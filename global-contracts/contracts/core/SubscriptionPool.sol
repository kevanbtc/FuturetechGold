// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "../interfaces/IFTHG.sol";
import "../interfaces/IIdentitySBT.sol";
import "../interfaces/IComplianceRegistry.sol";
import "../interfaces/IWhitelistGate.sol";
import "../interfaces/IAgreementRegistry.sol";

/**
 * @title SubscriptionPool - Global Smart Contract Subscription System
 * @notice AI DocuSign-like subscription system with EIP-712 signature binding
 * @dev Handles $20k entries with document hash verification and global compliance
 */
contract SubscriptionPool is ReentrancyGuard, Pausable, AccessControl, EIP712 {
    using ECDSA for bytes32;

    // Role definitions
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    
    // Contract interfaces
    IFTHG public immutable fthgToken;
    IIdentitySBT public immutable identitySBT;
    IComplianceRegistry public immutable complianceRegistry;
    IWhitelistGate public immutable whitelistGate;
    IAgreementRegistry public immutable agreementRegistry;
    
    // Subscription terms
    uint256 public constant SUBSCRIPTION_PRICE_USD = 20_000e6; // $20k in USDC/USDT format
    uint256 public constant MIN_SUBSCRIPTION_AMOUNT = SUBSCRIPTION_PRICE_USD;
    uint256 public constant MAX_INVESTORS = 500;
    uint256 public constant PER_INVESTOR_CAP_USD = 10_000_000e6; // $10M cap per investor
    
    // EIP-712 Domain
    bytes32 private constant SUBSCRIPTION_INTENT_TYPEHASH = keccak256(
        "SubscriptionIntent(address investor,uint256 amount,bytes32 documentHash,uint256 nonce,uint256 deadline,string ipfsCID,bool fiveYearHold)"
    );
    
    struct SubscriptionIntent {
        address investor;
        uint256 amount;
        bytes32 documentHash; // SHA-256 hash of signed PDF
        uint256 nonce;
        uint256 deadline;
        string ipfsCID; // IPFS Content ID of signed documents
        bool fiveYearHold; // Optional 5-year hold commitment
    }
    
    struct Subscription {
        address investor;
        uint256 amount;
        uint256 tokensAllocated;
        bytes32 documentHash;
        string ipfsCID;
        uint256 timestamp;
        bool fiveYearHold;
        bool processed;
        bool redeemed;
    }
    
    // State variables
    mapping(address => uint256) public investorNonces;
    mapping(address => uint256) public investorTotalInvested;
    mapping(address => Subscription[]) public investorSubscriptions;
    mapping(bytes32 => bool) public documentHashUsed;
    
    uint256 public totalInvestors;
    uint256 public totalRaised;
    uint256 public totalTokensAllocated;
    
    // Events
    event SubscriptionIntent(
        address indexed investor,
        uint256 amount,
        bytes32 documentHash,
        string ipfsCID,
        bool fiveYearHold
    );
    
    event SubscriptionProcessed(
        address indexed investor,
        uint256 amount,
        uint256 tokensAllocated,
        bytes32 documentHash
    );
    
    event DocumentVerified(
        address indexed investor,
        bytes32 documentHash,
        string ipfsCID
    );
    
    event ComplianceCheck(
        address indexed investor,
        bool kycPassed,
        bool whitelistPassed,
        bool sanctionsPassed
    );
    
    // Errors
    error InvalidSignature();
    error DocumentHashAlreadyUsed();
    error InvestorNotCompliant();
    error ExceedsInvestorCap();
    error ExceedsMaxInvestors();
    error InvalidAmount();
    error DeadlineExpired();
    error InsufficientBalance();
    error SubscriptionNotFound();
    error AlreadyProcessed();
    
    constructor(
        address _fthgToken,
        address _identitySBT,
        address _complianceRegistry,
        address _whitelistGate,
        address _agreementRegistry,
        address _admin
    ) EIP712("FuturetechGold Subscription", "1") {
        require(_fthgToken != address(0), "Invalid FTHG token");
        require(_identitySBT != address(0), "Invalid Identity SBT");
        require(_complianceRegistry != address(0), "Invalid Compliance Registry");
        require(_whitelistGate != address(0), "Invalid Whitelist Gate");
        require(_agreementRegistry != address(0), "Invalid Agreement Registry");
        
        fthgToken = IFTHG(_fthgToken);
        identitySBT = IIdentitySBT(_identitySBT);
        complianceRegistry = IComplianceRegistry(_complianceRegistry);
        whitelistGate = IWhitelistGate(_whitelistGate);
        agreementRegistry = IAgreementRegistry(_agreementRegistry);
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(OPERATOR_ROLE, _admin);
    }
    
    /**
     * @notice Subscribe with EIP-712 signature verification (AI DocuSign flow)
     * @param intent Subscription details including document hash
     * @param signature EIP-712 signature from investor
     */
    function subscribe(
        SubscriptionIntent calldata intent,
        bytes calldata signature
    ) external payable nonReentrant whenNotPaused {
        // Verify deadline
        if (block.timestamp > intent.deadline) revert DeadlineExpired();
        
        // Verify signature
        bytes32 structHash = keccak256(abi.encode(
            SUBSCRIPTION_INTENT_TYPEHASH,
            intent.investor,
            intent.amount,
            intent.documentHash,
            intent.nonce,
            intent.deadline,
            keccak256(bytes(intent.ipfsCID)),
            intent.fiveYearHold
        ));
        
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = hash.recover(signature);
        
        if (signer != intent.investor) revert InvalidSignature();
        
        // Verify nonce
        require(investorNonces[intent.investor] == intent.nonce, "Invalid nonce");
        investorNonces[intent.investor]++;
        
        // Check document hash uniqueness
        if (documentHashUsed[intent.documentHash]) revert DocumentHashAlreadyUsed();
        documentHashUsed[intent.documentHash] = true;
        
        // Compliance checks
        _performComplianceChecks(intent.investor);
        
        // Amount validation
        if (intent.amount < MIN_SUBSCRIPTION_AMOUNT) revert InvalidAmount();
        
        // Check investor cap
        uint256 newTotal = investorTotalInvested[intent.investor] + intent.amount;
        if (newTotal > PER_INVESTOR_CAP_USD) revert ExceedsInvestorCap();
        
        // Check max investors limit
        if (investorTotalInvested[intent.investor] == 0) {
            if (totalInvestors >= MAX_INVESTORS) revert ExceedsMaxInvestors();
            totalInvestors++;
        }
        
        // Calculate token allocation (1 token = 1kg = $20k)
        uint256 tokensToAllocate = intent.amount / SUBSCRIPTION_PRICE_USD;
        
        // Create subscription record
        Subscription memory subscription = Subscription({
            investor: intent.investor,
            amount: intent.amount,
            tokensAllocated: tokensToAllocate,
            documentHash: intent.documentHash,
            ipfsCID: intent.ipfsCID,
            timestamp: block.timestamp,
            fiveYearHold: intent.fiveYearHold,
            processed: false,
            redeemed: false
        });
        
        investorSubscriptions[intent.investor].push(subscription);
        investorTotalInvested[intent.investor] += intent.amount;
        totalRaised += intent.amount;
        totalTokensAllocated += tokensToAllocate;
        
        // Record agreement on-chain
        agreementRegistry.recordAgreement(
            intent.investor,
            intent.documentHash,
            intent.ipfsCID,
            "Subscription Agreement"
        );
        
        emit SubscriptionIntent(
            intent.investor,
            intent.amount,
            intent.documentHash,
            intent.ipfsCID,
            intent.fiveYearHold
        );
        
        emit DocumentVerified(
            intent.investor,
            intent.documentHash,
            intent.ipfsCID
        );
    }
    
    /**
     * @notice Process subscription and mint tokens (admin only)
     * @param investor Investor address
     * @param subscriptionIndex Index of subscription to process
     */
    function processSubscription(
        address investor,
        uint256 subscriptionIndex
    ) external onlyRole(OPERATOR_ROLE) {
        Subscription[] storage subscriptions = investorSubscriptions[investor];
        
        if (subscriptionIndex >= subscriptions.length) revert SubscriptionNotFound();
        
        Subscription storage subscription = subscriptions[subscriptionIndex];
        
        if (subscription.processed) revert AlreadyProcessed();
        
        // Final compliance check before minting
        _performComplianceChecks(investor);
        
        // Mark as processed
        subscription.processed = true;
        
        // Mint tokens with cliff/hold parameters
        fthgToken.mintWithCliff(
            investor,
            subscription.tokensAllocated,
            subscription.fiveYearHold
        );
        
        emit SubscriptionProcessed(
            investor,
            subscription.amount,
            subscription.tokensAllocated,
            subscription.documentHash
        );
    }
    
    /**
     * @notice Batch process multiple subscriptions
     * @param investors Array of investor addresses
     * @param subscriptionIndices Array of subscription indices
     */
    function batchProcessSubscriptions(
        address[] calldata investors,
        uint256[] calldata subscriptionIndices
    ) external onlyRole(OPERATOR_ROLE) {
        require(investors.length == subscriptionIndices.length, "Array length mismatch");
        
        for (uint256 i = 0; i < investors.length; i++) {
            processSubscription(investors[i], subscriptionIndices[i]);
        }
    }
    
    /**
     * @notice Perform comprehensive compliance checks
     * @param investor Investor address to check
     */
    function _performComplianceChecks(address investor) internal view {
        // Check KYC status
        bool hasKYC = identitySBT.hasValidIdentity(investor);
        
        // Check whitelist status
        bool isWhitelisted = whitelistGate.isWhitelisted(investor);
        
        // Check sanctions status
        bool isSanctioned = complianceRegistry.isRestricted(investor);
        
        emit ComplianceCheck(investor, hasKYC, isWhitelisted, !isSanctioned);
        
        if (!hasKYC || !isWhitelisted || isSanctioned) {
            revert InvestorNotCompliant();
        }
    }
    
    /**
     * @notice Get investor's current nonce for EIP-712 signing
     * @param investor Investor address
     * @return Current nonce
     */
    function getInvestorNonce(address investor) external view returns (uint256) {
        return investorNonces[investor];
    }
    
    /**
     * @notice Get investor's subscription history
     * @param investor Investor address
     * @return Array of subscriptions
     */
    function getInvestorSubscriptions(address investor) 
        external view returns (Subscription[] memory) {
        return investorSubscriptions[investor];
    }
    
    /**
     * @notice Get subscription count for investor
     * @param investor Investor address
     * @return Number of subscriptions
     */
    function getInvestorSubscriptionCount(address investor) 
        external view returns (uint256) {
        return investorSubscriptions[investor].length;
    }
    
    /**
     * @notice Verify document hash and IPFS CID match
     * @param documentHash SHA-256 hash of document
     * @param ipfsCID IPFS Content ID
     * @return True if verification passes
     */
    function verifyDocumentIntegrity(
        bytes32 documentHash,
        string calldata ipfsCID
    ) external view returns (bool) {
        return agreementRegistry.verifyDocument(documentHash, ipfsCID);
    }
    
    /**
     * @notice Get domain separator for EIP-712 signatures
     * @return Domain separator hash
     */
    function getDomainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }
    
    /**
     * @notice Get subscription statistics
     * @return investors Total number of investors
     * @return raised Total amount raised
     * @return allocated Total tokens allocated
     */
    function getSubscriptionStats() external view returns (
        uint256 investors,
        uint256 raised,
        uint256 allocated
    ) {
        return (totalInvestors, totalRaised, totalTokensAllocated);
    }
    
    /**
     * @notice Emergency pause (admin only)
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause (admin only)
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @notice Update contract interfaces (admin only)
     * @param component Component to update (0=identity, 1=compliance, 2=whitelist, 3=agreement)
     * @param newAddress New contract address
     */
    function updateInterface(
        uint8 component,
        address newAddress
    ) external onlyRole(ADMIN_ROLE) {
        require(newAddress != address(0), "Invalid address");
        
        // Note: This would require upgradeable pattern in production
        // For now, we emit events for off-chain monitoring
        emit InterfaceUpdated(component, newAddress);
    }
    
    event InterfaceUpdated(uint8 indexed component, address newAddress);
}