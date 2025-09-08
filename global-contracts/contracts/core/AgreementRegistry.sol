// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title AgreementRegistry - On-chain Document Notarization
 * @notice IPFS-backed document registry with cryptographic verification
 * @dev Stores document hashes, IPFS CIDs, and signature metadata
 */
contract AgreementRegistry is AccessControl, Pausable {
    
    bytes32 public constant NOTARY_ROLE = keccak256("NOTARY_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    struct Agreement {
        address signer;
        bytes32 documentHash; // SHA-256 hash of signed document
        string ipfsCID; // IPFS Content ID
        string documentType; // "Subscription Agreement", "PPM", etc.
        uint256 timestamp;
        bool verified;
        string pgpSignature; // Optional PGP detached signature
        address notary; // Address that recorded the agreement
    }
    
    struct DocumentMetadata {
        string title;
        string version;
        uint256 createdAt;
        address creator;
        bytes32 templateHash; // Hash of unsigned template
    }
    
    // State mappings
    mapping(bytes32 => Agreement) public agreements; // documentHash => Agreement
    mapping(address => bytes32[]) public signerAgreements; // signer => documentHashes[]
    mapping(string => bytes32) public ipfsToDochash; // ipfsCID => documentHash
    mapping(bytes32 => DocumentMetadata) public documentMetadata; // documentHash => metadata
    mapping(bytes32 => bool) public revokedDocuments; // documentHash => revoked status
    
    // Global counters
    uint256 public totalAgreements;
    uint256 public totalSigners;
    mapping(address => bool) public hasSignedBefore;
    
    // PGP public key storage for verification
    mapping(address => string) public pgpPublicKeys;
    string public issuerPGPKey = "FTH1 A50E C95C 2025 8204"; // Issuer's PGP fingerprint
    
    // Events
    event AgreementRecorded(
        address indexed signer,
        bytes32 indexed documentHash,
        string ipfsCID,
        string documentType,
        address notary
    );
    
    event DocumentVerified(
        bytes32 indexed documentHash,
        address verifier,
        bool verified
    );
    
    event DocumentRevoked(
        bytes32 indexed documentHash,
        address revoker,
        string reason
    );
    
    event PGPKeyRegistered(
        address indexed signer,
        string pgpFingerprint
    );
    
    event BulkAgreementsProcessed(
        uint256 count,
        address processor
    );
    
    // Errors
    error DocumentAlreadyExists();
    error DocumentNotFound();
    error UnauthorizedSigner();
    error DocumentRevoked();
    error InvalidIPFSCID();
    error InvalidDocumentHash();
    
    constructor(address _admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(NOTARY_ROLE, _admin);
    }
    
    /**
     * @notice Record a signed agreement on-chain
     * @param signer Address of the document signer
     * @param documentHash SHA-256 hash of the signed document
     * @param ipfsCID IPFS Content ID where document is stored
     * @param documentType Type of document (e.g., "Subscription Agreement")
     */
    function recordAgreement(
        address signer,
        bytes32 documentHash,
        string calldata ipfsCID,
        string calldata documentType
    ) external onlyRole(NOTARY_ROLE) whenNotPaused {
        if (agreements[documentHash].timestamp != 0) revert DocumentAlreadyExists();
        if (revokedDocuments[documentHash]) revert DocumentRevoked();
        if (bytes(ipfsCID).length == 0) revert InvalidIPFSCID();
        if (documentHash == bytes32(0)) revert InvalidDocumentHash();
        
        // Create agreement record
        Agreement memory agreement = Agreement({
            signer: signer,
            documentHash: documentHash,
            ipfsCID: ipfsCID,
            documentType: documentType,
            timestamp: block.timestamp,
            verified: false,
            pgpSignature: "",
            notary: msg.sender
        });
        
        agreements[documentHash] = agreement;
        signerAgreements[signer].push(documentHash);
        ipfsToDochash[ipfsCID] = documentHash;
        
        // Update counters
        totalAgreements++;
        if (!hasSignedBefore[signer]) {
            totalSigners++;
            hasSignedBefore[signer] = true;
        }
        
        emit AgreementRecorded(
            signer,
            documentHash,
            ipfsCID,
            documentType,
            msg.sender
        );
    }
    
    /**
     * @notice Record agreement with PGP signature
     * @param signer Address of the document signer
     * @param documentHash SHA-256 hash of the signed document
     * @param ipfsCID IPFS Content ID
     * @param documentType Type of document
     * @param pgpSignature PGP detached signature (base64 encoded)
     */
    function recordAgreementWithPGP(
        address signer,
        bytes32 documentHash,
        string calldata ipfsCID,
        string calldata documentType,
        string calldata pgpSignature
    ) external onlyRole(NOTARY_ROLE) whenNotPaused {
        if (agreements[documentHash].timestamp != 0) revert DocumentAlreadyExists();
        if (revokedDocuments[documentHash]) revert DocumentRevoked();
        
        Agreement memory agreement = Agreement({
            signer: signer,
            documentHash: documentHash,
            ipfsCID: ipfsCID,
            documentType: documentType,
            timestamp: block.timestamp,
            verified: false,
            pgpSignature: pgpSignature,
            notary: msg.sender
        });
        
        agreements[documentHash] = agreement;
        signerAgreements[signer].push(documentHash);
        ipfsToDochash[ipfsCID] = documentHash;
        
        totalAgreements++;
        if (!hasSignedBefore[signer]) {
            totalSigners++;
            hasSignedBefore[signer] = true;
        }
        
        emit AgreementRecorded(signer, documentHash, ipfsCID, documentType, msg.sender);
    }
    
    /**
     * @notice Verify document integrity
     * @param documentHash Document hash to verify
     * @param ipfsCID Expected IPFS CID
     * @return True if document exists and CID matches
     */
    function verifyDocument(
        bytes32 documentHash,
        string calldata ipfsCID
    ) external view returns (bool) {
        Agreement storage agreement = agreements[documentHash];
        if (agreement.timestamp == 0) return false;
        if (revokedDocuments[documentHash]) return false;
        
        return keccak256(bytes(agreement.ipfsCID)) == keccak256(bytes(ipfsCID));
    }
    
    /**
     * @notice Mark document as verified by authorized verifier
     * @param documentHash Document hash to verify
     */
    function markDocumentVerified(
        bytes32 documentHash
    ) external onlyRole(NOTARY_ROLE) {
        if (agreements[documentHash].timestamp == 0) revert DocumentNotFound();
        if (revokedDocuments[documentHash]) revert DocumentRevoked();
        
        agreements[documentHash].verified = true;
        
        emit DocumentVerified(documentHash, msg.sender, true);
    }
    
    /**
     * @notice Revoke a document (emergency use)
     * @param documentHash Document hash to revoke
     * @param reason Reason for revocation
     */
    function revokeDocument(
        bytes32 documentHash,
        string calldata reason
    ) external onlyRole(ADMIN_ROLE) {
        if (agreements[documentHash].timestamp == 0) revert DocumentNotFound();
        
        revokedDocuments[documentHash] = true;
        
        emit DocumentRevoked(documentHash, msg.sender, reason);
    }
    
    /**
     * @notice Register PGP public key for an address
     * @param signer Address to register key for
     * @param pgpFingerprint PGP key fingerprint
     */
    function registerPGPKey(
        address signer,
        string calldata pgpFingerprint
    ) external onlyRole(NOTARY_ROLE) {
        pgpPublicKeys[signer] = pgpFingerprint;
        
        emit PGPKeyRegistered(signer, pgpFingerprint);
    }
    
    /**
     * @notice Batch record multiple agreements (for bulk processing)
     * @param signers Array of signer addresses
     * @param documentHashes Array of document hashes
     * @param ipfsCIDs Array of IPFS CIDs
     * @param documentTypes Array of document types
     */
    function batchRecordAgreements(
        address[] calldata signers,
        bytes32[] calldata documentHashes,
        string[] calldata ipfsCIDs,
        string[] calldata documentTypes
    ) external onlyRole(NOTARY_ROLE) whenNotPaused {
        require(
            signers.length == documentHashes.length &&
            documentHashes.length == ipfsCIDs.length &&
            ipfsCIDs.length == documentTypes.length,
            "Array length mismatch"
        );
        
        for (uint256 i = 0; i < signers.length; i++) {
            if (agreements[documentHashes[i]].timestamp == 0 && !revokedDocuments[documentHashes[i]]) {
                Agreement memory agreement = Agreement({
                    signer: signers[i],
                    documentHash: documentHashes[i],
                    ipfsCID: ipfsCIDs[i],
                    documentType: documentTypes[i],
                    timestamp: block.timestamp,
                    verified: false,
                    pgpSignature: "",
                    notary: msg.sender
                });
                
                agreements[documentHashes[i]] = agreement;
                signerAgreements[signers[i]].push(documentHashes[i]);
                ipfsToDochash[ipfsCIDs[i]] = documentHashes[i];
                
                totalAgreements++;
                if (!hasSignedBefore[signers[i]]) {
                    totalSigners++;
                    hasSignedBefore[signers[i]] = true;
                }
                
                emit AgreementRecorded(
                    signers[i],
                    documentHashes[i],
                    ipfsCIDs[i],
                    documentTypes[i],
                    msg.sender
                );
            }
        }
        
        emit BulkAgreementsProcessed(signers.length, msg.sender);
    }
    
    /**
     * @notice Get agreement details
     * @param documentHash Document hash to lookup
     * @return Agreement struct
     */
    function getAgreement(bytes32 documentHash) 
        external view returns (Agreement memory) {
        return agreements[documentHash];
    }
    
    /**
     * @notice Get all agreements for a signer
     * @param signer Signer address
     * @return Array of document hashes
     */
    function getSignerAgreements(address signer) 
        external view returns (bytes32[] memory) {
        return signerAgreements[signer];
    }
    
    /**
     * @notice Get document hash by IPFS CID
     * @param ipfsCID IPFS Content ID
     * @return Document hash
     */
    function getDocumentByIPFS(string calldata ipfsCID) 
        external view returns (bytes32) {
        return ipfsToDochash[ipfsCID];
    }
    
    /**
     * @notice Check if document is valid and not revoked
     * @param documentHash Document hash to check
     * @return Valid status
     */
    function isDocumentValid(bytes32 documentHash) 
        external view returns (bool) {
        return agreements[documentHash].timestamp != 0 && !revokedDocuments[documentHash];
    }
    
    /**
     * @notice Get registry statistics
     * @return totalDocs Total documents recorded
     * @return totalUsers Total unique signers
     * @return verifiedDocs Total verified documents
     */
    function getRegistryStats() external view returns (
        uint256 totalDocs,
        uint256 totalUsers,
        uint256 verifiedDocs
    ) {
        uint256 verified = 0;
        
        // Note: In production, maintain a separate verified counter for gas efficiency
        // This is for demonstration purposes
        
        return (totalAgreements, totalSigners, verified);
    }
    
    /**
     * @notice Store document metadata
     * @param documentHash Document hash
     * @param title Document title
     * @param version Document version
     * @param templateHash Hash of unsigned template
     */
    function storeDocumentMetadata(
        bytes32 documentHash,
        string calldata title,
        string calldata version,
        bytes32 templateHash
    ) external onlyRole(NOTARY_ROLE) {
        documentMetadata[documentHash] = DocumentMetadata({
            title: title,
            version: version,
            createdAt: block.timestamp,
            creator: msg.sender,
            templateHash: templateHash
        });
    }
    
    /**
     * @notice Update issuer PGP key
     * @param newPGPFingerprint New PGP key fingerprint
     */
    function updateIssuerPGPKey(
        string calldata newPGPFingerprint
    ) external onlyRole(ADMIN_ROLE) {
        issuerPGPKey = newPGPFingerprint;
    }
    
    /**
     * @notice Pause the registry (emergency)
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause the registry
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}