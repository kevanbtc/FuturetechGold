// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title ComplianceRegistry - KYC/AML and Sanctions Compliance
 * @notice Manages user compliance status, sanctions screening, and jurisdiction controls
 * @dev Integrates with Dubai DMCC requirements and international compliance standards
 */
contract ComplianceRegistry is AccessControl, Pausable {
    bytes32 public constant COMPLIANCE_OFFICER_ROLE = keccak256("COMPLIANCE_OFFICER_ROLE");
    bytes32 public constant SANCTIONS_SCREENER_ROLE = keccak256("SANCTIONS_SCREENER_ROLE");
    bytes32 public constant RISK_ASSESSOR_ROLE = keccak256("RISK_ASSESSOR_ROLE");
    
    enum RiskLevel { Low, Medium, High, Prohibited }
    enum JurisdictionStatus { Allowed, Restricted, Prohibited }
    
    struct UserProfile {
        bool kycCompleted;
        bool sanctionsScreened;
        bool pepScreened;
        bool adverseMediaScreened;
        RiskLevel riskLevel;
        bytes32 jurisdictionCode; // ISO 3166-1 alpha-2 country code
        uint256 lastScreeningUpdate;
        uint256 kycExpiryDate;
        string[] attachedDocuments; // IPFS hashes of compliance documents
        mapping(bytes32 => bool) actionPermissions; // Specific action permissions
    }
    
    struct JurisdictionConfig {
        JurisdictionStatus status;
        bool requiresEnhancedDD;
        uint256 maxInvestmentAmount;
        string[] requiredDocuments;
        string regulatoryNotes;
    }
    
    struct ActionConfig {
        bool enabled;
        bool requiresKYC;
        bool requiresSanctionsScreen;
        bool requiresRiskAssessment;
        RiskLevel maxRiskLevel;
        bytes32[] allowedJurisdictions;
        uint256 cooldownPeriod; // Minimum time between actions
    }
    
    // User compliance data
    mapping(address => UserProfile) public userProfiles;
    mapping(address => uint256) public lastActionTime;
    mapping(address => bool) public globallyBlocked; // Emergency block list
    
    // Jurisdiction management
    mapping(bytes32 => JurisdictionConfig) public jurisdictions;
    bytes32[] public supportedJurisdictions;
    
    // Action configuration (SUBSCRIBE, TRANSFER, REDEEM, etc.)
    mapping(bytes32 => ActionConfig) public actionConfigs;
    bytes32[] public configuredActions;
    
    // Sanctions lists (merkle roots or direct mappings for efficiency)
    mapping(bytes32 => bool) public sanctionedAddresses; // Hash of (address + source)
    mapping(bytes32 => bool) public sanctionedEntities;  // Hash of (entity_name + source)
    bytes32 public sanctionsListRoot; // Merkle root for gas-efficient bulk screening
    
    // Risk scoring parameters
    mapping(bytes32 => uint256) public riskFactorWeights;
    uint256 public lowRiskThreshold = 25;
    uint256 public mediumRiskThreshold = 60;
    uint256 public highRiskThreshold = 85;
    
    // Dubai-specific compliance flags
    bool public dubaiModeEnabled = true;
    bytes32 public constant DUBAI_JURISDICTION = keccak256("AE"); // UAE
    uint256 public dmccReportingThreshold = 200000e18; // $200k reporting threshold
    
    event UserProfileUpdated(address indexed user, string updateType);
    event RiskAssessmentUpdated(address indexed user, RiskLevel oldLevel, RiskLevel newLevel);
    event SanctionsScreeningPerformed(address indexed user, bool passed, string source);
    event JurisdictionConfigured(bytes32 indexed jurisdictionCode, JurisdictionStatus status);
    event ActionConfigUpdated(bytes32 indexed action, bool enabled);
    event ComplianceViolation(address indexed user, bytes32 action, string reason);
    event GlobalBlockStatusChanged(address indexed user, bool blocked);
    
    error UserNotCompliant(address user, string reason);
    error ActionNotPermitted(address user, bytes32 action);
    error JurisdictionNotAllowed(bytes32 jurisdictionCode);
    error SanctionsMatch(address user, string source);
    error InsufficientRiskClearance(address user, RiskLevel required, RiskLevel actual);
    error ActionCooldownActive(address user, bytes32 action, uint256 remainingTime);
    error KYCExpired(address user, uint256 expiryDate);
    
    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(COMPLIANCE_OFFICER_ROLE, admin);
        _grantRole(SANCTIONS_SCREENER_ROLE, admin);
        _grantRole(RISK_ASSESSOR_ROLE, admin);
        
        // Initialize default jurisdictions
        _configureJurisdiction("AE", JurisdictionStatus.Allowed, false, type(uint256).max, "UAE - Primary jurisdiction");
        _configureJurisdiction("US", JurisdictionStatus.Prohibited, true, 0, "US persons prohibited");
        _configureJurisdiction("GB", JurisdictionStatus.Allowed, false, 1000000e18, "UK - Standard compliance");
        _configureJurisdiction("SG", JurisdictionStatus.Allowed, false, 1000000e18, "Singapore - Standard compliance");
        
        // Initialize default actions
        _configureAction("SUBSCRIBE", true, true, true, true, RiskLevel.Medium, 3600);
        _configureAction("TRANSFER", true, true, true, false, RiskLevel.High, 0);
        _configureAction("REDEEM", true, true, true, true, RiskLevel.Medium, 86400);
        _configureAction("PAYOUT", true, true, true, false, RiskLevel.High, 0);
        
        // Initialize risk factors
        riskFactorWeights["HIGH_RISK_JURISDICTION"] = 30;
        riskFactorWeights["PEP_STATUS"] = 25;
        riskFactorWeights["ADVERSE_MEDIA"] = 20;
        riskFactorWeights["LARGE_TRANSACTION"] = 15;
        riskFactorWeights["FREQUENT_TRANSACTIONS"] = 10;
    }
    
    /**
     * @notice Complete KYC process for a user
     * @param user User address
     * @param jurisdictionCode ISO country code
     * @param riskLevel Assessed risk level
     * @param kycExpiryDate When KYC expires
     * @param documentHashes IPFS hashes of KYC documents
     */
    function completeKYC(
        address user,
        bytes32 jurisdictionCode,
        RiskLevel riskLevel,
        uint256 kycExpiryDate,
        string[] calldata documentHashes
    ) external onlyRole(COMPLIANCE_OFFICER_ROLE) {
        UserProfile storage profile = userProfiles[user];
        
        profile.kycCompleted = true;
        profile.jurisdictionCode = jurisdictionCode;
        profile.riskLevel = riskLevel;
        profile.kycExpiryDate = kycExpiryDate;
        profile.lastScreeningUpdate = block.timestamp;
        
        // Store document hashes
        delete profile.attachedDocuments;
        for (uint256 i = 0; i < documentHashes.length; i++) {
            profile.attachedDocuments.push(documentHashes[i]);
        }
        
        emit UserProfileUpdated(user, "KYC_COMPLETED");
        emit RiskAssessmentUpdated(user, RiskLevel.Low, riskLevel);
    }
    
    /**
     * @notice Perform sanctions screening for a user
     * @param user User address
     * @param passed Whether screening passed
     * @param source Screening source identifier
     * @param pepStatus Whether user is a PEP
     * @param adverseMedia Whether adverse media found
     */
    function performSanctionsScreening(
        address user,
        bool passed,
        string calldata source,
        bool pepStatus,
        bool adverseMedia
    ) external onlyRole(SANCTIONS_SCREENER_ROLE) {
        if (!passed) revert SanctionsMatch(user, source);
        
        UserProfile storage profile = userProfiles[user];
        profile.sanctionsScreened = true;
        profile.pepScreened = true;
        profile.adverseMediaScreened = true;
        profile.lastScreeningUpdate = block.timestamp;
        
        // Adjust risk level based on screening results
        if (pepStatus || adverseMedia) {
            RiskLevel oldLevel = profile.riskLevel;
            if (pepStatus && adverseMedia) {
                profile.riskLevel = RiskLevel.High;
            } else if (pepStatus || adverseMedia) {
                profile.riskLevel = profile.riskLevel == RiskLevel.Low ? RiskLevel.Medium : RiskLevel.High;
            }
            
            if (profile.riskLevel != oldLevel) {
                emit RiskAssessmentUpdated(user, oldLevel, profile.riskLevel);
            }
        }
        
        emit SanctionsScreeningPerformed(user, passed, source);
        emit UserProfileUpdated(user, "SANCTIONS_SCREENED");
    }
    
    /**
     * @notice Check if user can perform a specific action
     * @param user User address
     * @param action Action identifier (SUBSCRIBE, TRANSFER, REDEEM, etc.)
     * @return allowed Whether action is allowed
     */
    function check(address user, bytes32 action) external view returns (bool allowed) {
        // Global blocks override everything
        if (globallyBlocked[user]) return false;
        
        ActionConfig memory config = actionConfigs[action];
        if (!config.enabled) return false;
        
        UserProfile storage profile = userProfiles[user];
        
        // Check KYC requirements
        if (config.requiresKYC && !profile.kycCompleted) return false;
        if (profile.kycCompleted && block.timestamp > profile.kycExpiryDate) return false;
        
        // Check sanctions screening
        if (config.requiresSanctionsScreen && !profile.sanctionsScreened) return false;
        
        // Check risk level
        if (config.requiresRiskAssessment && profile.riskLevel > config.maxRiskLevel) return false;
        
        // Check jurisdiction restrictions
        JurisdictionConfig memory jurisdiction = jurisdictions[profile.jurisdictionCode];
        if (jurisdiction.status == JurisdictionStatus.Prohibited) return false;
        
        // Check jurisdiction allowlist for action
        if (config.allowedJurisdictions.length > 0) {
            bool jurisdictionAllowed = false;
            for (uint256 i = 0; i < config.allowedJurisdictions.length; i++) {
                if (config.allowedJurisdictions[i] == profile.jurisdictionCode) {
                    jurisdictionAllowed = true;
                    break;
                }
            }
            if (!jurisdictionAllowed) return false;
        }
        
        // Check cooldown period
        if (config.cooldownPeriod > 0) {
            if (block.timestamp < lastActionTime[user] + config.cooldownPeriod) return false;
        }
        
        // Check specific action permissions (if set)
        // This allows for granular control per user per action
        return true; // Default to allowed if all checks pass
    }
    
    /**
     * @notice Record that a user performed an action (for cooldown tracking)
     * @param user User address
     * @param action Action performed
     */
    function recordAction(address user, bytes32 action) external {
        // Only allow calls from authorized contracts (e.g., SubscriptionPool)
        require(hasRole(COMPLIANCE_OFFICER_ROLE, msg.sender) || 
                hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Unauthorized");
        
        lastActionTime[user] = block.timestamp;
    }
    
    /**
     * @notice Calculate risk score for a user
     * @param user User address
     * @return score Risk score (0-100)
     * @return level Risk level enum
     */
    function calculateRiskScore(address user) external view returns (uint256 score, RiskLevel level) {
        UserProfile storage profile = userProfiles[user];
        JurisdictionConfig memory jurisdiction = jurisdictions[profile.jurisdictionCode];
        
        // Base score starts at 0
        score = 0;
        
        // Add jurisdiction risk
        if (jurisdiction.status == JurisdictionStatus.Restricted) {
            score += riskFactorWeights["HIGH_RISK_JURISDICTION"];
        }
        
        // Add PEP risk (this would be determined during screening)
        // For now, assume we store this in action permissions mapping
        
        // Add transaction-based risk factors would be calculated here
        // based on historical transaction patterns
        
        // Determine risk level based on thresholds
        if (score < lowRiskThreshold) {
            level = RiskLevel.Low;
        } else if (score < mediumRiskThreshold) {
            level = RiskLevel.Medium;
        } else if (score < highRiskThreshold) {
            level = RiskLevel.High;
        } else {
            level = RiskLevel.Prohibited;
        }
    }
    
    /**
     * @notice Configure a jurisdiction
     * @param jurisdictionCode ISO country code
     * @param status Jurisdiction status
     * @param requiresEnhancedDD Whether enhanced due diligence required
     * @param maxInvestment Maximum investment amount
     * @param notes Regulatory notes
     */
    function configureJurisdiction(
        bytes32 jurisdictionCode,
        JurisdictionStatus status,
        bool requiresEnhancedDD,
        uint256 maxInvestment,
        string calldata notes
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _configureJurisdiction(jurisdictionCode, status, requiresEnhancedDD, maxInvestment, notes);
    }
    
    function _configureJurisdiction(
        bytes32 jurisdictionCode,
        JurisdictionStatus status,
        bool requiresEnhancedDD,
        uint256 maxInvestment,
        string memory notes
    ) internal {
        JurisdictionConfig storage config = jurisdictions[jurisdictionCode];
        
        bool isNew = config.status == JurisdictionStatus.Prohibited && 
                     bytes(config.regulatoryNotes).length == 0;
        
        config.status = status;
        config.requiresEnhancedDD = requiresEnhancedDD;
        config.maxInvestmentAmount = maxInvestment;
        config.regulatoryNotes = notes;
        
        if (isNew) {
            supportedJurisdictions.push(jurisdictionCode);
        }
        
        emit JurisdictionConfigured(jurisdictionCode, status);
    }
    
    /**
     * @notice Configure an action's compliance requirements
     * @param action Action identifier
     * @param enabled Whether action is enabled
     * @param requiresKYC Whether KYC is required
     * @param requiresSanctions Whether sanctions screening is required
     * @param requiresRisk Whether risk assessment is required
     * @param maxRisk Maximum allowed risk level
     * @param cooldown Cooldown period in seconds
     */
    function configureAction(
        bytes32 action,
        bool enabled,
        bool requiresKYC,
        bool requiresSanctions,
        bool requiresRisk,
        RiskLevel maxRisk,
        uint256 cooldown
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _configureAction(action, enabled, requiresKYC, requiresSanctions, requiresRisk, maxRisk, cooldown);
    }
    
    function _configureAction(
        bytes32 action,
        bool enabled,
        bool requiresKYC,
        bool requiresSanctions,
        bool requiresRisk,
        RiskLevel maxRisk,
        uint256 cooldown
    ) internal {
        ActionConfig storage config = actionConfigs[action];
        
        bool isNew = !config.enabled && config.cooldownPeriod == 0;
        
        config.enabled = enabled;
        config.requiresKYC = requiresKYC;
        config.requiresSanctionsScreen = requiresSanctions;
        config.requiresRiskAssessment = requiresRisk;
        config.maxRiskLevel = maxRisk;
        config.cooldownPeriod = cooldown;
        
        if (isNew) {
            configuredActions.push(action);
        }
        
        emit ActionConfigUpdated(action, enabled);
    }
    
    /**
     * @notice Set global block status for a user (emergency function)
     * @param user User address
     * @param blocked Whether to block user
     */
    function setGlobalBlock(address user, bool blocked) external onlyRole(COMPLIANCE_OFFICER_ROLE) {
        globallyBlocked[user] = blocked;
        emit GlobalBlockStatusChanged(user, blocked);
    }
    
    /**
     * @notice Get user's compliance status summary
     * @param user User address
     * @return kycCompleted Whether KYC is completed
     * @return sanctionsScreened Whether sanctions screening passed
     * @return riskLevel Current risk level
     * @return kycExpiry KYC expiry timestamp
     * @return blocked Whether user is globally blocked
     */
    function getUserComplianceStatus(address user) 
        external view returns (
            bool kycCompleted,
            bool sanctionsScreened,
            RiskLevel riskLevel,
            uint256 kycExpiry,
            bool blocked
        ) {
        UserProfile storage profile = userProfiles[user];
        
        return (
            profile.kycCompleted,
            profile.sanctionsScreened,
            profile.riskLevel,
            profile.kycExpiryDate,
            globallyBlocked[user]
        );
    }
    
    /**
     * @notice Emergency pause all compliance checking (allows admin override)
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Resume normal compliance operations
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}