// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

// Dependencies
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IBEP20.sol";
import "./interfaces/IPancakeRouter02.sol";

contract ZorroStrategy {
    /* Types */
    enum PriceCalculationMethod {
        AOnly,
        AInverse,
        AMultipliedByB,
        ADividedByB
    }
    struct LPContract {
        address ammContractAddress;
        address tokenA;
        address tokenB;
    }
    struct TokenMeta {
        AggregatorV3Interface priceFeedA;
        AggregatorV3Interface priceFeedB;
        PriceCalculationMethod priceCalculationMethod;
        bool initialized;

    }
    /* Constants */
    IPancakeRouter02 router = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    // TODO - Make absolutely certain is the correct USDC. There seem to be many.
    IBEP20 USDC = IBEP20(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);

    
    /* Variables */
    // Key addresses / ownership
    address owner;
    // Strategies
    mapping(string => LPContract[]) public lpContracts;
    // Price feed (Chainlink)
    mapping(address => TokenMeta) internal tokenMetaInfo;
    AggregatorV3Interface priceFeedBNBUSD = AggregatorV3Interface(0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE);
    // Balances of wallets by address, by token
    mapping(address => mapping(address => uint)) public bep20TokenBalances;
    // Array of all Zorro wallets
    address[] public wallets;


    // Financial paramters
    uint16 public compoundingFrequencyDays;
    uint8 public performanceFeePercent;
    uint8 slippageTolerancePercent = 1;
    uint256 reservesForFeesETH = 18 finney; // About $5 in BNB at time of writing
    
    // Accounting
    mapping(address => uint256) public liquidityTokenLedger;
    mapping(address => uint256) public lastFeeTakenAmount;
    mapping(address => uint64) public lastFeeTakenAt;
    mapping(address => uint256) public lastProfitAmountPreFees;

    // Events
    event AddedContract(string strategy, address contractAddress, uint numContractsInStrategy);
    event RemovedContract(string strategy, address contractAddress, uint numContractsInStrategy);
    event AddedLiquidity(string strategy, uint256 amountTotal, uint256 liquidityEarned);

    // Modifiers
    modifier onlyOwner {
        require(msg.sender == owner, "Only the owner of this contract can perform this action.");
        _;
    }

    // Constructor
    constructor () public {
        // Mark owner of the contract
        owner = msg.sender;
        // Set initial fee-taking parameters
        performanceFeePercent = 30;
        compoundingFrequencyDays = 30;
        // TODO: Set lpContracts for each strategy to begin with
        lpContracts["stablecoin"].push(LPContract(0xEc6557348085Aa57C72514D67070dC863C0a5A8c, 0x55d398326f99059fF775485246999027B3197955, 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d));
        // TODO: Set ChainLink price feed contracts for each strategy to begin with
        tokenMetaInfo[0x55d398326f99059fF775485246999027B3197955] = TokenMeta(AggregatorV3Interface(0xB97Ad0E74fa7d920791E90258A6E2085088b4320), AggregatorV3Interface(0x51597f405303C4377E36123cBc172b13269EA163), PriceCalculationMethod(0), true);
        // TODO: Separate out this information for testnet vs mainnet
        // TODO: ETH terminology is confusing.
    }

    // State-changing methods
    function invest(string calldata strategy, address customerWallet, uint investmentAmountUSD) external {
        // TODO - Make sure to use safe maths library

        /*
        - Swap a small amount of Binance USDC to BNB and send to Zorro to pay for gas fees
        - Add customer wallet to wallets array
        - Iterate through all LP contracts in the specified strategy and calculate the required allocation for each token
        - - Swap as necessary to get all the required tokens, w/ destination address of swap being Zorro
        - Add liquidity to each contract
        - - Update the ledger of this contract to reflect liquidity balances
        */


        uint256 grossAllocatableFunds = msg.value; // Does not include fees yet
        uint256 netAllocatableFundsETH = grossAllocatableFundsETH - reservesForFeesETH;
        // Requirements
        require(msg.value > 0, "Message must have a value greater than 0");

        // Prep variables
        LPContract[] memory strategyContracts = lpContracts[strategy]; 
        address[] memory allocatableTokens = new address[](strategyContractsLength * 2);
        uint256[] memory allocatableFundsByTokenBNB = new uint256[](strategyContractsLength * 2);
        int latestBNBPrice = getLatestPrice(priceFeedBNBUSD);
        
        // Add wallet if does not exist
        bool walletDoesExist = false;
        for (uint i=0; i<wallets.length; i++) {
            if (wallets[i] == msg.sender) {
                walletDoesExist = true;
                break;
            }
        }
        if (!walletDoesExist) {
            wallets.push(msg.sender);
        }
        
        // Determine the amount of each token to allocate. (2 tokens per pair)
        uint256 allocationAmountPerTokenBNB = (netAllocatableFundsBNB / (strategyContracts.length * 2));

        // Iterates through accepted LP contracts for this strategy
        for (uint16 i=0;i<strategyContracts.length;i++) {
            // Determine indexes for each token in pair
            LPContract memory strategyContract = strategyContracts[i];
            int16 tokenAIndex = -1;
            int16 tokenBIndex = -1;
            for (uint16 j=0;j<allocatableTokens.length;j++) {
                if (allocatableTokens[j] == strategyContract.tokenA) {
                    tokenAIndex = int16(j);
                } else if (allocatableTokens[j] == strategyContract.tokenB) {
                    tokenBIndex = int16(j);
                }
            }
            
            // Update allocatable funds for each token
            int16 latestUpdatedIndexA = -1;
            int16 latestUpdatedIndexB = -1;
            if (tokenAIndex >= 0) {
                // If token is already present, increment the allocatable amount for that token
                allocatableFundsByTokenETH[uint16(tokenAIndex)] += allocationAmountPerTokenETH;
            } else {
                // If token is not present in allocations array yet, append its address and allocatable amount
                allocatableTokens[uint16(latestUpdatedIndexA + 1)] = strategyContract.tokenA;
                allocatableFundsByTokenETH[uint16(latestUpdatedIndexA + 1)] = allocationAmountPerTokenETH;
            }
            if (tokenBIndex >= 0) {
                // If token is already present, increment the allocatable amount for that token
                allocatableFundsByTokenETH[uint16(tokenBIndex)] += allocationAmountPerTokenETH;
            } else {
                // If token is not present in allocations array yet, append its address and allocatable amount
                allocatableTokens[uint16(latestUpdatedIndexB + 1)] = strategyContract.tokenB;
                allocatableFundsByTokenETH[uint16(latestUpdatedIndexB + 1)] = allocationAmountPerTokenETH;
            }
        }
        
        // Iterate through all allocatableTokens and swap to obtain proper allocations
        for (uint16 i=0;i<allocatableTokens.length;i++) {
            address token = allocatableTokens[i];
            if (token == address(USDC)) {
                // We already have USDC, skip
                continue;
            }
            uint256 amountInETH = allocatableFundsByTokenETH[i];
            TokenMeta memory tokenMeta = tokenMetaInfo[token];
            // Use Chainlink as oracle to get fair pricing
            int latestTokenPriceUSD = getLatestPriceForToken(tokenMeta);
            uint256 amountInUSD = amountInETH * uint(latestETHPrice);
            
            // Approve transaction for BEP20 token
            // TODO - approval only needs to be done once, upon first investment
            require(USDC.approve(address(router), amountInUSD), "Approval by router failed");
            // Perform swap
            address[] memory path = new address[](2);
            path[0] = address(USDC);
            path[1] = token;
            // Calculate min output amount, accounting for slippage tolerance
            uint256 amountOutMin = (amountInUSD / uint(latestTokenPriceUSD)) * ((100 - slippageTolerancePercent)/100);
            uint256[] memory amounts = router.swapExactTokensForTokens(amountInUSD, amountOutMin, path, msg.sender, block.timestamp);
        }
        
        // Iterates through each LP contract and add liquidity
        for (uint16 i=0;i<strategyContracts.length;i++) {
            LPContract memory strategyContract = strategyContracts[i];
            // Get latest prices from oracles and calculate fair exchange rates 
            TokenMeta memory tokenMetaA = tokenMetaInfo[strategyContract.tokenA];
            TokenMeta memory tokenMetaB = tokenMetaInfo[strategyContract.tokenB];
            int latestTokenPriceA = getLatestPriceForToken(tokenMetaA);
            int latestTokenPriceB = getLatestPriceForToken(tokenMetaB);
            uint256 amountInUSD = allocationAmountPerTokenETH * uint(latestETHPrice);
            
            // Calculate desired amounts
            uint amountADesired = amountInUSD / uint(latestTokenPriceA);
            uint amountBDesired = amountInUSD / uint(latestTokenPriceB);
            // For slippage
            uint amountAMin = ((100 - slippageTolerancePercent)/100) * amountADesired;
            uint amountBMin = ((100 - slippageTolerancePercent)/100) * amountBDesired;
            (
                uint amountANormal,
                uint amountBNormal, 
                uint liquidityNormal
            ) = router.addLiquidity(strategyContract.tokenA, strategyContract.tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, address(this), block.timestamp);
            // Store liquidity token in ledger 
            liquidityTokenLedger[msg.sender] += liquidityNormal;   
        }

        // Notify - TODO

    }

    function getLatestPriceForToken(TokenMeta memory tokenMeta) internal view returns (int) {
        int priceA = getLatestPrice(tokenMeta.priceFeedA);
        if (uint8(tokenMeta.priceCalculationMethod) == 0) {
            return priceA;
        } else if (uint8(tokenMeta.priceCalculationMethod) == 1) {
            return 1/priceA;
        } else if (uint8(tokenMeta.priceCalculationMethod) == 2) {
            int priceB = getLatestPrice(tokenMeta.priceFeedB);  
            return priceA * priceB;
        } else if (uint8(tokenMeta.priceCalculationMethod) == 3) {
            int priceB = getLatestPrice(tokenMeta.priceFeedB);  
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

    function withdraw() external {
        // TODO
    }

    function takeProfit() external onlyOwner {
        
    }

    function setCompoundingFrequency(uint16 minElapsedDays) external onlyOwner {
        // Sets the max frequency of compounding (and thus profit-taking) to a value in days.
        compoundingFrequencyDays = minElapsedDays;
    }

    function setZorroPerformanceFeePercent(uint8 feePct) external onlyOwner {
        // Sets performance fee percentage to a new value.
        require(feePct >= 0 && feePct <= 100, "Percent must be a value between 0 and 100.");
        performanceFeePercent = feePct;
    }

    function changeOwner(address newOwner) external onlyOwner {
        // Changes the owner of this contract
        owner = newOwner;
    }
    
    function setFeesReserve(uint256 reserveAmount) external onlyOwner {
        reservesForFeesETH = reserveAmount;
    }

    function addLPContractToStrategy(address contractAddress, string calldata strategy, address tokenA, address tokenB, address priceFeedA1, address priceFeedA2, address priceFeedB1, address priceFeedB2, uint8 priceCalculationMethod) external onlyOwner {
        // TODO - check to make sure there is a corresponding Chainlink oracle address
        // Get current contracts associated with strategy provided
        LPContract[] storage strategyContracts = lpContracts[strategy];
        // Check to make sure contract doesn't already exist
        for (uint16 i=0;i<strategyContracts.length;i++) {
            if (strategyContracts[i].ammContractAddress == contractAddress) {
                require(false, "Contract address already exists for this strategy");
            }
        }
        // Add contract
        LPContract memory lpContract = LPContract(contractAddress, tokenA, tokenB);
        strategyContracts.push(lpContract);
        lpContracts[strategy] = strategyContracts;
        // Add token metadata if applicable
        // priceFeedA, priceFeedB, PriceCalculationMethod(priceCalculationMethod)
        // Add Oracle if does not exist
        addTokenMetadataIfNotExists(tokenA, priceFeedA1, priceFeedA2, PriceCalculationMethod(priceCalculationMethod));
        addTokenMetadataIfNotExists(tokenB, priceFeedB1, priceFeedB2, PriceCalculationMethod(priceCalculationMethod));
        // Notify
        emit AddedContract(strategy, contractAddress, lpContracts[strategy].length);
    }

    function addTokenMetadataIfNotExists(address tokenAddress, address priceFeedA, address priceFeedB, PriceCalculationMethod priceCalculationMethod) internal {
        if (!tokenMetaInfo[tokenAddress].initialized) {
            tokenMetaInfo[tokenAddress] = TokenMeta(AggregatorV3Interface(priceFeedA), AggregatorV3Interface(priceFeedB), priceCalculationMethod, true);
        }
    }

    function removeLPContractFromStrategy(address contractAddress, string calldata strategy) external onlyOwner {
        // Get current contracts associated with strategy provided
        LPContract[] storage strategyContracts = lpContracts[strategy];
        // Check to make sure contract exists
        int16 matchingIndex = -1;
        for (uint16 i=0;i<strategyContracts.length;i++) {
            if (strategyContracts[i].ammContractAddress == contractAddress) {
                matchingIndex = int16(i);
                break;
            }
        }
        // If does not exist, revert
        require(matchingIndex >= 0, "Matching contract address could not be found for this strategy");
        // If does exist, remove contract and notify (Delete while preserving order)
        for (uint16 i=0;i<strategyContracts.length-1;i++) {
            strategyContracts[i] = strategyContracts[i+1];
        }
        strategyContracts.pop();
        
        // Modify contract state with shortened array and notify
        lpContracts[strategy] = strategyContracts;
        emit RemovedContract(strategy, contractAddress, lpContracts[strategy].length);

        // TODO - remove tokenmetainfo for a removed token so long as it's not used by other contracts
    }
    
    fallback () external payable {
        // TODO - fallback function. For accepting native currency from removeLiquidityETH.
    }
}