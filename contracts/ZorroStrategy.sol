// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./helpers/ERC20.sol";
import "./libraries/Address.sol";
import "./libraries/SafeERC20.sol";
import "./libraries/EnumerableSet.sol";
import "./helpers/Ownable.sol";
import "./interfaces/IPancakeswapFarm.sol";
import "./interfaces/IPancakeRouter01.sol";
import "./interfaces/IPancakeRouter02.sol";

interface IWBNB is IERC20 {
    function deposit() external payable;

    function withdraw(uint256 wad) external;
}

import "./helpers/ReentrancyGuard.sol";
import "./helpers/Pausable.sol";

contract ZorroStrategy is Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Constants
    // TODO - account for testnet vs mainnet 
    address public constant cakeTokenAddress = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    address public constant wbnbAddress = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public constant masterChefAddress = 0x73feaa1eE314F8c655E354234017bE2193C9E24E;

    // Variables
    uint256 public pid; // pid of pool in masterChefAddress
    address public pancakePairAddress; // Used to be "wantAddress"
    address public pancakeRouterAddress;
    address public token0Address;
    address public token1Address;
    // Ledger
    mapping(address => uint256) public sharesLedger; //(account address => amount)

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
    constructor(
        address _govAddress,
        address _pancakePairAddress,
        address _token0Address,
        address _token1Address,
        address _rewardsAddress,
        uint256 _pid,
        address[] memory _cakeToToken0Path,
        address[] memory _cakeToToken1Path,
        address[] memory _token0ToCakePath,
        address[] memory _token1ToCakePath,
        uint256 _controllerFee,
        uint256 _entranceFeeFactor
    ) public {
        govAddress = _govAddress;
        pancakePairAddress = _pancakePairAddress;
        token0Address = _token0Address;
        token1Address = _token1Address;
        rewardsAddress = _rewardsAddress;

        pid = _pid;

        cakeToToken0Path = _cakeToToken0Path;
        cakeToToken1Path = _cakeToToken1Path;
        token0ToCakePath = _token0ToCakePath;
        token1ToCakePath = _token1ToCakePath;

        controllerFee = _controllerFee;
        entranceFeeFactor = _entranceFeeFactor;

        pancakeRouterAddress = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

        transferOwnership(msg.sender);
    }

    // Events
    event SetSettings(
        uint256 _entranceFeeFactor,
        uint256 _controllerFee,
        uint256 _slippageFactor
    );
    event SetGov(address _govAddress);
    event SetOnlyGov(bool _onlyGov);
    event SetPancakeRouterAddress(address _uniRouterAddress);
    event SetRewardsAddress(address _rewardsAddress);

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    // Modifiers
    modifier onlyAllowGov() {
        require(msg.sender == govAddress, "!gov");
        _;
    }

    function deposit(uint256 _lpTokenAmt) public nonReentrant {
        if (_lpTokenAmt > 0) {
            uint256 sharesAdded = _deposit(_lpTokenAmt);
            sharesLedger[msg.sender] = sharesLedger[msg.sender].add(sharesAdded);
        }
        emit Deposit(msg.sender, pid, _lpTokenAmt);
    }

    // Receives new deposits
    function _deposit(uint256 _lpTokenAmt)
        public
        virtual
        onlyOwner
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        IERC20(pancakePairAddress).safeTransferFrom(
            address(msg.sender),
            address(this),
            _lpTokenAmt
        );

        // First depositor gets shares added equal to the number of LP tokens deposited
        uint256 sharesAdded = _lpTokenAmt;
        // All subsequent depositors get shares added equal to the number of LP tokens
        // deposited, minus entranceFee for protection against front-running, paid to existing vault users
        if (lpTokensLockedTotal > 0 && sharesTotal > 0) {
            sharesAdded = _lpTokenAmt
                .mul(sharesTotal)
                .mul(entranceFeeFactor)
                .div(lpTokensLockedTotal)
                .div(entranceFeeFactorMax);
        }
        // Increment the total number of shares by sharesAdded
        sharesTotal = sharesTotal.add(sharesAdded);

        _farm();

        return sharesAdded;
    }

    function farm() public virtual nonReentrant {
        _farm();
    }

    function _farm() internal virtual {
        uint256 lpTokenAmt = IERC20(pancakePairAddress).balanceOf(address(this));
        lpTokensLockedTotal = lpTokensLockedTotal.add(lpTokenAmt);
        IERC20(pancakePairAddress).safeIncreaseAllowance(masterChefAddress, lpTokenAmt);

        IPancakeswapFarm(masterChefAddress).deposit(pid, lpTokenAmt);
    }

    function _unfarm(uint256 _lpTokenAmt) internal virtual {
        IPancakeswapFarm(masterChefAddress).withdraw(pid, _lpTokenAmt);
    }

    function withdraw(uint256 _lpTokenAmt) public nonReentrant {
        require(sharesLedger[msg.sender] > 0, "user shares is 0");
        require(sharesTotal > 0, "sharesTotal is 0");

        // Withdraw LP tokens
        uint256 amount = sharesLedger[msg.sender].mul(lpTokensLockedTotal).div(sharesTotal);
        if (_lpTokenAmt > amount) {
            _lpTokenAmt = amount;
        }
        if (_lpTokenAmt > 0) {
            uint256 sharesRemoved = _withdraw(_lpTokenAmt);
            if (sharesRemoved > sharesLedger[msg.sender]) {
                sharesLedger[msg.sender] = 0;
            } else {
                sharesLedger[msg.sender] = sharesLedger[msg.sender].sub(sharesRemoved);
            }
        }
        emit Withdraw(msg.sender, pid, _lpTokenAmt);
    }

    function _withdraw(uint256 _lpTokenAmt)
        public
        virtual
        onlyOwner
        nonReentrant
        returns (uint256)
    {
        require(_lpTokenAmt > 0, "_lpTokenAmt <= 0");

        uint256 sharesRemoved = _lpTokenAmt.mul(sharesTotal).div(lpTokensLockedTotal);
        if (sharesRemoved > sharesTotal) {
            sharesRemoved = sharesTotal;
        }
        sharesTotal = sharesTotal.sub(sharesRemoved);

        _unfarm(_lpTokenAmt);

        uint256 lpTokenAmt = IERC20(pancakePairAddress).balanceOf(address(this));
        if (_lpTokenAmt > lpTokenAmt) {
            _lpTokenAmt = lpTokenAmt;
        }

        if (lpTokensLockedTotal < _lpTokenAmt) {
            _lpTokenAmt = lpTokensLockedTotal;
        }

        lpTokensLockedTotal = lpTokensLockedTotal.sub(_lpTokenAmt);

        IERC20(pancakePairAddress).safeTransfer(msg.sender, _lpTokenAmt);

        return sharesRemoved;
    }

    // 1. Harvest cake tokens
    // 2. Converts cake tokens into LP tokens
    // 3. Deposits LP tokens
    function earn() public virtual nonReentrant whenNotPaused {
        if (onlyGov) {
            require(msg.sender == govAddress, "!gov");
        }

        // Harvest Cake tokens
        _unfarm(0);

        // Converts Cake tokens into LP tokens
        uint256 earnedCakeAmt = IERC20(cakeTokenAddress).balanceOf(address(this));

        earnedCakeAmt = distributeFees(earnedCakeAmt);

        IERC20(cakeTokenAddress).safeApprove(pancakeRouterAddress, 0);
        IERC20(cakeTokenAddress).safeIncreaseAllowance(
            pancakeRouterAddress,
            earnedCakeAmt
        );

        if (cakeTokenAddress != token0Address) {
            // Swap half earned Cake to token0
            _safeSwap(
                pancakeRouterAddress,
                earnedCakeAmt.div(2),
                slippageFactor,
                cakeToToken0Path,
                address(this),
                block.timestamp.add(600)
            );
        }

        if (cakeTokenAddress != token1Address) {
            // Swap half earned Cake to token1
            _safeSwap(
                pancakeRouterAddress,
                earnedCakeAmt.div(2),
                slippageFactor,
                cakeToToken1Path,
                address(this),
                block.timestamp.add(600)
            );
        }

        // Get LP tokens, ie. add liquidity
        uint256 token0Amt = IERC20(token0Address).balanceOf(address(this));
        uint256 token1Amt = IERC20(token1Address).balanceOf(address(this));
        if (token0Amt > 0 && token1Amt > 0) {
            IERC20(token0Address).safeIncreaseAllowance(
                pancakeRouterAddress,
                token0Amt
            );
            IERC20(token1Address).safeIncreaseAllowance(
                pancakeRouterAddress,
                token1Amt
            );
            IPancakeRouter02(pancakeRouterAddress).addLiquidity(
                token0Address,
                token1Address,
                token0Amt,
                token1Amt,
                0,
                0,
                address(this),
                block.timestamp.add(600)
            );
        }

        lastEarnBlock = block.number;

        _farm();
    }

    function distributeFees(uint256 _earnedCakeAmt)
        internal
        virtual
        returns (uint256)
    {
        if (_earnedCakeAmt > 0) {
            // Performance fee
            if (controllerFee > 0) {
                uint256 fee =
                    _earnedCakeAmt.mul(controllerFee).div(controllerFeeMax);
                IERC20(cakeTokenAddress).safeTransfer(rewardsAddress, fee);
                _earnedCakeAmt = _earnedCakeAmt.sub(fee);
            }
        }

        return _earnedCakeAmt;
    }

    function convertDustToEarned() public virtual whenNotPaused {
        // Converts dust tokens into earned tokens, which will be reinvested on the next earn().
        // https://www.coindesk.com/bitcoin-dust-tell-get-rid 

        // Converts token0 dust (if any) to earned tokens
        uint256 token0Amt = IERC20(token0Address).balanceOf(address(this));
        if (token0Address != cakeTokenAddress && token0Amt > 0) {
            IERC20(token0Address).safeIncreaseAllowance(
                pancakeRouterAddress,
                token0Amt
            );

            // Swap all dust tokens to earned (CAKE) tokens
            _safeSwap(
                pancakeRouterAddress,
                token0Amt,
                slippageFactor,
                token0ToCakePath,
                address(this),
                block.timestamp.add(600)
            );
        }

        // Converts token1 dust (if any) to earned tokens
        uint256 token1Amt = IERC20(token1Address).balanceOf(address(this));
        if (token1Address != cakeTokenAddress && token1Amt > 0) {
            IERC20(token1Address).safeIncreaseAllowance(
                pancakeRouterAddress,
                token1Amt
            );

            // Swap all dust tokens to earned tokens
            _safeSwap(
                pancakeRouterAddress,
                token1Amt,
                slippageFactor,
                token1ToCakePath,
                address(this),
                block.timestamp.add(600)
            );
        }
    }

    /* Maintenance */
    function pause() public virtual onlyAllowGov {
        _pause();
    }

    function unpause() public virtual onlyAllowGov {
        _unpause();
    }

    function setSettings(
        uint256 _entranceFeeFactor,
        uint256 _controllerFee,
        uint256 _slippageFactor
    ) public virtual onlyAllowGov {
        require(
            _entranceFeeFactor >= entranceFeeFactorLL,
            "_entranceFeeFactor too low"
        );
        require(
            _entranceFeeFactor <= entranceFeeFactorMax,
            "_entranceFeeFactor too high"
        );
        entranceFeeFactor = _entranceFeeFactor;

        require(_controllerFee <= controllerFeeUL, "_controllerFee too high");
        controllerFee = _controllerFee;

        require(
            _slippageFactor <= slippageFactorUL,
            "_slippageFactor too high"
        );
        slippageFactor = _slippageFactor;

        emit SetSettings(
            _entranceFeeFactor,
            _controllerFee,
            _slippageFactor
        );
    }

    function setGov(address _govAddress) public virtual onlyAllowGov {
        govAddress = _govAddress;
        emit SetGov(_govAddress);
    }

    function setOnlyGov(bool _onlyGov) public virtual onlyAllowGov {
        onlyGov = _onlyGov;
        emit SetOnlyGov(_onlyGov);
    }

    function setPancakeRouterAddress(address _pancakeRouterAddress)
        public
        virtual
        onlyAllowGov
    {
        pancakeRouterAddress = _pancakeRouterAddress;
        emit SetPancakeRouterAddress(_pancakeRouterAddress);
    }

    function setRewardsAddress(address _rewardsAddress)
        public
        virtual
        onlyAllowGov
    {
        rewardsAddress = _rewardsAddress;
        emit SetRewardsAddress(_rewardsAddress);
    }

    function inCaseTokensGetStuck(
        address _token,
        uint256 _amount,
        address _to
    ) public virtual onlyAllowGov {
        require(_token != cakeTokenAddress, "!safe");
        require(_token != pancakePairAddress, "!safe");
        IERC20(_token).safeTransfer(_to, _amount);
    }

    function _wrapBNB() internal virtual {
        // BNB -> WBNB
        uint256 bnbBal = address(this).balance;
        if (bnbBal > 0) {
            IWBNB(wbnbAddress).deposit{value: bnbBal}(); // BNB -> WBNB
        }
    }

    function wrapBNB() public virtual onlyAllowGov {
        _wrapBNB();
    }

    function _safeSwap(
        address _pancakeRouterAddress,
        uint256 _amountIn,
        uint256 _slippageFactor,
        address[] memory _path,
        address _to,
        uint256 _deadline
    ) internal virtual {
        uint256[] memory amounts =
            IPancakeRouter02(_pancakeRouterAddress).getAmountsOut(_amountIn, _path);
        uint256 amountOut = amounts[amounts.length.sub(1)];

        IPancakeRouter02(_pancakeRouterAddress)
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amountIn,
            amountOut.mul(_slippageFactor).div(1000),
            _path,
            _to,
            _deadline
        );
    }
}