// An example contract for how validator could manage group rewards. These reward contracts are custom and written or chosen by validators, 
// the Panarchy system does not enforce any standard. I just provide this as an example (and anyone can use it of course. )
// The two most basic categories of voter reward schemes is to send voter reward to the voter who elected validator, or, distribute
// on all voters during a period. This contract is for the group version. Also note, part of the reward goes to validator (unless they
// choose to give everything to voters. )

contract Coinbase {
    address public validator;
    mapping(address => uint) public votes;
    uint public totalVotes;
    uint public voterReward;
    uint public validatorReward;
    uint public voterShare;

    constructor(address _validator, uint _voterShare) {
        validator = _validator;
        voterShare = _voterShare;
    }

    modifier onlyValidator() {
        require(msg.sender == validator, "Only the validator can perform this action");
        _;
    }

    function recordVote(address voter) external onlyValidator {
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

    function claimReward(address voter) external onlyValidator {
        initRewards();
        uint reward = (voterReward * votes[voter]) / totalVotes;
        delete votes[voter];
        (bool success, ) = voter.call{value: reward}("");
        require(success, "Transfer failed.");
    }
    function claimValidatorReward() external onlyValidator {
        initRewards();
        uint _validatorReward = validatorReward;
        delete validatorReward;
        (bool success, ) = validator.call{value: _validatorReward}("");
        require(success, "Validator transfer failed.");
    }
}
