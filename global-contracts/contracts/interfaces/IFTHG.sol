// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IFTHG - Interface for FTH-G Gold Token
 * @notice Interface for the core gold token contract
 */
interface IFTHG is IERC20 {
    
    /**
     * @notice Mint tokens with cliff period
     * @param to Recipient address
     * @param amount Amount to mint
     * @param fiveYearHold Whether to apply 5-year hold
     */
    function mintWithCliff(
        address to,
        uint256 amount,
        bool fiveYearHold
    ) external;
    
    /**
     * @notice Check if address is eligible for operations
     * @param user User address
     * @return True if eligible
     */
    function isEligible(address user) external view returns (bool);
    
    /**
     * @notice Check if address is in cliff period
     * @param user User address
     * @return True if in cliff
     */
    function isInCliff(address user) external view returns (bool);
    
    /**
     * @notice Get cliff end time for address
     * @param user User address
     * @return Cliff end timestamp
     */
    function getCliffEnd(address user) external view returns (uint256);
    
    /**
     * @notice Burn tokens from address
     * @param from Address to burn from
     * @param amount Amount to burn
     */
    function burnFrom(address from, uint256 amount) external;
}