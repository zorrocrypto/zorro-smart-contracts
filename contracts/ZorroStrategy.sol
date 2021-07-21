// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.6 <0.9.0;

// Dependencies
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";

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
        address pricefeedA;
        address pricefeedB;
        PriceCalculationMethod priceCalculationMethod;
    }
    /* Constants */

    /* Variables */
    // Key addresses / ownership
    address owner;
    // Strategies
    mapping(string => LPContract[]) public lpContracts;
    // Price feed (Chainlink) - maps 
    mapping(address => address) public priceFeedMaps;


    // Financial paramters
    uint16 public compoundingFrequencyDays;
    uint8 public performanceFeePercent;

    // Mappings?
    mapping(address => uint256) public lastFeeTakenAmount;
    mapping(address => uint64) public lastFeeTakenAt;
    mapping(address => uint256) public lastProfitAmountPreFees;

    // mapping (address => uint256) public balances;

    // Events
    event AddedContract(string strategy, address contractAddress, uint numContractsInStrategy);
    event RemovedContract(string strategy, address contractAddress, uint numContractsInStrategy);
    // TODO - remove
    event TmpBeforeAppendToken(uint arrLength);

    // Modifiers
    modifier onlyOwner {
        require(msg.sender == owner, "Only the owner of this contract can perform this action.");
        _;
    }

    // Constructor
    constructor () {
        // Mark owner of the contract
        owner = msg.sender;
        // Set initial fee-taking parameters
        performanceFeePercent = 30;
        compoundingFrequencyDays = 30;
        // TODO: Set lpContracts for each strategy to begin with
        // TODO: Set ChainLink price feed contracts for each strategy to begin with
        // TODO: Separate out this information for testnet vs mainnet
    }

    // State-changing methods
    function invest(string memory strategy) external payable {
        // TODO - How do we know we have enough fees to complete this entire transaction?
        // TODO - Make sure to use safe maths library
        uint256 allocatableFunds = msg.value; // TODO: - minus fees 
        // Requirements
        require(msg.value > 0, "Message must have a value greater than 0");

        // Prep variables
        LPContract[] memory strategyContracts = lpContracts[strategy]; 
        uint256 strategyContractsLength = strategyContracts.length;
        address[] memory allocatableTokens = new address[](strategyContractsLength * 2);
        uint256[] memory allocatableFundsByToken = new uint256[](strategyContractsLength * 2);

        
        // Determine the amount of each token to allocate. (2 tokens per pair)
        uint256 allocationAmountPerToken = (allocatableFunds / (strategyContractsLength * 2));

        // Iterates through accepted LP contracts for this strategy
        for (uint16 i=0;i<strategyContractsLength;i++) {
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
                allocatableFundsByToken[uint16(tokenAIndex)] += allocationAmountPerToken;
            } else {
                // If token is not present in allocations array yet, append its address and allocatable amount
                allocatableTokens[uint16(latestUpdatedIndexA + 1)] = strategyContract.tokenA;
                allocatableFundsByToken[uint16(latestUpdatedIndexA + 1)] = allocationAmountPerToken;
            }
            if (tokenBIndex >= 0) {
                // If token is already present, increment the allocatable amount for that token
                allocatableFundsByToken[uint16(tokenBIndex)] += allocationAmountPerToken;
            } else {
                // If token is not present in allocations array yet, append its address and allocatable amount
                allocatableTokens[uint16(latestUpdatedIndexB + 1)] = strategyContract.tokenB;
                allocatableFundsByToken[uint16(latestUpdatedIndexB + 1)] = allocationAmountPerToken;
            }
            // -- Perform swaps to get all required underlying tokens (Use oracle for fair pricing)
            
            // -- Engage in each LP contract

            // -- Store received LP token in Zorro contract
        }

    }

    function withdraw() external {
        // TODO
    }

    function takeProfit() external onlyOwner {
        // TODO
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

    function addLPContractToStrategy(address contractAddress, string memory strategy, address tokenA, address tokenB, address priceFeedA, address priceFeedB, uint8 priceCalculationMethod) external onlyOwner {
        // Get current contracts associated with strategy provided
        LPContract[] storage strategyContracts = lpContracts[strategy];
        // Check to make sure contract doesn't already exist
        for (uint16 i=0;i<strategyContracts.length;i++) {
            if (strategyContracts[i].ammContractAddress == contractAddress) {
                require(false, "Contract address already exists for this strategy");
            }
        }
        // Add contract & notify
        LPContract memory lpContract = LPContract(contractAddress, tokenA, tokenB, priceFeedA, priceFeedB, PriceCalculationMethod(priceCalculationMethod));
        strategyContracts.push(lpContract);
        lpContracts[strategy] = strategyContracts;
        emit AddedContract(strategy, contractAddress, lpContracts[strategy].length);
    }

    function removeLPContractFromStrategy(address contractAddress, string memory strategy) external onlyOwner {
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
    }
}