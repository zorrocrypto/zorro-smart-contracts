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
    address public pancakePairAddress; // Used to be "wantAddress"
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
    constructor(
        address[] memory _addresses,
        uint256 _pid,
        address[] memory _cakeToToken0Path,
        address[] memory _cakeToToken1Path,
        address[] memory _token0ToCakePath,
        address[] memory _token1ToCakePath,
        uint256 _controllerFee,
        uint256 _entranceFeeFactor
    ) public {
        wbnbAddress = _addresses[0];
        govAddress = _addresses[1];
        pancakePairAddress = _addresses[2];
        token0Address = _addresses[3];
        token1Address = _addresses[4];
        pancakeRouterAddress = _addresses[5];
        rewardsAddress = _addresses[6];

        pid = _pid;

        cakeToToken0Path = _cakeToToken0Path;
        cakeToToken1Path = _cakeToToken1Path;
        token0ToCakePath = _token0ToCakePath;
        token1ToCakePath = _token1ToCakePath;

        controllerFee = _controllerFee;
        buyBackRate = _buyBackRate;
        entranceFeeFactor = _entranceFeeFactor;

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
    event SetUniRouterAddress(address _uniRouterAddress);
    event SetBuyBackAddress(address _buyBackAddress);
    event SetRewardsAddress(address _rewardsAddress);

    // Modifiers
    modifier onlyAllowGov() {
        require(msg.sender == govAddress, "!gov");
        _;
    }

    // Receives new deposits from user
    function deposit(uint256 _lpTokenAmt)
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
        // deposited, minus entranceFee for security
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

    function withdraw(address _userAddress, uint256 _lpTokenAmt)
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

        uint256 lpTokenAmt = IERC20(wantAddress).balanceOf(address(this));
        if (_lpTokenAmt > lpTokenAmt) {
            _lpTokenAmt = lpTokenAmt;
        }

        if (lpTokensLockedTotal < _lpTokenAmt) {
            _lpTokenAmt = lpTokensLockedTotal;
        }

        lpTokensLockedTotal = lpTokensLockedTotal.sub(_lpTokenAmt);

        // Must have a way of verifying this is the correct recipient and is entitled to these funds
        IERC20(pancakePairAddress).safeTransfer(msg.sender, _lpTokenAmt);

        return sharesRemoved;
    }

    function earn() {

    }
}