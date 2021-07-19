// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

contract ZorroStrategy {
    /* Constants */

    /* Variables */
    // Key addresses / ownership
    address owner;
    // Strategies
    mapping(string => address[]) public lpContracts;


    // Financial paramters
    uint16 public compoundingFrequencyDays;
    uint8 public performanceFeePercent;

    // Mappings?
    mapping(address => uint256) public lastFeeTakenAmount;
    mapping(address => uint64) public lastFeeTakenAt;
    mapping(address => uint256) public lastProfitAmountPreFees;

    // mapping (address => uint256) public balances;

    // Events
    event AddedContract(string strategy, address contractAddress);

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
    }


    // State-changing methods
    function invest() external payable {
        // Requirements
        require(msg.value > 0, "Message must have a value greater than 0");

        // Iterates through accepted LP contracts for this strategy (use oracle)
        // ---- OR, should they be updated into the contract? 
        // -- Perform swaps to get all required underlying tokens (Use oracle for fair pricing)

        // -- Engage in each LP contract

        // -- Store received LP token in Zorro contract

    }

    function withdraw() external {

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

    function addLPContractToStrategy(address contractAddress, string memory strategy) external onlyOwner {
        // Get current contracts associated with strategy provided
        address[] storage strategyContracts = lpContracts[strategy];
        // Check to make sure contract doesn't already exist
        for (uint16 i=0;i<strategyContracts.length;i++) {
            if (strategyContracts[i] == contractAddress) {
                require(false, "Contract address already exists for this strategy");
            }
        }
        // Add contract & notify
        strategyContracts.push(contractAddress);
        emit AddedContract(strategy, contractAddress);
    }

    function removeLPContractFromStrategy(address contractAddress, string memory strategy) external onlyOwner {
        // Get current contracts associated with strategy provided
        address[] storage strategyContracts = lpContracts[strategy];
        // Check to make sure contract exists
        int16 matchingIndex = -1;
        for (uint16 i=0;i<strategyContracts.length;i++) {
            if (strategyContracts[i] == contractAddress) {
                matchingIndex = int16(i);
                break;
            }
        }
        // If does not exist, revert
        require(matchingIndex >= 0, "Matching contract address could not be found for this strategy");
        // If does exist, remove contract and notify
        delete strategyContracts[uint16(matchingIndex)];
        emit AddedContract(strategy, contractAddress);
    }
}