// An example contract for how validator could manage group rewards. These reward contracts are custom and written or chosen by validators, 
// the Panarchy system does not enforce any standard. I just provide this as an example (and anyone can use it of course. )
// The two most basic categories of voter reward schemes is to send voter reward to the voter who elected validator, or, distribute
// on all voters during a period. This contract is for the group version. Also note, part of the reward goes to validator (unless they
// choose to give everything to voters. )

contract Coinbase {
    address public validator;
    mapping(address => uint) public votes;
    uint public totalVotes;
    uint public balance;

    constructor(address _validator) {
        validator = _validator;
    }

    modifier onlyValidator() {
        require(msg.sender == validator, "Only the validator can perform this action");
        _;
    }

    function recordVote(address voter) external onlyValidator {
        votes[voter]++;
        totalVotes++;
    }

    function claimReward(address voter) external onlyValidator {
        if (balance == 0) { balance = address(this).balance; }

        uint reward = (balance * votes[voter]) / totalVotes;
        delete votes[voter];
        (bool success, ) = voter.call{value: reward}("");
        require(success, "Transfer failed.");
    }
}
