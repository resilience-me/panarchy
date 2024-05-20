// Will likely be adding ability to automate validator rewards to voters, current work on that in code below. Was previously 
// skipping it and leaving it to be done manually, mostly because the Geth consensus engine interface seemed to not support it well 
// (was no way to read state during prepare for example) but found a few good workarounds, one relies on temporary rewarad storage contracts
// that can be deterministically known (thus hardcoded into Geth) and it seems like a good solution so I'll code that at least, and possibly
// restart the network to use it

contract Bitpeople { function seed(uint t) external view returns (uint) {} }

contract Election {
    function election(uint t, uint i) external view returns (address) {}
    function electionLength(uint t) external view returns (uint) {}
}

contract Coinbase {
    address constant internal blockRewardsContract = 0x0000000000000000000000000000000000000012;
    function sendAll(address rewardAddress) external {
        require(msg.sender == blockRewardsContract);
        selfdestruct(payable(rewardAddress));
    }
}

contract Schedule {

    uint constant public genesis = 1715407200;
    uint constant public period = 4 weeks;

    function schedule() public view returns(uint) { return ((block.timestamp - genesis) / period); }
}

contract BlockRewards is Schedule {

    Bitpeople bitpeople = Bitpeople(0x0000000000000000000000000000000000000010);
    Election election = Election(0x0000000000000000000000000000000000000011);

    uint constant public slotTime = 12;
    uint public nonce;

    struct RewardHandler {
        address addr;
        uint[] slotsRewarded;
        uint rewardsClaimed;
        uint validSince;
    }
    mapping (address => RewardHandler[]) public rewardHandler;
    mapping (address => uint) public processedHandlers;

    function changeHandler(address addr) external {
        RewardHandler memory newHandler;
        newHandler.addr = addr;
        newHandler.validSince = schedule();
        rewardHandler[msg.sender].push(newHandler);
    }

    function pendingCoinbase(address account) public returns (bool) {
        RewardHandler storage handler = rewardHandler[account][processedHandlers[account];
        return (handler.slotsRewarded.length > handler.rewardsClaimed);
    }

    function coinbaseSlot(address account) public returns (uint) {
        RewardHandler storage handler = rewardHandler[account][processedHandlers[account];
        require(handler.slotsRewarded.length > handler.rewardsClaimed, "Coinbase processing not synced");
        return handler.slotsRewarded[handler.rewardsClaimed];
    }

    function coinbaseAddress(uint slot) public returns (address) {
         return address(uint160(uint256(keccak256(abi.encodePacked(address(this), slot)))));
    }

    function syncCoinbase() external returns (bool) {
        uint t = schedule();
        uint i = processedHandlers[msg.sender];
        RewardHandler[] storage handlers = rewardHandler[msg.sender];
        if(handlers[i].slotsRewarded.length == handlers[i].rewardsClaimed) {
            if(handlers.length > i && handlers[i+1].validSince <= t) {
                processedHandlers[msg.sender]++;
                return false;
            }
        }
        return true;
    }

    function processCoinbase() external returns (uint) {
        require(pendingCoinbase(msg.sender));
        uint slot = coinbaseSlot(msg.sender);
        address cbaddr = coinbaseAddress(slot);
        Coinbase coinbase = Coinbase(cbaddr);
        RewardHandler storage handler = rewardHandler[msg.sender][processedHandlers[msg.sender];
        coinbase.sendAll(handler.addr);
        handler.rewardsClaimed++;
        return slot;
    }

    function createRewardContract() external returns (bool) {
        uint256 currentSlot = (block.timestamp - genesis) / slotTime;
        if(currentSlot <= nonce) return false;
        Coinbase coinbase = new Coinbase();
        if(address(coinbase).balance == 0) {
            coinbase.sendAll(address(0));
            return true;
        }
        uint t = (nonce * slotTime) / period;
        uint i = (bitpeople.seed(t) + uint256(keccak256(abi.encode(nonce)))) % election.electionLength(t);
        address validator = election.election(t, i);

        uint rewardHandlerIndex = rewardHandler[validator].length-1;
        while(rewardHandler[validator][rewardHandlerIndex].validSince > t) { rewardHandlerIndex--; }
        if(rewardHandler[validator][rewardHandlerIndex].addr == address(0)) {
            coinbase.sendAll(validator);
            return true;
        }
        rewardHandler[validator][rewardHandlerIndex].slotsRewarded.push(nonce);
        nonce++; // Increment the nonce after creating the contract
        return true;
    }
}
