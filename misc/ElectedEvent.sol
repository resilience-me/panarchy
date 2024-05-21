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

contract ElectedEvent is Schedule {

    Bitpeople bitpeople = Bitpeople(0x0000000000000000000000000000000000000010);
    Election election = Election(0x0000000000000000000000000000000000000011);
    
    uint constant public slotTime = 12;
    uint public nonce;

    event Elected(uint indexed slot, address indexed validator, address indexed coinbase);

    function emitElectedEvent() external returns (bool) {
        uint256 slot = (block.timestamp - genesis) / slotTime;
        if(slot <= nonce) return false;
        uint t = nonce * slotTime / period;
        uint i = (bitpeople.seed(t) + uint256(keccak256(abi.encode(nonce)))) % election.votesLength(t);
        Vote vote = election.votes(t, i);
        emit Elected(slot, vote.validator, vote.coinbase);
        nonce++;
        return true;
    }
}
