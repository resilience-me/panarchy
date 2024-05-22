// To automate voter rewards whilst not breaking the consensus engine interface, coinbase contracts are generated by this contract, one per slot.

interface Bitpeople { function seed(uint t) external view returns (uint); }

interface Election {
    struct Vote { address validator; address coinbase; }
    function votes(uint t, uint i) external view returns (Vote memory);
    function votesLength(uint t) external view returns (uint);
}

contract Coinbase {
    address constant internal coinbaseFactoryContract = 0x0000000000000000000000000000000000000012;
    function sendAll(address rewardAddress) external {
        require(msg.sender == coinbaseFactoryContract);
        selfdestruct(rewardAddress);
    }
}

contract CoinbaseFactory {

    uint public genesisBlockTimestamp;
    uint constant public period = 4 weeks;
    uint constant public slotTime = 12;

    uint public nonce;

    event CoinbaseEvent(uint indexed slot, address indexed validator, address indexed coinbase);

    function createCoinbaseContract() external returns (bool) {
        uint256 slot = (block.timestamp - genesisBlockTimestamp) / slotTime;
        if(slot <= nonce) return false;
        Coinbase coinbase = new Coinbase();
        nonce++;
        if(address(coinbase).balance == 0) {
            coinbase.sendAll(address(0));
            return true;
        }
        uint t = nonce * slotTime / period;
        uint i = (bitpeople.seed(t) + uint256(keccak256(abi.encode(nonce)))) % election.votesLength(t);
        Vote vote = election.votes(t, i);
        if(vote.coinbase == address(0)) {
          coinbase.sendAll(vote.validator);
        } else {
            coinbase.sendAll(vote.coinbase);
        }
        emit CoinbaseEvent(slot, vote.validator, vote.coinbase);
        return true;
    }
}
