package clique

import (
	"bytes"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"math/big"
	"sync"
	"time"

	"github.com/ethereum/go-ethereum/accounts"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/consensus"
	"github.com/ethereum/go-ethereum/core/state"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethdb"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/params/types/ctypes"
	"github.com/ethereum/go-ethereum/params/vars"
	"github.com/ethereum/go-ethereum/params/mutations"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/ethereum/go-ethereum/trie"

	"golang.org/x/crypto/sha3"
)

var (
	errInvalidTimestamp         	= errors.New("invalid timestamp")
	errMissingSignature         	= errors.New("extra-data does not contain the signature")
	errWrongDifficulty 		= errors.New("wrong difficulty")
	errNoWithdrawalsAllowed     	= errors.New("panarchy does not support withdrawals")
	errFailedStatePassToSeal    	= errors.New("Failed to pass state object to Seal. Go-Ethereum consensus engine interface is not perfect fit for Panarchy engine, so we provide the state object to Seal in an unconventional way. We add this error check if it were to fail for some reason.")
	errHeaderOlderThanCheckpoint 	= errors.New("Header is older than checkpoint and will therefore be rejected")
	errValidatorNotElected      	= errors.New("Validator is not elected to sign the block")
)

const (
	genesis uint64 = 1712988000
	period 	uint64 = 4*7*24*60*60
)

var (
	seedSlot		= make([]byte, 32)
	electionSlot		= []byte{31: 1}
	bitpeopleContract	= common.Address{19: 0x10}
	electionContract	= common.Address{19: 0x11}
)

var allowedFutureBlockTime uint64

type cachedState struct {
	state *state.StateDB
	number uint64
}

type Panarchy struct {
	config	*ctypes.CliqueConfig
	checkpoint uint64
	lock sync.RWMutex
	signer common.Address
	signFn SignerFn
	cachedState cachedState
}

type Clique struct {
	Panarchy
}

type SignerFn func(signer accounts.Account, mimeType string, message []byte) ([]byte, error)

func New(config *ctypes.CliqueConfig, db ethdb.Database) *Clique {
	p := Panarchy{
		config: config,
	}
	allowedFutureBlockTime = config.Period/2
	return &Clique{p}
}

func (p *Panarchy) VerifyHeader(chain consensus.ChainHeaderReader, header *types.Header, seal bool) error {
	return p.verifyHeader(chain, header, nil)
}
func (p *Panarchy) VerifyHeaders(chain consensus.ChainHeaderReader, headers []*types.Header, seals []bool) (chan<- struct{}, <-chan error) {
	abort := make(chan struct{})
	results := make(chan error, len(headers))

	go func() {
		for i, header := range headers {
			err := p.verifyHeader(chain, header, headers[:i])

			select {
			case <-abort:
				return
			case results <- err:
			}
		}
	}()
	return abort, results
}
func (p *Panarchy) verifyHeader(chain consensus.ChainHeaderReader, header *types.Header, parents []*types.Header) error {

	number := header.Number.Uint64()
	if number == 0 {
		return nil
	}
	var parent *types.Header
	if len(parents) > 0 {
		parent = parents[len(parents)-1]
	} else {
		parent = chain.GetHeader(header.ParentHash, number-1)
	}

	if parent == nil || parent.Number.Uint64() != number-1 || parent.Hash() != header.ParentHash {
		return consensus.ErrUnknownAncestor
	}
	if err := p.processCheckpoint(header.Time); err != nil {
		return err
	}
	
	if parent.Time+p.config.Period != header.Time {
		return errInvalidTimestamp
	}
	skipped := header.Nonce.Uint64() - parent.Nonce.Uint64()
	if header.Time + skipped*p.config.Period > uint64(time.Now().Unix()) + allowedFutureBlockTime {
		return consensus.ErrFutureBlock
	}

	if header.Difficulty.Cmp(common.Big1) != 0 {
		return errWrongDifficulty
	}
	if header.GasLimit > vars.MaxGasLimit {
		return fmt.Errorf("invalid gasLimit: have %v, max %v", header.GasLimit, vars.MaxGasLimit)
	}
	if header.GasUsed > header.GasLimit {
		return fmt.Errorf("invalid gasUsed: have %d, gasLimit %d", header.GasUsed, header.GasLimit)
	}
	return nil
}

func (p *Panarchy) VerifyUncles(chain consensus.ChainReader, block *types.Block) error {
	if len(block.Uncles()) > 0 {
		return errors.New("uncles not allowed")
	}
	return nil
}

func schedule(timestamp uint64) uint64 {
	return (timestamp - genesis) / period
}

func (p *Panarchy) updateCheckpoint (timestamp uint64) {
	currentSchedule := schedule(timestamp)
	if currentSchedule == 0 {
		return
	}
	checkpoint := currentSchedule-1
	if p.checkpoint < checkpoint {
		p.checkpoint = checkpoint
	}
}

func (p *Panarchy) processCheckpoint(timestamp uint64) error {
	p.updateCheckpoint(timestamp)
	if schedule(timestamp) < p.checkpoint {
		return errHeaderOlderThanCheckpoint
	}
	return nil
}

func (p *Panarchy) Prepare(chain consensus.ChainHeaderReader, header *types.Header) error {

	parent := chain.GetHeader(header.ParentHash, header.Number.Uint64()-1)
	if parent == nil {
		return consensus.ErrUnknownAncestor
	}
	header.Time = parent.Time + p.config.Period
	if header.Number.Uint64() > 1 {
		grandParent := chain.GetHeader(parent.ParentHash, parent.Number.Uint64()-1)
		skipped := parent.Nonce.Uint64() - grandParent.Nonce.Uint64()
		header.Time += skipped*p.config.Period
	}
	p.updateCheckpoint(header.Time)
	header.Difficulty = p.CalcDifficulty(chain, header.Time, parent)
	return nil
}

func (p *Panarchy) Finalize(chain consensus.ChainHeaderReader, header *types.Header, state *state.StateDB, txs []*types.Transaction, uncles []*types.Header, withdrawals []*types.Withdrawal) {
	if err := p.verifySeal(header, state); err != nil {
		header.GasUsed=0
		log.Error("Error in Finalize. Will now force ValidateState to fail by altering block.Header.GasUsed")
	}
	mutations.AccumulateRewards(chain.Config(), state, header, uncles)
}

func (p *Panarchy) verifySeal(header *types.Header, state *state.StateDB) error {
	signer, err := p.Author(header)
	if err != nil {
		return err
	}
	skipped := header.Nonce.Uint64()
	if signer != p.getValidator(header, new(big.Int).SetUint64(skipped), state) {
		return errValidatorNotElected
	}
	return nil
}

func (p *Panarchy) FinalizeAndAssemble(chain consensus.ChainHeaderReader, header *types.Header, state *state.StateDB, txs []*types.Transaction, uncles []*types.Header, receipts []*types.Receipt, withdrawals []*types.Withdrawal) (*types.Block, error) {
	if len(withdrawals) > 0 {
		return nil, errNoWithdrawalsAllowed
	}
	mutations.AccumulateRewards(chain.Config(), state, header, uncles)
	header.Root = state.IntermediateRoot(true)
	p.cachedState = cachedState {
		state: state,
		number: header.Number.Uint64(),
	}
	return types.NewBlock(header, txs, nil, receipts, trie.NewStackTrie(nil)), nil
}

func (p *Panarchy) Seal(chain consensus.ChainHeaderReader, block *types.Block, results chan<- *types.Block, stop <-chan struct{}) error {
	cachedState := p.cachedState
	if cachedState.number != block.NumberU64() {
		return errFailedStatePassToSeal
	}
	go func() {
		p.lock.RLock()
		signer, signFn := p.signer, p.signFn
		p.lock.RUnlock()
		
		header := block.Header()
		delay := time.Unix(int64(header.Time), 0).Sub(time.Now())
		parentHeader := chain.GetHeaderByHash(header.ParentHash)
		var i uint64
		nonce := parentHeader.Nonce.Uint64()
		loop:
		for {
			select {
			case <-stop:
				return
			case <-time.After(delay):
				validator := p.getValidator(header, new(big.Int).SetUint64(nonce+i), cachedState.state);
				if validator == signer {
					break loop
				}
				i++
				delay = time.Duration(p.config.Period) * time.Second
			}
		}
    		nonce +=i
		header.Nonce = types.EncodeNonce(nonce)

		headerRlp := new(bytes.Buffer)
		encodeSigHeader(headerRlp, header, true)
		
		sig, err := signFn(accounts.Account{Address: signer}, "", headerRlp.Bytes())
		if err != nil {
			log.Error("failed to sign the header for account %s: %v", signer.Hex(), err)
			return
		}

		header.Extra = sig

		select {
			case results <- block.WithSeal(header):
			default:
				log.Warn("Sealing result is not read by miner")
		}
	}()

	return nil
}

func (p *Panarchy) SealHash(header *types.Header) (hash common.Hash) {
	return sealHash(header, false)
}

func sealHash(header *types.Header, finalSealHash bool) (hash common.Hash) {
	hasher := sha3.NewLegacyKeccak256()
	encodeSigHeader(hasher, header, finalSealHash)
	hasher.(crypto.KeccakState).Read(hash[:])
	return hash
}

func encodeSigHeader(w io.Writer, header *types.Header, finalSealHash bool) {
	enc := []interface{}{
		header.ParentHash,
		header.Coinbase,
		header.Root,
		header.TxHash,
		header.ReceiptHash,
		header.Bloom,
		header.Difficulty,
		header.Number,
		header.GasLimit,
		header.GasUsed,
		header.Time,
	}
	if finalSealHash {
		enc = append(enc, header.Nonce)
	}
	rlp.Encode(w, enc)
}

func (p *Panarchy) Author(header *types.Header) (common.Address, error) {
	if len(header.Extra) != crypto.SignatureLength {
		return common.Address{}, errMissingSignature
	}
	signature := header.Extra
	pubkey, err := crypto.Ecrecover(sealHash(header, true).Bytes(), signature)
	if err != nil {
		return common.Address{}, err
	}
	var signer common.Address
	copy(signer[:], crypto.Keccak256(pubkey[1:])[12:])

	return signer, nil
}

func (p *Panarchy) getValidator(header *types.Header, skipped *big.Int, state *state.StateDB) common.Address {
	currentSchedule := schedule(header.Time)
	currentIndex := make([]byte, 32)
	binary.BigEndian.PutUint64(currentIndex, currentSchedule)
	offset := new(big.Int).Set(common.Big0)
	if currentSchedule != 0 {
		previousIndex := make([]byte, 32)
		binary.BigEndian.PutUint64(previousIndex, currentSchedule - 1)
		seedKey := crypto.Keccak256Hash(append(previousIndex, seedSlot...))
		seed := state.GetState(bitpeopleContract, seedKey)
		offset.SetBytes(seed.Bytes())
	}
	electionKey := crypto.Keccak256(append(currentIndex, electionSlot...))
	electionLengthValue := state.GetState(electionContract, common.BytesToHash(electionKey))
	electionLength := new(big.Int).SetBytes(electionLengthValue.Bytes())
	validatorHeight := new(big.Int).Add(header.Number, skipped).Bytes()
	validatorHeightHashed := crypto.Keccak256(common.LeftPadBytes(validatorHeight, 32))
	randomVoter := new(big.Int).SetBytes(validatorHeightHashed)
	randomVoter.Add(randomVoter, offset)
	randomVoter.Mod(randomVoter, electionLength)
	electionArray := new(big.Int).SetBytes(crypto.Keccak256(electionKey))
	electionArray.Add(electionArray, randomVoter)
	validator := state.GetState(electionContract, common.BytesToHash(electionArray.Bytes()))
	return common.BytesToAddress(validator.Bytes())
}

func (p *Panarchy) Authorize(signer common.Address, signFn SignerFn) {
	p.lock.Lock()
	defer p.lock.Unlock()
	p.signer = signer
	p.signFn = signFn
}

func (p *Panarchy) CalcDifficulty(chain consensus.ChainHeaderReader, time uint64, parent *types.Header) *big.Int {
	return new(big.Int).Set(common.Big1)
}
func (p *Panarchy) APIs(chain consensus.ChainHeaderReader) []rpc.API {
	return []rpc.API{}
}
func (p *Panarchy) Close() error {
	return nil
}
