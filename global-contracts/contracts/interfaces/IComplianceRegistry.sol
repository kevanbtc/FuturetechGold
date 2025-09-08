// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title IComplianceRegistry - Interface for Compliance Registry
 * @notice Interface for sanctions and jurisdiction management
 */
interface IComplianceRegistry {
    
    enum RestrictionLevel {
        NONE,
        MONITORING,
        RESTRICTED,
        BLOCKED
    }
    
    enum SanctionsList {
        OFAC,
        UN,
        EU,
        UAE,
        UK,
        CUSTOM
    }
    
    /**
     * @notice Check if address is restricted
     * @param wallet Address to check
     * @return True if restricted
     */
    function isRestricted(address wallet) external view returns (bool);
    
    /**
     * @notice Check if address is sanctioned
     * @param wallet Address to check
     * @return sanctioned True if on any sanctions list
     * @return lists Array of applicable sanctions lists
     */
    function isSanctioned(address wallet) external view returns (
        bool sanctioned,
        SanctionsList[] memory lists
    );
    
    /**
     * @notice Check jurisdiction compliance
     * @param jurisdiction ISO country code
     * @param newInvestor Whether this is a new investor
     * @return allowed Whether jurisdiction is allowed
     * @return enhancedKYCRequired Whether enhanced KYC is required
     */
    function checkJurisdictionCompliance(
        string calldata jurisdiction,
        bool newInvestor
    ) external view returns (bool allowed, bool enhancedKYCRequired);
    
    /**
     * @notice Increment investor count for jurisdiction
     * @param jurisdiction ISO country code
     */
    function incrementJurisdictionCount(string calldata jurisdiction) external;
}