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
        require(voterSuccess, "Voter transfer failed");

        (bool validatorSuccess, ) = validator.call{value: validatorReward}("");
        require(validatorSuccess, "Validator transfer failed");
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

    mapping(uint => mapping(address => Coinbase)) public coinbase;
    mapping(uint => address[]) public voters;

    constructor(address _validator, uint _voterShare) {
        validator = _validator;
        voterShare = _voterShare;
    }

    modifier onlyValidator() {
        require(msg.sender == validator, "Only the validator can perform this action");
        _;
    }

    function vote() external {
        uint t = election.schedule() + 1;
        if (address(coinbase[t][msg.sender]) == address(0)) {
            coinbase[t][voter] = new Coinbase(address(this), msg.sender, validator, voterShare);
            voters[t].push(msg.sender);
        }
        require(election.allowance(t, msg.sender, address(this)) >= 1, "Insufficient allowance to vote");
        election.transferFrom(msg.sender, address(this), 1);
        election.vote(validator, address(coinbase[t][msg.sender]));
    }

    function _claimReward(uint t, address voter) external {
        Coinbase _coinbase = coinbase[t][voter];
        require(address(_coinbase) != address(0), "Coinbase not set for this voter");
        _coinbase.claimReward();
    }
    function claimReward(uint t) external {
        _claimReward(t, msg.sender);
    }
    function claimValidatorRewards(uint t, address voter) external onlyValidator {
        _claimReward(t, voter);
    }
}
