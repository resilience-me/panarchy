// Will likely be adding ability to automate validator rewards to voters, current work on that in code below. Was previously 
// skipping it and leaving it to be done manually, mostly because the Geth consensus engine interface seemed to not support it well 
// (was no way to read state during prepare for example) but found a few good workarounds, one relies on temporary rewarad storage contracts
// that can be deterministically known (thus hardcoded into Geth) and it seems like a good solution so I'll code that at least, and possibly
// restart the network to use it

contract Bitpeople { 
    function seed(uint t) external view returns (uint) {}
    function proofOfUniqueHuman(uint t, address account) external view returns (bool) {}
}

contract Schedule {

    uint constant public genesis = 1715407200;
    uint constant public period = 4 weeks;

    function schedule() public view returns(uint) { return ((block.timestamp - genesis) / period); }
    function toSeconds(uint t) public pure returns (uint) { return genesis + t * period; }
    function halftime(uint t) public view returns (bool) { return((block.timestamp > toSeconds(t)+period/2)); }
}

contract Reward {
    address constant internal electionContract = 0x0000000000000000000000000000000000000011;
    function withdraw(address rewardAddress) external { require(msg.sender == electionContract); selfdestruct(payable(rewardAddress)); }
}

contract Election is Schedule {

    uint public nonce;

    struct RewardContract {
        address addr;
        uint[] slotsRewarded;
        uint rewardsClaimed;
        uint validSince;
    }
    mapping (address => RewardContract[]) public rewardContract;

    function createRewardContract() external returns (bool) {
        uint256 currentSlot = (block.timestamp - genesis) / slotTime;
        if(currentSlot <= nonce) return false;
        Reward reward = new Reward();
        if(address(reward).balance == 0) {
            reward.withdraw(address(0));
            return true;
        }
        uint t = (nonce * slotTime) / period;
        uint i = (bitpeople.seed(t) + uint256(keccak256(abi.encode(nonce)))) % data[t].election.length;
        address validator = data[t].election[i];

        uint rewardContractIndex = rewardContract[validator].length-1;
        while(rewardContract[validator][rewardContractIndex].validSince>t) { rewardContractIndex--; }
        if(rewardContract[validator][rewardContractIndex].addr == address(0)) {
            reward.withdraw(validator);
            return true;
        }
        rewardContract[validator][rewardContractIndex].slotsRewarded.push(nonce);
        nonce++; // Increment the nonce after creating the contract
        return true;
    }

    Bitpeople bitpeople = Bitpeople(0x0000000000000000000000000000000000000010);

    uint constant public slotTime = 12;

    struct Data {
        address[] election;
        mapping (address => uint) balanceOf;
        mapping (address => mapping (address => uint)) allowance;
        mapping (address => bool) claimedSuffrageToken;
    }

    mapping (uint => Data) data;

    event Elected(uint indexed schedule, address indexed validator);

    event Transfer(uint indexed schedule, address indexed from, address indexed to, uint256 value);
    event Approval(uint indexed schedule, address indexed owner, address indexed spender, uint256 value);

    function vote(address validator) external {
        uint t = schedule();
        require(!halftime(t), "Voting is only allowed before the halfway point.");
        require(data[t].balanceOf[msg.sender] >= 1, "Balance decrement failed: Insufficient balance");
        data[t].balanceOf[msg.sender]--;
        data[t+1].election.push(validator);
        emit Elected(t+1, validator);
    }

    function allocateSuffrageToken() external {
        uint t = schedule();
        require(bitpeople.proofOfUniqueHuman(t, msg.sender), "Failed to verify proof-of-unique-human.");
        require(!data[t].claimedSuffrageToken[msg.sender], "Suffrage token already claimed.");
        data[t].balanceOf[msg.sender]++;
        data[t].claimedSuffrageToken[msg.sender] = true;
    }

    function _transfer(uint t, address from, address to, uint value) internal {
        require(data[t].balanceOf[from] >= value, "Transfer failed: Insufficient balance");
        data[t].balanceOf[from] -= value;
        data[t].balanceOf[to] += value;
        emit Transfer(t, from, to, value);
    }
    function transfer(address to, uint value) external {
        _transfer(schedule(), msg.sender, to, value);
    }
    function approve(address spender, uint value) external {
        uint t = schedule();
        data[t].allowance[msg.sender][spender] = value;
        emit Approval(t, msg.sender, spender, value);
    }
    function transferFrom(address from, address to, uint value) external {
        uint t = schedule();
        require(data[t].allowance[from][msg.sender] >= value, "Transfer failed: Allowance exceeded");
        _transfer(t, from, to, value);
        data[t].allowance[from][msg.sender] -= value;
    }

    function election(uint t, uint i) external view returns (address) { return data[t].election[i]; }
    function electionLength(uint t) external view returns (uint) { return data[t].election.length; }
    function balanceOf(uint t, address account) external view returns (uint) { return data[t].balanceOf[account]; }
    function allowance(uint t, address owner, address spender) external view returns (uint) { return data[t].allowance[owner][spender]; }
    function claimedSuffrageToken(uint t, address account) external view returns (bool) { return data[t].claimedSuffrageToken[account]; }
}
