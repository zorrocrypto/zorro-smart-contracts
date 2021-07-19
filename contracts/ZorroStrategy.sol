// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

contract ZorroStrategy {
    /* Variables */
    // Key addresses / ownership
    address owner;

    // Financial paramters
    uint16 public compoundingFrequencyDays;
    uint8 public performanceFeePercent;

    // Mappings?
    mapping(address => uint256) public lastFeeTakenAmount;
    mapping(address => uint64) public lastFeeTakenAt;
    mapping(address => uint256) public lastProfitAmountPreFees;

    // mapping (address => uint256) public balances;

    // Events

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

    }

    function withdraw() external {

    }

    function takeProfit() external onlyOwner {
        
    }

    function setCompoundingFrequency(uint16 minElapsedDays) external onlyOwner {
        compoundingFrequencyDays = minElapsedDays;
    }

    function setZorroPerformanceFeePercent(uint8 feePct) external onlyOwner {
        require(feePct >= 0 && feePct <= 100, "Percent must be a value between 0 and 100.");
        performanceFeePercent = feePct;
    }
}