// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

/**
 * @title IdentitySBT - Soulbound KYC Identity Tokens
 * @notice Non-transferable identity tokens for KYC verification
 * @dev Implements ERC-721 with transfer restrictions (Soulbound)
 */
contract IdentitySBT is ERC721, AccessControl, Pausable {
    using Counters for Counters.Counter;
    
    bytes32 public constant KYC_OPERATOR_ROLE = keccak256("KYC_OPERATOR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    Counters.Counter private _tokenIdCounter;
    
    enum KYCLevel {
        NONE,
        BASIC,      // Basic verification (passport + selfie)
        ENHANCED,   // Enhanced due diligence
        INSTITUTIONAL // Institutional KYC
    }
    
    enum AccreditationStatus {
        NONE,
        ACCREDITED_INVESTOR,
        PROFESSIONAL_CLIENT,
        ELIGIBLE_COUNTERPARTY
    }
    
    struct IdentityData {
        address wallet;
        string kycProvider; // "Sumsub", "Trulioo", etc.
        string kycSessionId; // External KYC session ID
        KYCLevel kycLevel;
        AccreditationStatus accreditation;
        string jurisdiction; // ISO country code
        uint256 issuedAt;
        uint256 expiresAt;
        bool isActive;
        bool isRevoked;
        string ipfsMetadata; // IPFS CID for additional metadata
    }
    
    // State mappings
    mapping(uint256 => IdentityData) public identityData;
    mapping(address => uint256) public walletToTokenId;
    mapping(string => bool) public usedKYCSessionIds;
    
    // Jurisdiction and provider management
    mapping(string => bool) public approvedJurisdictions;
    mapping(string => bool) public approvedKYCProviders;
    
    // Global stats
    uint256 public totalIdentitiesIssued;
    uint256 public totalActiveIdentities;
    mapping(KYCLevel => uint256) public countByKYCLevel;
    mapping(AccreditationStatus => uint256) public countByAccreditation;
    
    // Events
    event IdentityIssued(
        address indexed wallet,
        uint256 indexed tokenId,
        KYCLevel kycLevel,
        AccreditationStatus accreditation,
        string jurisdiction
    );
    
    event IdentityRevoked(
        address indexed wallet,
        uint256 indexed tokenId,
        string reason
    );
    
    event IdentityUpdated(
        address indexed wallet,
        uint256 indexed tokenId,
        KYCLevel newLevel,
        AccreditationStatus newAccreditation
    );
    
    event JurisdictionStatusChanged(string jurisdiction, bool approved);
    event KYCProviderStatusChanged(string provider, bool approved);
    
    // Errors
    error TransferNotAllowed();
    error IdentityAlreadyExists();
    error IdentityNotFound();
    error KYCSessionAlreadyUsed();
    error JurisdictionNotApproved();
    error KYCProviderNotApproved();
    error IdentityExpired();
    error IdentityRevoked();
    
    constructor(
        string memory name,
        string memory symbol,
        address admin
    ) ERC721(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(KYC_OPERATOR_ROLE, admin);
        
        // Pre-approve common jurisdictions
        approvedJurisdictions["AE"] = true; // UAE
        approvedJurisdictions["GB"] = true; // UK
        approvedJurisdictions["DE"] = true; // Germany
        approvedJurisdictions["SG"] = true; // Singapore
        approvedJurisdictions["HK"] = true; // Hong Kong
        
        // Pre-approve KYC providers
        approvedKYCProviders["Sumsub"] = true;
        approvedKYCProviders["Trulioo"] = true;
        approvedKYCProviders["Persona"] = true;
    }
    
    /**
     * @notice Issue a new identity SBT
     * @param wallet Target wallet address
     * @param kycProvider KYC provider name
     * @param kycSessionId External KYC session ID
     * @param kycLevel KYC verification level
     * @param accreditation Accreditation status
     * @param jurisdiction ISO country code
     * @param validityPeriod Validity period in seconds
     * @param ipfsMetadata IPFS CID for additional metadata
     */
    function issueIdentity(
        address wallet,
        string calldata kycProvider,
        string calldata kycSessionId,
        KYCLevel kycLevel,
        AccreditationStatus accreditation,
        string calldata jurisdiction,
        uint256 validityPeriod,
        string calldata ipfsMetadata
    ) external onlyRole(KYC_OPERATOR_ROLE) whenNotPaused {
        if (walletToTokenId[wallet] != 0) revert IdentityAlreadyExists();
        if (usedKYCSessionIds[kycSessionId]) revert KYCSessionAlreadyUsed();
        if (!approvedJurisdictions[jurisdiction]) revert JurisdictionNotApproved();
        if (!approvedKYCProviders[kycProvider]) revert KYCProviderNotApproved();
        
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        
        // Create identity data
        IdentityData memory identity = IdentityData({
            wallet: wallet,
            kycProvider: kycProvider,
            kycSessionId: kycSessionId,
            kycLevel: kycLevel,
            accreditation: accreditation,
            jurisdiction: jurisdiction,
            issuedAt: block.timestamp,
            expiresAt: block.timestamp + validityPeriod,
            isActive: true,
            isRevoked: false,
            ipfsMetadata: ipfsMetadata
        });
        
        identityData[tokenId] = identity;
        walletToTokenId[wallet] = tokenId;
        usedKYCSessionIds[kycSessionId] = true;
        
        // Update counters
        totalIdentitiesIssued++;
        totalActiveIdentities++;
        countByKYCLevel[kycLevel]++;
        countByAccreditation[accreditation]++;
        
        // Mint the SBT
        _safeMint(wallet, tokenId);
        
        emit IdentityIssued(wallet, tokenId, kycLevel, accreditation, jurisdiction);
    }
    
    /**
     * @notice Check if wallet has valid identity
     * @param wallet Wallet address to check
     * @return Valid identity status
     */
    function hasValidIdentity(address wallet) external view returns (bool) {
        uint256 tokenId = walletToTokenId[wallet];
        if (tokenId == 0) return false;
        
        IdentityData storage identity = identityData[tokenId];
        
        return identity.isActive && 
               !identity.isRevoked && 
               block.timestamp <= identity.expiresAt;
    }
    
    /**
     * @notice Get identity details for wallet
     * @param wallet Wallet address
     * @return Identity data struct
     */
    function getIdentity(address wallet) external view returns (IdentityData memory) {
        uint256 tokenId = walletToTokenId[wallet];
        if (tokenId == 0) revert IdentityNotFound();
        
        return identityData[tokenId];
    }
    
    /**
     * @notice Check accreditation status
     * @param wallet Wallet address
     * @return accreditation Accreditation status
     * @return isValid Whether identity is still valid
     */
    function getAccreditationStatus(address wallet) external view returns (
        AccreditationStatus accreditation,
        bool isValid
    ) {
        uint256 tokenId = walletToTokenId[wallet];
        if (tokenId == 0) return (AccreditationStatus.NONE, false);
        
        IdentityData storage identity = identityData[tokenId];
        
        isValid = identity.isActive && 
                 !identity.isRevoked && 
                 block.timestamp <= identity.expiresAt;
                 
        return (identity.accreditation, isValid);
    }
    
    /**
     * @notice Update identity level (upgrade/downgrade)
     * @param wallet Target wallet
     * @param newKYCLevel New KYC level
     * @param newAccreditation New accreditation status
     */
    function updateIdentity(
        address wallet,
        KYCLevel newKYCLevel,
        AccreditationStatus newAccreditation
    ) external onlyRole(KYC_OPERATOR_ROLE) {
        uint256 tokenId = walletToTokenId[wallet];
        if (tokenId == 0) revert IdentityNotFound();
        
        IdentityData storage identity = identityData[tokenId];
        if (identity.isRevoked) revert IdentityRevoked();
        
        // Update counters
        countByKYCLevel[identity.kycLevel]--;
        countByAccreditation[identity.accreditation]--;
        
        identity.kycLevel = newKYCLevel;
        identity.accreditation = newAccreditation;
        
        countByKYCLevel[newKYCLevel]++;
        countByAccreditation[newAccreditation]++;
        
        emit IdentityUpdated(wallet, tokenId, newKYCLevel, newAccreditation);
    }
    
    /**
     * @notice Revoke an identity
     * @param wallet Wallet to revoke
     * @param reason Revocation reason
     */
    function revokeIdentity(
        address wallet,
        string calldata reason
    ) external onlyRole(KYC_OPERATOR_ROLE) {
        uint256 tokenId = walletToTokenId[wallet];
        if (tokenId == 0) revert IdentityNotFound();
        
        IdentityData storage identity = identityData[tokenId];
        
        identity.isRevoked = true;
        identity.isActive = false;
        
        totalActiveIdentities--;
        
        emit IdentityRevoked(wallet, tokenId, reason);
    }
    
    /**
     * @notice Extend identity validity
     * @param wallet Wallet to extend
     * @param additionalTime Additional time in seconds
     */
    function extendValidity(
        address wallet,
        uint256 additionalTime
    ) external onlyRole(KYC_OPERATOR_ROLE) {
        uint256 tokenId = walletToTokenId[wallet];
        if (tokenId == 0) revert IdentityNotFound();
        
        IdentityData storage identity = identityData[tokenId];
        if (identity.isRevoked) revert IdentityRevoked();
        
        identity.expiresAt += additionalTime;
    }
    
    /**
     * @notice Batch issue identities
     * @param wallets Array of wallet addresses
     * @param kycData Array of KYC data (packed)
     */
    function batchIssueIdentities(
        address[] calldata wallets,
        bytes[] calldata kycData
    ) external onlyRole(KYC_OPERATOR_ROLE) whenNotPaused {
        require(wallets.length == kycData.length, "Array length mismatch");
        
        for (uint256 i = 0; i < wallets.length; i++) {
            // Decode packed KYC data
            (
                string memory kycProvider,
                string memory kycSessionId,
                KYCLevel kycLevel,
                AccreditationStatus accreditation,
                string memory jurisdiction,
                uint256 validityPeriod,
                string memory ipfsMetadata
            ) = abi.decode(kycData[i], (string, string, KYCLevel, AccreditationStatus, string, uint256, string));
            
            if (walletToTokenId[wallets[i]] == 0 && !usedKYCSessionIds[kycSessionId]) {
                // Issue identity without external call overhead
                _tokenIdCounter.increment();
                uint256 tokenId = _tokenIdCounter.current();
                
                identityData[tokenId] = IdentityData({
                    wallet: wallets[i],
                    kycProvider: kycProvider,
                    kycSessionId: kycSessionId,
                    kycLevel: kycLevel,
                    accreditation: accreditation,
                    jurisdiction: jurisdiction,
                    issuedAt: block.timestamp,
                    expiresAt: block.timestamp + validityPeriod,
                    isActive: true,
                    isRevoked: false,
                    ipfsMetadata: ipfsMetadata
                });
                
                walletToTokenId[wallets[i]] = tokenId;
                usedKYCSessionIds[kycSessionId] = true;
                
                totalIdentitiesIssued++;
                totalActiveIdentities++;
                countByKYCLevel[kycLevel]++;
                countByAccreditation[accreditation]++;
                
                _safeMint(wallets[i], tokenId);
                
                emit IdentityIssued(wallets[i], tokenId, kycLevel, accreditation, jurisdiction);
            }
        }
    }
    
    /**
     * @notice Manage approved jurisdictions
     * @param jurisdiction ISO country code
     * @param approved Approval status
     */
    function setJurisdictionApproval(
        string calldata jurisdiction,
        bool approved
    ) external onlyRole(ADMIN_ROLE) {
        approvedJurisdictions[jurisdiction] = approved;
        emit JurisdictionStatusChanged(jurisdiction, approved);
    }
    
    /**
     * @notice Manage approved KYC providers
     * @param provider KYC provider name
     * @param approved Approval status
     */
    function setKYCProviderApproval(
        string calldata provider,
        bool approved
    ) external onlyRole(ADMIN_ROLE) {
        approvedKYCProviders[provider] = approved;
        emit KYCProviderStatusChanged(provider, approved);
    }
    
    /**
     * @notice Generate SVG metadata for token
     * @param tokenId Token ID
     * @return SVG metadata
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        
        IdentityData storage identity = identityData[tokenId];
        
        string memory svg = string(abi.encodePacked(
            '<svg width="350" height="200" xmlns="http://www.w3.org/2000/svg">',
            '<rect width="100%" height="100%" fill="#1a365d"/>',
            '<text x="20" y="40" fill="#FFD700" font-size="16" font-family="Arial">Future Tech Holdings</text>',
            '<text x="20" y="70" fill="#ffffff" font-size="14" font-family="Arial">Identity SBT</text>',
            '<text x="20" y="100" fill="#ffffff" font-size="12" font-family="Arial">Level: ', _kycLevelToString(identity.kycLevel), '</text>',
            '<text x="20" y="120" fill="#ffffff" font-size="12" font-family="Arial">Jurisdiction: ', identity.jurisdiction, '</text>',
            '<text x="20" y="140" fill="#ffffff" font-size="12" font-family="Arial">Provider: ', identity.kycProvider, '</text>',
            '<text x="20" y="170" fill="#888888" font-size="10" font-family="Arial">Non-transferable</text>',
            '</svg>'
        ));
        
        string memory json = Base64.encode(bytes(string(abi.encodePacked(
            '{"name": "FTH Identity SBT #', Strings.toString(tokenId), '",',
            '"description": "Soulbound identity token for Future Tech Holdings compliance",',
            '"image": "data:image/svg+xml;base64,', Base64.encode(bytes(svg)), '",',
            '"attributes": [',
                '{"trait_type": "KYC Level", "value": "', _kycLevelToString(identity.kycLevel), '"},',
                '{"trait_type": "Accreditation", "value": "', _accreditationToString(identity.accreditation), '"},',
                '{"trait_type": "Jurisdiction", "value": "', identity.jurisdiction, '"},',
                '{"trait_type": "Provider", "value": "', identity.kycProvider, '"},',
                '{"trait_type": "Valid Until", "value": "', Strings.toString(identity.expiresAt), '"}',
            ']}'
        ))));
        
        return string(abi.encodePacked("data:application/json;base64,", json));
    }
    
    function _kycLevelToString(KYCLevel level) internal pure returns (string memory) {
        if (level == KYCLevel.BASIC) return "Basic";
        if (level == KYCLevel.ENHANCED) return "Enhanced";
        if (level == KYCLevel.INSTITUTIONAL) return "Institutional";
        return "None";
    }
    
    function _accreditationToString(AccreditationStatus status) internal pure returns (string memory) {
        if (status == AccreditationStatus.ACCREDITED_INVESTOR) return "Accredited Investor";
        if (status == AccreditationStatus.PROFESSIONAL_CLIENT) return "Professional Client";
        if (status == AccreditationStatus.ELIGIBLE_COUNTERPARTY) return "Eligible Counterparty";
        return "None";
    }
    
    /**
     * @notice Override transfers to make tokens soulbound
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
        
        // Allow minting (from == address(0)) and burning (to == address(0))
        if (from != address(0) && to != address(0)) {
            revert TransferNotAllowed();
        }
    }
    
    /**
     * @notice Get identity statistics
     * @return total Total identities issued
     * @return active Currently active identities
     * @return expired Expired identities
     */
    function getIdentityStats() external view returns (
        uint256 total,
        uint256 active,
        uint256 expired
    ) {
        return (
            totalIdentitiesIssued,
            totalActiveIdentities,
            totalIdentitiesIssued - totalActiveIdentities
        );
    }
    
    /**
     * @notice Pause identity operations
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause identity operations
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}