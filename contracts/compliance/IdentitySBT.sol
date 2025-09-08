// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title IdentitySBT - Soulbound Identity NFT for KYC Verification
 * @notice Non-transferable NFT representing completed KYC verification
 * @dev Used to gate access to FTH-GOLD subscription and operations
 */
contract IdentitySBT is ERC721, AccessControl {
    bytes32 public constant KYC_SIGNER_ROLE = keccak256("KYC_SIGNER_ROLE");
    
    mapping(address => bool) public verified;
    mapping(address => bytes32) public kycHash; // Hash of KYC documents
    
    uint256 public nextTokenId = 1;
    
    event KYCVerified(address indexed user, uint256 tokenId, bytes32 kycHash);
    event KYCRevoked(address indexed user, uint256 tokenId);
    
    error Soulbound();
    error NotAuthorized();
    error AlreadyVerified();
    error NotVerified();
    
    constructor(
        address admin,
        address initialSigner
    ) ERC721("FTH KYC Identity", "FTH-KYC") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(KYC_SIGNER_ROLE, initialSigner);
    }
    
    /**
     * @notice Mint KYC SBT to verified user
     * @param to Address to mint to
     * @param documentHash Hash of KYC documents for audit trail
     */
    function mint(address to, bytes32 documentHash) external {
        if (!hasRole(KYC_SIGNER_ROLE, msg.sender)) revert NotAuthorized();
        if (verified[to]) revert AlreadyVerified();
        
        uint256 tokenId = nextTokenId++;
        _safeMint(to, tokenId);
        
        verified[to] = true;
        kycHash[to] = documentHash;
        
        emit KYCVerified(to, tokenId, documentHash);
    }
    
    /**
     * @notice Revoke KYC verification (burn SBT)
     * @param user Address to revoke verification for
     */
    function revoke(address user) external {
        if (!hasRole(KYC_SIGNER_ROLE, msg.sender)) revert NotAuthorized();
        if (!verified[user]) revert NotVerified();
        
        uint256 tokenId = tokenOfOwnerByIndex(user, 0);
        _burn(tokenId);
        
        verified[user] = false;
        delete kycHash[user];
        
        emit KYCRevoked(user, tokenId);
    }
    
    /**
     * @notice Check if address has completed KYC verification
     * @param user Address to check
     * @return True if user is verified
     */
    function isVerified(address user) external view returns (bool) {
        return verified[user];
    }
    
    /**
     * @notice Get KYC document hash for audit purposes
     * @param user Address to get hash for
     * @return Hash of KYC documents
     */
    function getKYCHash(address user) external view returns (bytes32) {
        if (!verified[user]) revert NotVerified();
        return kycHash[user];
    }
    
    // Soulbound: Disable all transfers
    function transferFrom(address, address, uint256) public pure override {
        revert Soulbound();
    }
    
    function safeTransferFrom(address, address, uint256) public pure override {
        revert Soulbound();
    }
    
    function safeTransferFrom(address, address, uint256, bytes calldata) public pure override {
        revert Soulbound();
    }
    
    function tokenURI(uint256) public pure override returns (string memory) {
        return "https://api.futuretechholdings.com/kyc-metadata";
    }
}