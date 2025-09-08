// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title IFTHGCore - Minimal Read-Only Interface to FTH-G Core
 * @notice Non-breaking interface for add-ons to read core contract state
 * @dev This interface allows add-ons to integrate without modifying core contracts
 */
interface IFTHGCore {
    /**
     * @notice Check if user is eligible for distributions
     * @param user User address to check
     * @return eligible True if user can receive distributions
     */
    function isEligible(address user) external view returns (bool eligible);
    
    /**
     * @notice Get user's FTH-G token balance
     * @param user User address
     * @return balance Token balance (18 decimals, 1e18 = 1kg)
     */
    function balanceOf(address user) external view returns (uint256 balance);
    
    /**
     * @notice Check if user's cliff period has ended
     * @param user User address
     * @return cliffOver True if cliff period has ended
     */
    function cliffOver(address user) external view returns (bool cliffOver);
    
    /**
     * @notice Get total supply of FTH-G tokens
     * @return totalSupply Total tokens issued (18 decimals)
     */
    function totalSupply() external view returns (uint256 totalSupply);
    
    /**
     * @notice Check if user is currently in cliff period
     * @param user User address
     * @return inCliff True if user is in cliff period
     */
    function isInCliff(address user) external view returns (bool inCliff);
    
    /**
     * @notice Get user's cliff end timestamp
     * @param user User address
     * @return cliffEnd Timestamp when cliff ends (0 if no cliff)
     */
    function getCliffEnd(address user) external view returns (uint256 cliffEnd);
}