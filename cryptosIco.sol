// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 <0.9.0;

interface ERC20Interface {
    function totalSupply() external view returns (uint); // mandatory function
    function balanceOf(address tokenOwner) external view returns (uint balance); // mandatory function
    function transfer(address to, uint tokens) external returns (bool success); // mandatory function
    
    function allowance(address tokenOwner, address spender) external view returns (uint remaining); // optional function
    function approve(address spender, uint tokens) external returns (bool success); // optional function
    function transferFrom(address from, address to, uint tokens) external returns (bool success); // optional function
    
    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

contract Cryptos is ERC20Interface {
    string public name = 'Cryptos';
    string public symbol = 'CRPT';
    uint public decimals = 0; //18
    uint public override totalSupply;

    address public founder;
    mapping(address => uint) public balances;
    mapping(address => mapping(address => uint)) public allowed;

    constructor() {
        totalSupply = 1000000;
        founder = msg.sender;
        balances[founder] = totalSupply;
    }

    function balanceOf(address tokenOwner) public view override returns(uint balance) {
        return balances[tokenOwner];
    }

    function transfer(address to, uint tokens) public virtual override returns (bool success) {
        require(balances[msg.sender] >= tokens, 'You dont have enough tokens in your account.');

        balances[msg.sender] -= tokens;
        balances[to] += tokens;
        emit Transfer(msg.sender, to, tokens);
        return true;
    }

    function allowance(address tokenOwner, address spender) public view override returns (uint remaining) {
        return allowed[tokenOwner][spender];
    }

    function approve(address spender, uint tokens) public override returns (bool success) {
        require(balances[msg.sender] >= tokens);
        require(tokens > 0);
        allowed[msg.sender][spender] = tokens;

        emit Approval(msg.sender, spender, tokens);

        return true;
    }

     function transferFrom(address from, address to, uint tokens) public virtual override returns (bool success) {
         require(allowed[from][msg.sender] >= tokens);
         require(balances[from] >= tokens);
         balances[from] -= tokens;
         balances[to] += tokens;
         allowed[from][msg.sender] -= tokens;

         emit Transfer(from, to, tokens);

         return true;
     }
}

contract CryptosICO is Cryptos {
    uint public tokenPrice = 0.001 ether;
    uint public minInvestment = 0.01 ether;
    uint public maxInvestment = 5 ether;
    uint public hardCap = 300 ether;
    uint public saleStart;
    uint public saleEnd;
    uint public tokenTradeStart;
    address public admin;
    address payable public depositAddress = payable(0xdD870fA1b7C4700F2BD7f44238821C26f7392148);
    address payable public burnAddress = payable(0x5c6B0f7Bf3E7ce046039Bd8FABdfD3f9F5021678);
    uint public raisedAmount;

    enum States {
        beforeStart,
        running,
        afterEnd,
        halted
    }

    States public icoState;

    constructor() {
        admin = msg.sender;
        saleStart = block.timestamp;
        saleEnd = saleStart + 604800;
        icoState = States.running;      
    }

    modifier onlyAdmin {
        require(msg.sender == admin);
        _;
    }

    event Invest(address investor, uint investment, uint cryptosTokens);

    function changeDepositAddress(address payable newDepositAddress) public onlyAdmin {
        depositAddress = payable(newDepositAddress);
    }

    function initiateIco(uint _end) public onlyAdmin {
        saleStart = block.timestamp;
        saleEnd = _end;
        icoState = States.running;
    }

    function stopIco() public onlyAdmin {
        icoState = States.halted;
    }

    function resumeIco() public onlyAdmin {
        icoState = States.running;
    }

    function getCurrentState() public view returns(States) {
        if (icoState == States.halted) {
            return States.halted;
        } else if (block.timestamp < saleStart) {
            return States.beforeStart;
        } else if (block.timestamp >= saleStart && block.timestamp <= saleEnd) {
            return States.running;
        } else {
            return States.afterEnd;
        }
    }

    function invest() public payable returns(bool) {
        require(msg.sender != founder, 'Founders cannot buy their own tokens.');
        require(msg.value >= minInvestment, 'Minimum investment is 0.01 ether.');
        require(msg.value <= maxInvestment, 'Invested value has to be less than 5 ether.');
        require(getCurrentState() == States.running, 'Time to buy CRYPTOS tokes is up.');
        raisedAmount += msg.value;
        require(raisedAmount <= hardCap);

        uint acquiredCryptosTokens = msg.value / tokenPrice; // multiplying and division has to be in same units, ether - ether, wei-wei, it cannot be ether - no unit(constant)
        balances[msg.sender] += acquiredCryptosTokens;
        balances[founder] -= acquiredCryptosTokens;
        depositAddress.transfer(msg.value);

        emit Invest(msg.sender, msg.value, acquiredCryptosTokens);

        return true;
    }

    receive() external payable {
        invest();
    }

    function transfer(address to, uint tokens) public override returns (bool success) {
        require(block.timestamp > tokenTradeStart);
        Cryptos.transfer(to, tokens); // super.transfer(to, tokens);
        return true;
    }

    function transferFrom(address from, address to, uint tokens) public virtual override returns (bool success) {
         require(block.timestamp > tokenTradeStart);
         super.transferFrom(from, to, tokens);
         return true;
     }

     function burn() public returns(bool) {
         require(getCurrentState() == States.afterEnd);
         balances[founder] = 0;
         return true;
     }

}