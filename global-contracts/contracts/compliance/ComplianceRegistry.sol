// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title ComplianceRegistry - Global Sanctions & Jurisdiction Management
 * @notice Manages sanctions lists, jurisdiction restrictions, and compliance flags
 * @dev Integrates with external compliance providers (Chainalysis, TRM Labs, etc.)
 */
contract ComplianceRegistry is AccessControl, Pausable {
    
    bytes32 public constant COMPLIANCE_OFFICER_ROLE = keccak256("COMPLIANCE_OFFICER_ROLE");
    bytes32 public constant SANCTIONS_UPDATER_ROLE = keccak256("SANCTIONS_UPDATER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    enum RestrictionLevel {
        NONE,           // No restrictions
        MONITORING,     // Enhanced monitoring required
        RESTRICTED,     // Limited access
        BLOCKED        // Completely blocked
    }
    
    enum SanctionsList {
        OFAC,    // US Treasury OFAC
        UN,      // United Nations
        EU,      // European Union
        UAE,     // UAE local sanctions
        UK,      // UK HM Treasury
        CUSTOM   // Custom internal list
    }
    
    struct ComplianceProfile {
        RestrictionLevel restrictionLevel;
        SanctionsList[] applicableLists;
        string jurisdiction; // ISO country code
        uint256 riskScore; // 0-1000, where 1000 is highest risk
        uint256 lastUpdated;
        string reason; // Reason for restriction
        bool isPEP; // Politically Exposed Person
        bool hasAdverseMedia; // Adverse media hits
        address updatedBy;
    }
    
    struct JurisdictionRule {
        bool isAllowed;
        uint256 maxInvestors;
        uint256 currentInvestors;
        uint256 perInvestorCap;
        RestrictionLevel defaultRestriction;
        string[] requiredLicenses;
        bool requiresEnhancedKYC;
    }
    
    struct TravelRuleData {
        bool enabled;
        uint256 threshold; // Threshold amount for travel rule
        string provider; // "TRISA", "Notabene", etc.
        address beneficiaryVASP;
        string beneficiaryVASPName;
    }
    
    // State mappings
    mapping(address => ComplianceProfile) public complianceProfiles;
    mapping(string => JurisdictionRule) public jurisdictionRules; // country code => rules
    mapping(address => bool) public restrictedAddresses;
    mapping(address => TravelRuleData) public travelRuleData;
    
    // Sanctions lists management
    mapping(SanctionsList => mapping(address => bool)) public sanctionedAddresses;
    mapping(SanctionsList => uint256) public lastSanctionsUpdate;
    
    // Global compliance settings
    uint256 public globalRiskThreshold = 700; // Addresses above this score are auto-restricted
    bool public travelRuleEnabled = true;
    uint256 public travelRuleThreshold = 1000e6; // $1000 USDT threshold
    
    // Provider integrations
    mapping(string => bool) public approvedComplianceProviders;
    mapping(address => string) public addressToProvider; // Which provider flagged this address
    
    // Events
    event AddressRestricted(
        address indexed wallet,
        RestrictionLevel level,
        string reason,
        address officer
    );
    
    event AddressUnrestricted(
        address indexed wallet,
        address officer
    );
    
    event SanctionsListUpdated(
        SanctionsList indexed list,
        uint256 addressesAdded,
        uint256 addressesRemoved,
        address updater
    );
    
    event JurisdictionRuleUpdated(
        string indexed jurisdiction,
        bool allowed,
        uint256 maxInvestors,
        uint256 perInvestorCap
    );
    
    event TravelRuleTriggered(
        address indexed from,
        address indexed to,
        uint256 amount,
        string provider
    );
    
    event ComplianceProviderUpdated(
        string provider,
        bool approved
    );
    
    // Errors
    error AddressRestricted(address wallet, RestrictionLevel level);
    error JurisdictionBlocked(string jurisdiction);
    error RiskScoreTooHigh(address wallet, uint256 score);
    error UnauthorizedProvider(string provider);
    error ExceedsJurisdictionCap(string jurisdiction);
    error InvalidRestrictionLevel();
    
    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(COMPLIANCE_OFFICER_ROLE, admin);
        _grantRole(SANCTIONS_UPDATER_ROLE, admin);
        
        // Initialize default jurisdiction rules
        _initializeDefaultJurisdictions();
        
        // Approve default compliance providers
        approvedComplianceProviders["Chainalysis"] = true;
        approvedComplianceProviders["TRM Labs"] = true;
        approvedComplianceProviders["Elliptic"] = true;
        approvedComplianceProviders["Internal"] = true;
    }
    
    /**
     * @notice Check if address is restricted
     * @param wallet Address to check
     * @return True if restricted (blocked or restricted level)
     */
    function isRestricted(address wallet) external view returns (bool) {
        ComplianceProfile storage profile = complianceProfiles[wallet];
        
        return profile.restrictionLevel == RestrictionLevel.RESTRICTED ||
               profile.restrictionLevel == RestrictionLevel.BLOCKED ||
               restrictedAddresses[wallet];
    }
    
    /**
     * @notice Check if address is sanctioned
     * @param wallet Address to check
     * @return sanctioned True if on any sanctions list
     * @return lists Array of applicable sanctions lists
     */
    function isSanctioned(address wallet) external view returns (
        bool sanctioned,
        SanctionsList[] memory lists
    ) {
        SanctionsList[] memory applicableLists = new SanctionsList[](6);
        uint256 count = 0;
        
        if (sanctionedAddresses[SanctionsList.OFAC][wallet]) {
            applicableLists[count++] = SanctionsList.OFAC;
        }
        if (sanctionedAddresses[SanctionsList.UN][wallet]) {
            applicableLists[count++] = SanctionsList.UN;
        }
        if (sanctionedAddresses[SanctionsList.EU][wallet]) {
            applicableLists[count++] = SanctionsList.EU;
        }
        if (sanctionedAddresses[SanctionsList.UAE][wallet]) {
            applicableLists[count++] = SanctionsList.UAE;
        }
        if (sanctionedAddresses[SanctionsList.UK][wallet]) {
            applicableLists[count++] = SanctionsList.UK;
        }
        if (sanctionedAddresses[SanctionsList.CUSTOM][wallet]) {
            applicableLists[count++] = SanctionsList.CUSTOM;
        }
        
        // Resize array to actual count
        lists = new SanctionsList[](count);
        for (uint256 i = 0; i < count; i++) {
            lists[i] = applicableLists[i];
        }
        
        sanctioned = count > 0;
    }
    
    /**
     * @notice Set compliance profile for address
     * @param wallet Target address
     * @param restrictionLevel Restriction level
     * @param jurisdiction ISO country code
     * @param riskScore Risk score (0-1000)
     * @param reason Reason for restriction
     * @param isPEP Whether address is PEP
     * @param hasAdverseMedia Whether address has adverse media
     */
    function setComplianceProfile(
        address wallet,
        RestrictionLevel restrictionLevel,
        string calldata jurisdiction,
        uint256 riskScore,
        string calldata reason,
        bool isPEP,
        bool hasAdverseMedia
    ) external onlyRole(COMPLIANCE_OFFICER_ROLE) whenNotPaused {
        require(riskScore <= 1000, "Risk score must be <= 1000");
        
        SanctionsList[] memory emptyLists;
        
        complianceProfiles[wallet] = ComplianceProfile({
            restrictionLevel: restrictionLevel,
            applicableLists: emptyLists,
            jurisdiction: jurisdiction,
            riskScore: riskScore,
            lastUpdated: block.timestamp,
            reason: reason,
            isPEP: isPEP,
            hasAdverseMedia: hasAdverseMedia,
            updatedBy: msg.sender
        });
        
        // Auto-restrict if risk score is too high
        if (riskScore >= globalRiskThreshold) {
            restrictedAddresses[wallet] = true;
        }
        
        emit AddressRestricted(wallet, restrictionLevel, reason, msg.sender);
    }
    
    /**
     * @notice Bulk update sanctions list
     * @param list Sanctions list to update
     * @param addresses Array of addresses
     * @param sanctioned Array of sanctions status (true = add, false = remove)
     */
    function bulkUpdateSanctionsList(
        SanctionsList list,
        address[] calldata addresses,
        bool[] calldata sanctioned
    ) external onlyRole(SANCTIONS_UPDATER_ROLE) {
        require(addresses.length == sanctioned.length, "Array length mismatch");
        
        uint256 added = 0;
        uint256 removed = 0;
        
        for (uint256 i = 0; i < addresses.length; i++) {
            if (sanctioned[i]) {
                if (!sanctionedAddresses[list][addresses[i]]) {
                    sanctionedAddresses[list][addresses[i]] = true;
                    added++;
                }
            } else {
                if (sanctionedAddresses[list][addresses[i]]) {
                    sanctionedAddresses[list][addresses[i]] = false;
                    removed++;
                }
            }
        }
        
        lastSanctionsUpdate[list] = block.timestamp;
        
        emit SanctionsListUpdated(list, added, removed, msg.sender);
    }
    
    /**
     * @notice Set jurisdiction rules
     * @param jurisdiction ISO country code
     * @param isAllowed Whether jurisdiction is allowed
     * @param maxInvestors Maximum investors from this jurisdiction
     * @param perInvestorCap Per-investor investment cap
     * @param defaultRestriction Default restriction level
     * @param requiresEnhancedKYC Whether enhanced KYC is required
     */
    function setJurisdictionRule(
        string calldata jurisdiction,
        bool isAllowed,
        uint256 maxInvestors,
        uint256 perInvestorCap,
        RestrictionLevel defaultRestriction,
        bool requiresEnhancedKYC
    ) external onlyRole(ADMIN_ROLE) {
        string[] memory emptyLicenses;
        
        jurisdictionRules[jurisdiction] = JurisdictionRule({
            isAllowed: isAllowed,
            maxInvestors: maxInvestors,
            currentInvestors: jurisdictionRules[jurisdiction].currentInvestors, // Preserve current count
            perInvestorCap: perInvestorCap,
            defaultRestriction: defaultRestriction,
            requiredLicenses: emptyLicenses,
            requiresEnhancedKYC: requiresEnhancedKYC
        });
        
        emit JurisdictionRuleUpdated(jurisdiction, isAllowed, maxInvestors, perInvestorCap);
    }
    
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
    ) external view returns (bool allowed, bool enhancedKYCRequired) {
        JurisdictionRule storage rule = jurisdictionRules[jurisdiction];
        
        allowed = rule.isAllowed;
        
        if (newInvestor && rule.currentInvestors >= rule.maxInvestors) {
            allowed = false;
        }
        
        enhancedKYCRequired = rule.requiresEnhancedKYC;
    }
    
    /**
     * @notice Increment investor count for jurisdiction
     * @param jurisdiction ISO country code
     */
    function incrementJurisdictionCount(
        string calldata jurisdiction
    ) external onlyRole(COMPLIANCE_OFFICER_ROLE) {
        jurisdictionRules[jurisdiction].currentInvestors++;
    }
    
    /**
     * @notice Record travel rule transaction
     * @param from Sender address
     * @param to Recipient address
     * @param amount Transaction amount
     * @param provider Travel rule provider
     */
    function recordTravelRuleTransaction(
        address from,
        address to,
        uint256 amount,
        string calldata provider
    ) external onlyRole(COMPLIANCE_OFFICER_ROLE) {
        if (travelRuleEnabled && amount >= travelRuleThreshold) {
            travelRuleData[from] = TravelRuleData({
                enabled: true,
                threshold: travelRuleThreshold,
                provider: provider,
                beneficiaryVASP: to,
                beneficiaryVASPName: ""
            });
            
            emit TravelRuleTriggered(from, to, amount, provider);
        }
    }
    
    /**
     * @notice Update compliance provider integration
     * @param provider Provider name
     * @param wallet Address flagged by provider
     * @param restrictionLevel Recommended restriction level
     * @param riskScore Risk score from provider
     * @param reason Reason for flagging
     */
    function updateFromComplianceProvider(
        string calldata provider,
        address wallet,
        RestrictionLevel restrictionLevel,
        uint256 riskScore,
        string calldata reason
    ) external onlyRole(SANCTIONS_UPDATER_ROLE) {
        if (!approvedComplianceProviders[provider]) {
            revert UnauthorizedProvider(provider);
        }
        
        addressToProvider[wallet] = provider;
        
        // Update or create compliance profile
        ComplianceProfile storage profile = complianceProfiles[wallet];
        profile.restrictionLevel = restrictionLevel;
        profile.riskScore = riskScore;
        profile.reason = reason;
        profile.lastUpdated = block.timestamp;
        profile.updatedBy = msg.sender;
        
        if (riskScore >= globalRiskThreshold || restrictionLevel >= RestrictionLevel.RESTRICTED) {
            restrictedAddresses[wallet] = true;
        }
    }
    
    /**
     * @notice Batch compliance check for multiple addresses
     * @param addresses Array of addresses to check
     * @return results Array of compliance results
     */
    function batchComplianceCheck(
        address[] calldata addresses
    ) external view returns (bool[] memory results) {
        results = new bool[](addresses.length);
        
        for (uint256 i = 0; i < addresses.length; i++) {
            results[i] = !this.isRestricted(addresses[i]);
        }
    }
    
    /**
     * @notice Get compliance profile
     * @param wallet Address to check
     * @return profile Compliance profile
     */
    function getComplianceProfile(address wallet) 
        external view returns (ComplianceProfile memory profile) {
        return complianceProfiles[wallet];
    }
    
    /**
     * @notice Unrestrict address (admin emergency function)
     * @param wallet Address to unrestrict
     */
    function unrestrictAddress(
        address wallet
    ) external onlyRole(ADMIN_ROLE) {
        restrictedAddresses[wallet] = false;
        complianceProfiles[wallet].restrictionLevel = RestrictionLevel.NONE;
        complianceProfiles[wallet].lastUpdated = block.timestamp;
        complianceProfiles[wallet].updatedBy = msg.sender;
        
        emit AddressUnrestricted(wallet, msg.sender);
    }
    
    /**
     * @notice Initialize default jurisdiction rules
     */
    function _initializeDefaultJurisdictions() internal {
        // UAE - Allowed
        jurisdictionRules["AE"] = JurisdictionRule({
            isAllowed: true,
            maxInvestors: 100,
            currentInvestors: 0,
            perInvestorCap: 10_000_000e6, // $10M
            defaultRestriction: RestrictionLevel.NONE,
            requiredLicenses: new string[](0),
            requiresEnhancedKYC: false
        });
        
        // US - Blocked (no private placement exemption)
        jurisdictionRules["US"] = JurisdictionRule({
            isAllowed: false,
            maxInvestors: 0,
            currentInvestors: 0,
            perInvestorCap: 0,
            defaultRestriction: RestrictionLevel.BLOCKED,
            requiredLicenses: new string[](0),
            requiresEnhancedKYC: true
        });
        
        // UK - Allowed with restrictions
        jurisdictionRules["GB"] = JurisdictionRule({
            isAllowed: true,
            maxInvestors: 50,
            currentInvestors: 0,
            perInvestorCap: 5_000_000e6, // $5M
            defaultRestriction: RestrictionLevel.MONITORING,
            requiredLicenses: new string[](0),
            requiresEnhancedKYC: true
        });
    }
    
    /**
     * @notice Update global risk threshold
     * @param newThreshold New risk threshold (0-1000)
     */
    function updateGlobalRiskThreshold(
        uint256 newThreshold
    ) external onlyRole(ADMIN_ROLE) {
        require(newThreshold <= 1000, "Threshold must be <= 1000");
        globalRiskThreshold = newThreshold;
    }
    
    /**
     * @notice Update travel rule settings
     * @param enabled Whether travel rule is enabled
     * @param threshold New threshold amount
     */
    function updateTravelRuleSettings(
        bool enabled,
        uint256 threshold
    ) external onlyRole(ADMIN_ROLE) {
        travelRuleEnabled = enabled;
        travelRuleThreshold = threshold;
    }
    
    /**
     * @notice Approve/disapprove compliance provider
     * @param provider Provider name
     * @param approved Approval status
     */
    function setComplianceProviderApproval(
        string calldata provider,
        bool approved
    ) external onlyRole(ADMIN_ROLE) {
        approvedComplianceProviders[provider] = approved;
        emit ComplianceProviderUpdated(provider, approved);
    }
    
    /**
     * @notice Pause compliance operations
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause compliance operations
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}