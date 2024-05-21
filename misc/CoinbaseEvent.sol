// An idea for how to emit block reward events. The problem here is that it also emits for missed validator slots.
// An easy workaround is to check balance of the coinbase, but then it will not emit for collected coinbases (which
// seems a bit messy, either emit for all payouts or none... ) Alternatively, people can poll the coinbase contracts 
// they are part of.

interface Bitpeople { function seed(uint t) external view returns (uint); }

interface Election {
    struct Vote { address validator; address coinbase; }
    function votes(uint t, uint i) external view returns (Vote memory);
    function votesLength(uint t) external view returns (uint);
}

contract Schedule {

    uint constant public genesis = 1715407200;
    uint constant public period = 4 weeks;

    function schedule() public view returns(uint) { return ((block.timestamp - genesis) / period); }
}

contract CoinbaseEvent is Schedule {

    Bitpeople bitpeople = Bitpeople(0x0000000000000000000000000000000000000010);
    Election election = Election(0x0000000000000000000000000000000000000011);
    
    uint constant public slotTime = 12;
    uint public nonce;

    event BlockReward(uint indexed schedule, uint indexed slot, address indexed coinbase);

    function emitCoinbaseEvent() external returns (bool) {
        uint256 currentSlot = (block.timestamp - genesis) / slotTime;
        if(currentSlot <= nonce) return false;
        uint t = nonce * slotTime / period;
        uint i = (bitpeople.seed(t) + uint256(keccak256(abi.encode(nonce)))) % election.votesLength(t);
        address coinbase = election.votes(t, i).coinbase;
        emit BlockReward(t, slot, coinbase);
        nonce++;
        return true;
    }
}
