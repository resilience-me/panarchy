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
