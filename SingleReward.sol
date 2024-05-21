contract Coinbase {
    address public owner;
    address public voter;
    address public validator;
    uint public voterShare;

    constructor(address _owner, address _voter, address _validator, uint _voterShare) {
        owner = _owner;
        voter = _voter;
        validator = _validator;
        voterShare = _voterShare;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    function claimReward() external onlyOwner {
        uint balance = address(this).balance;
        uint voterReward = (balance * voterShare) / 10000;
        uint validatorReward = balance - voterReward;

        (bool voterSuccess, ) = voter.call{value: voterReward}("");
        require(voterSuccess, "Voter transfer failed.");

        (bool validatorSuccess, ) = validator.call{value: validatorReward}("");
        require(validatorSuccess, "Validator transfer failed.");
    }
}

interface Election {
    function schedule() external view returns (uint);
    function vote(address validator, address coinbase) external;
    function transferFrom(address from, address to, uint256 value) external;
    function allowance(uint t, address owner, address spender) external view returns (uint);
}

contract SingleReward {
    Election public election = Election(0x0000000000000000000000000000000000000011);

    address public validator;
    uint public voterShare;

    mapping(address => Coinbase) public coinbase;

    constructor(address _validator, uint _voterShare) {
        validator = _validator;
        voterShare = _voterShare;
    }

    modifier onlyValidator() {
        require(msg.sender == validator, "Only the validator can perform this action");
        _;
    }

    function vote(address voter) external {
        uint t = election.schedule();
        if (address(coinbase[voter]) == address(0)) {
            coinbase[voter] = new Coinbase(address(this), voter, validator, voterShare);
        }
        require(election.allowance(t, voter, address(this)) >= 1, "Insufficient allowance to vote");
        election.transferFrom(voter, address(this), 1);
        election.vote(validator, address(coinbase[voter]));
    }

    function claimReward() external {
        Coinbase _coinbase = coinbase[msg.sender];
        require(address(_coinbase) != address(0), "Coinbase not set for this voter");
        _coinbase.claimReward();
    }
}
