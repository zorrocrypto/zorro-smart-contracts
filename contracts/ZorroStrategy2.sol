// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

// Dependencies
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IBEP20.sol";
import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/IZorroStrategy.sol";
import './libraries/SafeMath.sol';

contract ZorroStrategy is IZorroStrategy, IBEP20 {
    /* Variables */
    // Core contract
    address[] public activeAccounts;
    IBEP20 public underlyingContract;
    address public tokenA;
    // BEP-20 variable implementations
    string public name;
    string public symbol;
    uint8 public decimals;
    uint public totalSupply;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;


    // Modifiers
    modifier ownerOnly {
        require(msg.sender == owner, "Only the owner of this contract can run this function");
        _;
    }

    // Constructor
    constructor (address _underlyingContractAddress, string _name, string _symbol, uint8 _decimals) public {
        owner = msg.sender;
        underlyingContract = IBEP20(_underlyingContractAddress);
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    // Functions
    function compoundInvestments() external {
        
    }

    function _extractFeeForGasAirdrop() internal {

    }

    function _takeZorroPerformanceFee() internal {

    }

    function invest() internal {
        // Trigger swaps for each currency in the pair
        // Collect fees for network/gas charges that Zorro fronted
        // Add liquidity to contract
        // Store LP tokens in balance

    }

    function withdraw() internal {
        // TODO: Any withdrawal methods in the IBEP20 interface need to first extract a profit

    }

    // BEP20 event implementations
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    // BEP20 function implementations
    function transfer(address to, uint256 value) public returns (bool success) {
         _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        if (allowance[from][msg.sender] != uint(-1)) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        _approve(msg.sender, _spender, _value);
        return true;
    }

    // Supporting functions for BEP-20 conformance
    function _approve(address owner, address spender, uint value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(address from, address to, uint value) private {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    function _mint(address to, uint value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Transfer(from, address(0), value);
    }
}