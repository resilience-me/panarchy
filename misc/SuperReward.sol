interface Election {
    function schedule() external view returns (uint);
    function vote(address validator, address coinbase) external;
    function transferFrom(address from, address to, uint256 value) external;
    function allowance(uint t, address owner, address spender) external view returns (uint);
}

contract SuperReward {
    Election public election = Election(0x0000000000000000000000000000000000000011);

    address public validator;

    constructor(address _validator) {
        validator = _validator;
    }

    modifier onlyValidator() {
        require(msg.sender == validator, "Only the validator can perform this action");
        _;
    }

    function vote() external {
        uint t = election.schedule() + 1;
        require(election.allowance(t, msg.sender, address(this)) >= 1, "Insufficient allowance to vote");
        election.transferFrom(msg.sender, address(this), 1);
        election.vote(validator, msg.sender);
    }
}
