contract Bitpeople {
    function proofOfUniqueHuman(uint t, address account) external view returns (bool) {}
    function population(uint t) external view returns (uint) {}
}

contract Schedule {
    uint constant public genesis = 1712988000;
    uint constant public period = 4 weeks;
    function schedule() public view returns(uint) { return ((block.timestamp - genesis) / period); }
    function toSeconds(uint t) public pure returns (uint) { return genesis + t * period; }
}

contract Exp {

    uint256 internal constant EXP = 60;
    uint256 internal constant SCALE = 2**EXP;

    function pow(uint256 x, uint256 y) public pure returns (uint256 result) {
        result = y & 1 == 1 ? x : SCALE;
        for (y >>= 1; y > 0; y >>= 1) {
            x = (x * x + (SCALE >> 1)) >> EXP;
            if (y & 1 == 1) {
                result = (result * x + (SCALE >> 1)) >> EXP;
            }
        }
    }
}

contract PAN is Schedule, Exp {

    Bitpeople bitpeople = Bitpeople(0x0000000000000000000000000000000000000010);

    string constant public symbol = "PAN";
    uint8 constant public decimals = 18;

    uint constant taxRate = 0x0ffffffe185dd90b;
    uint constant ubi = 17020135985237315;

    mapping (address => uint) public balanceOf;
    mapping (address => mapping (address => uint)) public allowance;

    mapping (uint => mapping (address => bool)) public claimedUBI;

    mapping (address => uint) public log;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() public view returns (uint) { return 10**decimals*bitpeople.population(schedule()); }

    function withdrawUBI() external {
        uint t = schedule();
        require(bitpeople.proofOfUniqueHuman(t, msg.sender), "Failed to verify proof-of-unique-human.");
        require(!claimedUBI[t][msg.sender], "UBI already claimed for this period");
        taxation(msg.sender);
        uint seconds_into_period = block.timestamp - toSeconds(t);
        uint tax_during_period = pow(taxRate, seconds_into_period);
        uint ubiTaxed = ubi*tax_during_period >> EXP;
        balanceOf[msg.sender] += ubiTaxed;
        claimedUBI[t][msg.sender] = true;
        emit Transfer(address(this), msg.sender, ubiTaxed);
    }

    function taxation(address account) public {
        if(log[account] > 0) {
            uint seconds_since_last_time = block.timestamp - log[account];
            uint tax = pow(taxRate, seconds_since_last_time);
            balanceOf[account] = balanceOf[account] * tax >> EXP;
        }
        log[account] = block.timestamp;
    }

    function _transfer(address from, address to, uint value) internal {
        taxation(from);
        require(balanceOf[from] >= value, "Transfer failed: Insufficient balance");
        taxation(to);
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }
    function transfer(address to, uint value) external {
        _transfer(msg.sender, to, value);
    }
    function approve(address spender, uint value) external {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
    }
    function transferFrom(address from, address to, uint value) external {
        require(allowance[from][msg.sender] >= value, "Transfer failed: Allowance exceeded");
        _transfer(from, to, value);
        allowance[from][msg.sender] -= value;
    }
}
