contract ZorroStrategy {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Constants
    address public constant cakeTokenAddress = "0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82";
    address public constant pancakeRouterAddress = "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c";
    address public constant wbnbAddress = "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c";
    address public constant masterChefAddress = "0x73feaa1ee314f8c655e354234017be2193c9e24e";

    // Variables
    uint256 public pid; // pid of pool in masterChefAddress
    address public pancakePairAddress;
    address public token0Address;
    address public token1Address;

    address public govAddress; // Timelock contract
    bool public onlyGov = true; // If true, only allows governor address (Timelock contract) to perform actions

    uint256 public lastEarnBlock = 0;
    uint256 public lpTokensLockedTotal = 0; // Used to be "wantLockedTotal"
    uint256 public sharesTotal = 0;

    // Performance fees
    uint256 public controllerFee = 0; // 100 = 1%
    uint256 public constant controllerFeeMax = 10000; 
    uint256 public constant controllerFeeUL = 5000; // (UL = "upper limit")
    address public rewardsAddress; // Where to send performance fees to

    // TODO - understand front running and how AUTO do this better
    uint256 public entranceFeeFactor = 9990; // < 0.1% entrance fee - goes to pool + prevents front-running
    uint256 public constant entranceFeeFactorMax = 10000;
    uint256 public constant entranceFeeFactorLL = 9950; // 0.5% is the max entrance fee settable. LL = lowerlimit

    // Slippage
    uint256 public slippageFactor = 950; // 5% default slippage tolerance
    uint256 public constant slippageFactorUL = 995;

    // Swap routing
    address[] public cakeToToken0Path;
    address[] public cakeToToken1Path;
    address[] public token0ToCakePath;
    address[] public token1ToCakePath;

    // Constructor
    constructor() {

    }

    function deposit(uint256 _amount) public {
        // Transfer from 
    }

    function earn() {

    }

    function withdraw() {

    }
}