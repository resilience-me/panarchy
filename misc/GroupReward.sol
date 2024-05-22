contract Coinbase {
    address public owner;
    address public validator;
    mapping(address => uint) public votes;
    uint public totalVotes;
    uint public voterReward;
    uint public validatorReward;
    uint public voterShare;

    constructor(address _owner, address _validator, uint _voterShare) {
        owner = _owner;
        validator = _validator;
        voterShare = _voterShare;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    function recordVote(address voter) external onlyOwner {
        votes[voter]++;
        totalVotes++;
    }

    function initRewards() public {
        if(voterReward == 0 && validatorReward == 0) {
            uint balance = address(this).balance;
            voterReward = (balance * voterShare) / 10000;
            validatorReward = balance - voterReward;
        }
    }

    function claimReward(address voter) external onlyOwner {
        initRewards();
        uint reward = (voterReward * votes[voter]) / totalVotes;
        delete votes[voter];
        (bool success, ) = voter.call{value: reward}("");
        require(success, "Transfer failed");
    }

    function claimValidatorReward() external onlyOwner {
        initRewards();
        uint _validatorReward = validatorReward;
        delete validatorReward;
        (bool success, ) = validator.call{value: _validatorReward}("");
        require(success, "Validator transfer failed");
    }
}

interface Election {
    function vote(address validator, address coinbase) external;
    function transferFrom(address from, address to, uint256 value) external;
    function allowance(uint t, address owner, address spender) external view returns (uint);
}

interface CoinbaseFactory {
    function genesisBlockTimestamp() external view returns (uint);
    function nonce() external view returns (uint);
    function slotTime() external pure returns (uint);
}

contract Schedule {
    uint constant public genesis = 1715407200;
    uint constant public period = 4 weeks;
    function schedule() public view returns(uint) { return ((block.timestamp - genesis) / period); }
    function toSeconds(uint t) public pure returns (uint) { return genesis + t * period; }
}

contract GroupReward is Schedule {
    Election election = Election(0x0000000000000000000000000000000000000011);
    CoinbaseFactory coinbaseFactory = CoinbaseFactory(0x0000000000000000000000000000000000000012);

    address public validator;
    uint public voterShare;

    mapping(uint => Coinbase) public coinbase;

    constructor(address _validator, uint _voterShare) {
        validator = _validator;
        voterShare = _voterShare;
    }

    modifier onlyValidator() {
        require(msg.sender == validator, "Only the validator can perform this action");
        _;
    }

    function initCoinbase(uint t) internal {
        if(address(coinbase[t]) == address(0)) {
            coinbase[t] = new Coinbase(address(this), validator, voterShare);
        }
    }

    function vote() external {
        uint t = schedule() + 1;
        initCoinbase(t);
        Coinbase _coinbase = coinbase[t];
        require(election.allowance(t, msg.sender, address(this)) >= 1, "Insufficient allowance to vote");
        election.transferFrom(msg.sender, address(this), 1);
        _coinbase.recordVote(msg.sender);
        election.vote(validator, address(_coinbase));
    }

    function isSynced(uint t) public view returns (bool) {
        uint syncedToSlot = coinbaseFactory.genesisBlockTimestamp() + coinbaseFactory.nonce() * coinbaseFactory.slotTime();
        return(toSeconds(t) < syncedToSlot + coinbaseFactory.slotTime());
    }

    function _claimReward(uint t) internal view returns (Coinbase) {
        if(t == 0) t = schedule();
        require(t > 0, "Cannot claim reward before period zero");
        t--;
        require(t < schedule(), "Cannot claim rewards for the current or future periods");
        require(isSynced(t), "Transfer from temporary coinbase contracts before claiming");
        Coinbase _coinbase = coinbase[t];
        require(address(_coinbase) != address(0), "Coinbase not set for this period");
        return _coinbase;
    }
    function claimReward(uint t) external {
        _claimReward(t).claimReward(msg.sender);
    }

    function claimValidatorReward(uint t) external onlyValidator {
        _claimReward(t).claimValidatorReward();
    }
}
