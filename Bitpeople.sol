contract Bitpeople {

    uint constant public genesis = 1712988000;
    uint constant public period = 4 weeks;

    function schedule() public view returns(uint) { return (block.timestamp - genesis) / period; }
    function toSeconds(uint t) public pure returns (uint) { return genesis + t * period; }
    function quarter(uint t) public view returns (uint) { return (block.timestamp-toSeconds(t))/(period/4); }
    function hour(uint t) public pure returns (uint) { return 1 + uint(keccak256(abi.encode(t)))%24; }
    function pseudonymEvent(uint t) public pure returns (uint) { return toSeconds(t) + hour(t)*1 hours; }

    struct Nym { uint id; bool verified; }
    struct Pair { bool[2] verified; bool disputed; }
    struct Court { uint id; bool[2] verified; }

    enum Token { ProofOfUniqueHuman, Register, OptIn, BorderVote }

    struct Data {
        uint seed;
        bytes32 random;

        mapping (address => Nym) nym;
        address[] registry;
        uint shuffled;
        mapping (address => bool) shuffler;
        mapping (uint => Pair) pair;
        mapping (address => Court) court;
        uint courts;

        mapping (address => bool) proofOfUniqueHuman;
        uint population;

        uint permits;
        mapping (uint => uint) target;
        uint traverser;

        mapping (address => bytes32) commit;
        mapping (uint => uint) points;

        mapping (Token => mapping (address => uint)) balanceOf;
        mapping (Token => mapping (address => mapping (address => uint))) allowance;
    }
    mapping (uint => Data) data;

    event Shuffled (uint indexed schedule, address indexed account);
    event Verify (uint indexed schedule, uint indexed pairID);
    event Judge (uint indexed schedule, address court, uint indexed courtID);
    event Dispute (uint indexed schedule, uint indexed pairID);

    event Transfer(uint indexed schedule, Token token, address indexed from, address indexed to, uint256 value);
    event Approval(uint indexed schedule, Token token,  address indexed owner, address indexed spender, uint256 value);

    function getPair(uint id) public pure returns (uint) { return (id+1)/2; }    
    function getCourt(Data storage d, uint id) internal view returns (uint) { return id != 0 ? 1 + (id - 1) % (d.registry.length / 2) : 0; }
    function pairVerified(Data storage d, uint id) internal view returns (bool) { return d.pair[id].verified[0] && d.pair[id].verified[1]; }
    function deductToken(Data storage currentData, Token token) internal { require(currentData.balanceOf[token][msg.sender] >= 1, "Balance decrement failed: Insufficient balance"); currentData.balanceOf[token][msg.sender]--; }

    function register(bytes32 randomNumberHash) external {
        uint t = schedule();
        require(quarter(t) < 2, "Registration is only allowed in the first two quarters");
        Data storage currentData = data[t];
        deductToken(currentData, Token.Register);
        currentData.registry.push(msg.sender);
        currentData.commit[msg.sender] = randomNumberHash;
    }
    function optIn() external {
        uint t = schedule();
        require(quarter(t) < 2, "Opting-in is only allowed in the first two quarters");
        Data storage currentData = data[t];
        deductToken(currentData, Token.OptIn);
        currentData.courts++;
        currentData.court[msg.sender].id = currentData.courts;
    }

    function _shuffle(uint t) internal returns (bool) {
        Data storage d = data[t];
        uint _shuffled = d.shuffled;
        if(_shuffled == 0) d.random = keccak256(abi.encode(d.seed));
        uint unshuffled = d.registry.length - _shuffled;
        if(unshuffled == 0) return false;
        uint index = _shuffled + uint(d.random)%unshuffled;
        address randomNym = d.registry[index];
        d.registry[index] = d.registry[_shuffled];
        d.registry[_shuffled] = randomNym;
        d.nym[randomNym].id = _shuffled+1;
        d.shuffled++;
        d.random = keccak256(abi.encode(d.random, randomNym));
        if(!d.shuffler[msg.sender]) d.shuffler[msg.sender] = true;
        emit Shuffled(t, randomNym);
        return true;
    }

    function shuffle() external returns (bool)  {
        uint t = schedule();
        require(quarter(t) == 3, "Shuffling is only allowed in the fourth quarter");
        return _shuffle(t);
    }
    function lateShuffle() external returns (bool) {
        return _shuffle(schedule()-1);
    }
    function verify() external {
        uint t = schedule()-1;
        require(block.timestamp > pseudonymEvent(t+1), "Verification not allowed before the pseudonym event has started");
        Data storage previousData = data[t];
        uint id = previousData.nym[msg.sender].id;
        require(id != 0, "Invalid ID: ID does not exist");
        require(previousData.shuffler[msg.sender] || previousData.shuffled == previousData.registry.length, "Verification failed: Requires shuffler status or completion of shuffling for everyone registered");
        uint pairID = getPair(id);
        require(!previousData.pair[pairID].disputed, "Verification failed: Pair is disputed");
        previousData.pair[pairID].verified[id%2] = true;
        emit Verify(t, pairID);
    }
    function judge(address _court) external {
        uint t = schedule()-1;
        require(block.timestamp > pseudonymEvent(t+1), "Judgement not allowed before the pseudonym event has started");
        Data storage previousData = data[t];
        uint signer = previousData.nym[msg.sender].id;
        uint courtID = getCourt(previousData, previousData.court[_court].id);
        require(courtID == getPair(signer), "Invalid court: the signer is not assigned to judge this court");
        previousData.court[_court].verified[signer%2] = true;
        emit Judge(t, _court, courtID);
    }

    function allocateTokens(Data storage currentData) internal {
        currentData.balanceOf[Token.Register][msg.sender]++;
        currentData.balanceOf[Token.BorderVote][msg.sender]++;
    }
    function nymVerified() external {
        uint t = schedule();
        Data storage currentData = data[t];
        Data storage previousData = data[t-1];
        require(!previousData.nym[msg.sender].verified, "Nym is already verified");
        uint id = previousData.nym[msg.sender].id;
        require(pairVerified(previousData, getPair(id)), "The nym's pair is not verified");
        allocateTokens(currentData);
        if(id <= previousData.permits) currentData.balanceOf[Token.OptIn][msg.sender]++;
        previousData.nym[msg.sender].verified = true;
    }
    function courtVerified() external {
        uint t = schedule();
        Data storage previousData = data[t-1];
        require(pairVerified(previousData, getCourt(previousData, previousData.court[msg.sender].id)), "Court's pair not verified");
        require(previousData.court[msg.sender].verified[0] && previousData.court[msg.sender].verified[1], "Verification failed: Both judges of this court must confirm verification");
        delete previousData.court[msg.sender];
    }

    function revealHash(bytes32 preimage) external {
        uint t = schedule();
        Data storage currentData = data[t];
        Data storage previousData = data[t-1];
        require(quarter(t) == 2, "Operation must be performed in the third quarter");
        require(previousData.nym[msg.sender].verified, "Nym must be verified");
        require(keccak256(abi.encode(preimage)) == previousData.commit[msg.sender], "Preimage does not match the committed hash");
        bytes32 mutated = keccak256(abi.encode(preimage, previousData.seed));
        uint id = uint(mutated)%previousData.registry.length;
        currentData.points[id]++;
        if (currentData.points[id] > currentData.points[currentData.seed]) currentData.seed = id;
        delete previousData.commit[msg.sender];
        currentData.balanceOf[Token.ProofOfUniqueHuman][msg.sender]++;
    }
    function claimProofOfUniqueHuman() external {
        uint t = schedule();
        Data storage nextData = data[t+1];
        deductToken(data[t], Token.ProofOfUniqueHuman);
        nextData.proofOfUniqueHuman[msg.sender] = true;
        nextData.population++;
    }

    function dispute(bool early) external {
        uint t = early ? schedule() : schedule() - 1;
        Data storage d = data[t];
        uint id = getPair(d.nym[msg.sender].id);
        require(id != 0, "Invalid ID: ID cannot be zero");
        if(!early) require(!pairVerified(d, id), "Dispute invalid: pair has already been verified");
        d.pair[id].disputed = true;
        emit Dispute(t, id);
    }
    function reassignNym(bool early) external {
        Data storage d = early ? data[schedule()] : data[schedule() - 1];
        uint id = d.nym[msg.sender].id;
        require(d.pair[getPair(id)].disputed, "Reassignment failed: Pair not disputed");
        delete d.nym[msg.sender];
        d.court[msg.sender].id = uint(keccak256(abi.encode(id)));
    }
    function reassignCourt(bool early) external {
        Data storage d = early ? data[schedule()] : data[schedule() - 1];
        uint id = d.court[msg.sender].id;
        require(d.pair[getCourt(d, id)].disputed, "Reassignment failed: The court's pair is not disputed");
        delete d.court[msg.sender].verified;
        d.court[msg.sender].id = uint(keccak256(abi.encode(0, id)));
    }
    function borderVote(uint target) external {
        Data storage currentData = data[schedule()];
        deductToken(currentData, Token.BorderVote);
        currentData.target[target]+=2;
        if(target > currentData.permits) {
            if(currentData.traverser < currentData.target[currentData.permits]) currentData.traverser++;
            else {
                currentData.permits++;
                currentData.traverser = 0;
            }
        }
        else if(target < currentData.permits) {
            if(currentData.traverser > 0) currentData.traverser--;
            else {
                currentData.permits--;
                currentData.traverser = currentData.target[currentData.permits];
            }
        }
        else currentData.traverser++;
    }

    function _transfer(uint t, address from, address to, uint value, Token token) internal {
        require(data[t].balanceOf[token][from] >= value, "Transfer failed: Insufficient balance");
        data[t].balanceOf[token][from] -= value;
        data[t].balanceOf[token][to] += value;
        emit Transfer(t, token, from, to, value);
    }
    function transfer(address to, uint value, Token token) external {
    _transfer(schedule(), msg.sender, to, value, token);
    }
    function approve(address spender, uint value, Token token) external {
        uint t = schedule();
        data[t].allowance[token][msg.sender][spender] = value;
        emit Approval(t, token, msg.sender, spender, value);
    }
    function transferFrom(address from, address to, uint value, Token token) external {
        uint t = schedule();
        require(data[t].allowance[token][from][msg.sender] >= value, "Transfer failed: Allowance exceeded");
        _transfer(t, from, to, value, token);
        data[t].allowance[token][from][msg.sender] -= value;
    }

    function seed(uint t) external view returns (uint) { return data[t].seed; }
    function nym(uint t, address account) external view returns (Nym memory) { return data[t].nym[account]; }
    function registry(uint t, uint id) external view returns (address) { return data[t].registry[id]; }
    function registryLength(uint t) external view returns (uint) { return data[t].registry.length; }
    function shuffled(uint t) external view returns (uint) { return data[t].shuffled; }
    function shuffler(uint t, address account) external view returns (bool) { return data[t].shuffler[account]; }
    function pair(uint t, uint id) external view returns (Pair memory) { return data[t].pair[id]; }
    function court(uint t, address account) external view returns (Court memory) { return data[t].court[account]; }
    function courts(uint t) external view returns (uint) { return data[t].courts; }
    function proofOfUniqueHuman(uint t, address account) external view returns (bool) { return data[t].proofOfUniqueHuman[account]; }
    function population(uint t) external view returns (uint) { return data[t].population; }
    function permits(uint t) external view returns (uint) { return data[t].permits; }
    function commit(uint t, address account) external view returns (bytes32) { return data[t].commit[account]; }
    function balanceOf(uint t, Token token, address account) external view returns (uint) { return data[t].balanceOf[token][account]; }
    function allowance(uint t, Token token, address owner, address spender) external view returns (uint) { return data[t].allowance[token][owner][spender]; }
}
