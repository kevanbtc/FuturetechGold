// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title IAgreementRegistry - Interface for Agreement Registry
 * @notice Interface for document notarization and verification
 */
interface IAgreementRegistry {
    
    struct Agreement {
        address signer;
        bytes32 documentHash;
        string ipfsCID;
        string documentType;
        uint256 timestamp;
        bool verified;
        string pgpSignature;
        address notary;
    }
    
    /**
     * @notice Record a signed agreement
     * @param signer Address of document signer
     * @param documentHash SHA-256 hash of signed document
     * @param ipfsCID IPFS Content ID
     * @param documentType Type of document
     */
    function recordAgreement(
        address signer,
        bytes32 documentHash,
        string calldata ipfsCID,
        string calldata documentType
    ) external;
    
    /**
     * @notice Verify document integrity
     * @param documentHash Document hash to verify
     * @param ipfsCID Expected IPFS CID
     * @return True if document exists and CID matches
     */
    function verifyDocument(
        bytes32 documentHash,
        string calldata ipfsCID
    ) external view returns (bool);
    
    /**
     * @notice Get agreement details
     * @param documentHash Document hash to lookup
     * @return Agreement struct
     */
    function getAgreement(bytes32 documentHash) external view returns (Agreement memory);
    
    /**
     * @notice Check if document is valid and not revoked
     * @param documentHash Document hash to check
     * @return True if valid
     */
    function isDocumentValid(bytes32 documentHash) external view returns (bool);
}