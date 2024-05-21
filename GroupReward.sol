// An example contract for how validator could manage group rewards. The reward contracts are modular, custom and written or chosen by validators, 
// the Panarchy system does not enforce any standard. I just provide this as an example (and anyone can use it of course. )
// The two most basic categories of voter reward schemes is to send voter reward to the voter who elected validator, or, distribute
// on all voters during a period. This contract is for the group version, and a SingleReward.sol or IndividualReward.sol should also be written.
// Also note, part of the reward goes to validator (unless they choose to give everything to voters. )

interface Election {
    function schedule() external view returns (uint);
    function vote(address validator, address coinbase) external;
    function transferFrom(address from, address to, uint256 value) external;
    function allowance(uint t, address owner, address spender) external view returns (uint);
}

contract Coinbase {
    address public owner;
    mapping(address => uint) public votes;
    uint public totalVotes;
    uint public voterReward;
    uint public validatorReward;
    uint public voterShare;

    constructor(address _owner, uint _voterShare) {
        owner = _owner;
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

    function claimValidatorReward(address validator) external onlyOwner {
        initRewards();
        uint _validatorReward = validatorReward;
        delete validatorReward;
        (bool success, ) = validator.call{value: _validatorReward}("");
        require(success, "Validator transfer failed");
    }
}

contract GroupReward {
    Election public election = Election(0x0000000000000000000000000000000000000011);

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
            coinbase[t] = new Coinbase(address(this), voterShare);
        }
    }

    function vote(address voter) external {
        uint t = election.schedule() + 1;
        initCoinbase(t);
        Coinbase _coinbase = coinbase[t];
        require(election.allowance(t, voter, address(this)) >= 1, "Insufficient allowance to vote");
        election.transferFrom(voter, address(this), 1);
        _coinbase.recordVote(voter);
        election.vote(validator, address(_coinbase));
    }

    function _claimReward(uint t) internal view returns (Coinbase) {
        if(t == 0) t = election.schedule();
        require(t > 0, "Cannot claim reward before period zero");
        t--;
        require(t < election.schedule(), "Cannot claim rewards for the current or future periods");
        Coinbase _coinbase = coinbase[t];
        require(address(_coinbase) != address(0), "Coinbase not set for this period");
        return _coinbase;
    }
    function claimReward(uint t) external {
        _claimReward(t).claimReward(msg.sender);
    }

    function claimValidatorReward(uint t) external onlyValidator {
        _claimReward(t).claimValidatorReward(validator);
    }
}
