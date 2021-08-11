// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

// Dependencies
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IBEP20.sol";
import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/IPancakePair.sol";
import "./interfaces/IZorroStrategy.sol";
import './libraries/SafeMath.sol';


contract ZorroStrategy is IZorroStrategy, IBEP20 {
    // TODO: Replace w/ SafeMath operations everywhere
    using SafeMath  for uint;

    /* Types */
    enum PriceCalculationMethod {
        AOnly,
        AInverse,
        AMultipliedByB,
        ADividedByB
    }
    struct TokenMeta {
        AggregatorV3Interface priceFeed0;
        AggregatorV3Interface priceFeed1;
        PriceCalculationMethod priceCalculationMethod;
    }

    /* Constants */
    IPancakeRouter02 public constant routerContract = IPancakeRouter02("0x10ED43C718714eb63d5aA57B78B54704E256024E");
    IBEP20 public constant BUSDC = IBEP20("0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d");
    TokenMeta public constant USDCBNBTokenMeta = TokenMeta(AggregatorV3Interface("0x45f86CA2A8BC9EBD757225B19a1A0D7051bE46Db"), AggregatorV3Interface("0x0"), PriceCalculationMethod(1));

    /* Variables */
    // Core contract
    address[] public activeAccounts;
    IPancakePair public lpContract;
    TokenMeta public tokenMetaA;
    TokenMeta public tokenMetaB;
    address public tokenA;
    address public tokenB;
    // TODO - this needs to be adjustable
    uint public slippageTolerancePct = 1;
    // TODO - fill this amount in, allow owner to change?
    uint256 public constant investmentGasFee = 5 gwei;

    // Performance
    // TODO - allow this to be reset
    uint public zorroPerformanceFeePct = 25;
    // TODO - allow this to be reset
    uint public minProfitTakingIntervalSecs;
    uint public tokenARewards;
    uint public tokenBRewards;
    uint public lastEarningTime;
    

    // BEP-20 variable implementations
    string public name;
    string public symbol;
    uint8 public decimals;
    uint public totalSupply;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    /* Events */
    event InvestmentComplete(address _sender, uint256 _value);
    event WithdrawalComplete(address _recipient, uint256 _value);

    /* Modifiers */
    modifier ownerOnly {
        require(msg.sender == owner, "Only the owner of this contract can run this function");
        _;
    }

    // Constructor
    constructor (
        address _lpContractAddress, 
        address _priceFeedA0, address _priceFeedA1, uint _priceCalcMethodA, 
        address _priceFeedB0, address _priceFeedB1, uint _priceCalcMethodB, 
        string _name, string _symbol, uint8 _decimals) public {
        owner = msg.sender;
        lpContract = IPancakePair(_lpContractAddress);

        tokenMetaA = TokenMeta(AggregatorV3Interface(_priceFeedA0), AggregatorV3Interface(_priceFeedA1), PriceCalculationMethod(_priceCalcMethodA));
        tokenMetaB = TokenMeta(AggregatorV3Interface(_priceFeedB0), AggregatorV3Interface(_priceFeedB1), PriceCalculationMethod(_priceCalcMethodB));
        tokenA = lpContract.token0();
        tokenB = lpContract.token1();

        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    // Functions
    function compoundInvestments(address[] calldata wallets) external ownerOnly {
        // Reinvests yield farm earnings back into protocol

        // Compare current total rewards against last total rewards
        
        // If there is a profit, remove associated reward amount. If not, skip
        // Extract performance fee
        // Subtract reward
        // Remove liquidity
        // Reinvest remainder
        // Mark last total reward and time on the ledger 

        // -- OLD -- 
        // Iterates through all active customer wallets and compounds their investments while taking a fee
        // TODO - Prevent this function from being run too often and consuming too much gas. 
        // Get underlying token supplies
        uint totalSupplyA = IBEP20(tokenA).totalSupply();
        uint totalSupplyB = IBEP20(tokenB).totalSupply();
        uint balance0 = IBEP20(tokenA).balanceOf(address(this));
        uint balance1 = IBEP20(tokenB).balanceOf(address(this));

        // Iterate through wallets
        for (uint i=0;i<wallets.length;i++) {
            address wallet = wallets[i];
            // Calculate amounts of tokens A, B based on current liquidity amount 
            uint liquidity = balanceOf[wallet];
            uint amount0 = liquidity.mul(balance0) / totalSupplyA;
            uint amount1 = liquidity.mul(balance1) / totalSupplyB;
            // Compare amounts for underlying tokens A, B to last profit taking event time

        }
        // If a profit was made, remove liquidity. If not, continue to next wallet (do nothing)
        // Profit calculation must account for cash flows since last profit taking period
        // Take Zorro fee as a percentage of profits and send this to the Zorro wallet
        // Take the remainder and add it back as liqudity to the protocol
    }

    function _extractFeeForGasAirdrop() internal {

    }

    function _takeZorroPerformanceFee() internal {

    }

    function invest(uint256 amountUSDC) external {
        /* Invests an amount in USDC by taking the corresponding amount from the caller's wallet address */
        // NOTE: Requires msg.sender to have previously approved this contract address as a spender of USDC
        // Must be lte to amount in origin
        uint256 walletBalance = BUSDC.balanceOf(msg.sender);
        require(walletBalance >= amountUSDC, "Caller's wallet has insufficient USDC balance for investment");
        // Transfer amount of BUSDC, minus gas (estimated gas value that can be set by owner)
        BUSDC.transferFrom(msg.sender, address(this), amountUSDC);
        // Trigger swaps for each currency in the pair
        // Collect fees for network/gas charges that Zorro fronted
        // TODO - consider the ability to waive or reduce these fees for large investments etc. 
        // Convert BNB to USDC equivalent and subtract this and submit to Zorro to compensate for gas fees. 
        uint256 gasFeeBNB = investmentGas * gasPrice;
        uint256 gasFeeUSDC = gasFeeBNB * getLatestPriceForToken(USDCBNBTokenMeta);
        uint256 netUSDCToInvest = amountUSDC - gasFeeUSDC;

        // TODO - can this be DRYd up?
        // Start swapping
        uint256 amountADesired = 0;
        uint256 amountBDesired = 0;
        // If one of the currencies is already USDC, skip swap
        if (tokenA == address(BUSDC)) {
            amountAReceived = netUSDCToInvest * 0.5;
        } else {
            address[] memory pathA = new address[](2);
            pathA[0] = address(BUSDC);
            pathA[1] = tokenA;
            uint256 amountOutMinA = getLatestPriceForToken(tokenMetaA);
            amountADesired = routerContract.swapExactTokensForTokens(netUSDCToInvest * 0.5, amountOutMinA, pathA, address(this), block.timestamp)[1];
        }
        if (tokenB != address(BUSDC)) {
            amountBReceived = netUSDCToInvest * 0.5;
        } else {
            address[] memory pathB = new address[](2);
            pathB[0] = address(BUSDC);
            pathB[1] = tokenB;
            uint256 amountOutMinB = getLatestPriceForToken(tokenMetaB);
            amountBDesired = routerContract.swapExactTokensForTokens(netUSDCToInvest * 0.5, amountOutMinB, pathB, address(this), block.timestamp)[1];
        }
        // Add liquidity to contract
        uint amountAMin = amountADesired * (100 - slippageTolerancePct) / 100;
        uint amountBMin = amountBDesired * (100 - slippageTolerancePct) / 100;
        (uint amountASent, uint amountBSent, uint liquidity) = routerContract.addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, address(this), block.timestamp);

        // Store LP tokens in balance
        _mint(msg.sender, liquidity);
        // Emit event
        emit InvestmentComplete(msg.sender, liquidity);
    }

    function getLatestPriceForToken(TokenMeta memory tokenMeta) internal view returns (int) {
        int priceA = getLatestPrice(tokenMeta.priceFeed0);
        if (uint8(tokenMeta.priceCalculationMethod) == 0) {
            return priceA;
        } else if (uint(tokenMeta.priceCalculationMethod) == 1) {
            return 1/priceA;
        } else if (uint(tokenMeta.priceCalculationMethod) == 2) {
            int priceB = getLatestPrice(tokenMeta.priceFeed1);  
            return priceA * priceB;
        } else if (uint(tokenMeta.priceCalculationMethod) == 3) {
            int priceB = getLatestPrice(tokenMeta.priceFeed1);  
            return priceA / priceB;
        }
    }

    function getLatestPrice(AggregatorV3Interface priceFeed) internal view returns (int) {
        (
            uint80 roundID, 
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        return price;
    }

    function withdraw(address to, uint256 liquidity, uint256 amountAMinBeforeFees, uint256 amountBMinBeforeFees) external {
        /* Removes liquidity, consolidates to USDC, and transfer to recipient address specified */
        // TODO: Consider if there's a way to avoid having to input amountAMinBeforeFees, and B, by using an Oracle etc. 
        // TODO: Any withdrawal methods in the IBEP20 interface need to first extract a profit
        // TODO: Make sure only true owner of LP tokens can withdraw their money
        // Burn Zorro LP token
        _burn(msg.sender, liquidity);
        // Remove liquidity
        (uint amountAReceived, uint amountBReceived) = routerContract.removeLiquidity(tokenA, tokenB, liquidity, amountAMinBeforeFees, amountBMinBeforeFees, address(this), block.timestamp);
        // Take fee - TODO - send to wallet too? 
        uint amountAAfterFee = amountAReceived * (100 - zorroPerformanceFeePct) / 100;
        uint amountBAfterFee = amountBReceived * (100 - zorroPerformanceFeePct) / 100;

        // Consolidate to USDC if not already USDC
        uint256 amountAInUSDC = 0;
        uint256 amountBInUSDC = 0;
        if (tokenA != address(BUSDC)) {
            amountAInUSDC = amountAAfterFee;
        } else {
            address[] pathA = new address[](2);
            pathA[0] = tokenA;
            pathA[1] = address(BUSDC);
            uint amountOutMinA = getLatestPriceForToken(tokenMetaA) * (100 - slippageTolerancePct) / 100;
            amountAInUSDC = routerContract.swapExactTokensForTokens(amountAAfterFee, amountOutMinA, pathA, address(this), block.timestamp)[1];
        }
        if (tokenB != address(BUSDC)) {
            amountAInUSDC = amountAAfterFee;
        } else {
            address[] pathB = new address[](2);
            pathB[0] = tokenB;
            pathB[1] = address(BUSDC);
            uint amountOutMinB = getLatestPriceForToken(tokenMetaB) * (100 - slippageTolerancePct) / 100;
            amountBInUSDC = routerContract.swapExactTokensForTokens(amountBAfterFee, amountOutMinB, pathB, address(this), block.timestamp)[1];
        }
        // Transfer to recipient
        uint totalInUSDC = amountAInUSDC + amountBInUSDC;
        BUSDC.transfer(msg.sender, totalInUSDC);
        emit WithdrawalComplete(msg.sender, totalInUSDC);
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