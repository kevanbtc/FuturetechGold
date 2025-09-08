// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title IIdentitySBT - Interface for Identity Soulbound Tokens
 * @notice Interface for KYC identity verification
 */
interface IIdentitySBT {
    
    enum KYCLevel {
        NONE,
        BASIC,
        ENHANCED,
        INSTITUTIONAL
    }
    
    enum AccreditationStatus {
        NONE,
        ACCREDITED_INVESTOR,
        PROFESSIONAL_CLIENT,
        ELIGIBLE_COUNTERPARTY
    }
    
    /**
     * @notice Check if address has valid identity
     * @param wallet Address to check
     * @return True if has valid identity
     */
    function hasValidIdentity(address wallet) external view returns (bool);
    
    /**
     * @notice Get accreditation status
     * @param wallet Address to check
     * @return accreditation Accreditation status
     * @return isValid Whether identity is still valid
     */
    function getAccreditationStatus(address wallet) external view returns (
        AccreditationStatus accreditation,
        bool isValid
    );
    
    /**
     * @notice Get KYC level for address
     * @param wallet Address to check
     * @return level KYC level
     * @return isValid Whether identity is still valid
     */
    function getKYCLevel(address wallet) external view returns (
        KYCLevel level,
        bool isValid
    );
}