// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./FTHG.sol";
import "../compliance/IdentitySBT.sol";
import "../compliance/ComplianceRegistry.sol";
import "../rails/GatewayRouter.sol";

/**
 * @title SubscriptionPool - FTH-GOLD Token Subscription Handler
 * @notice Manages $20k subscriptions with 5-month cliff and optional 5-year hold
 * @dev Integrates with KYC, compliance, and multi-rail deposits
 */
contract SubscriptionPool is AccessControl, Pausable {
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    
    enum LockMode { Standard, FiveYear }
    
    struct Subscription {
        address user;
        uint256 depositAmount;      // Amount deposited (USD, 18 decimals)
        uint256 kgAllocated;        // Gold kg allocated (18 decimals, 1e18 = 1kg)
        LockMode lockMode;          // Standard or 5-year lock
        uint256 cliffEnd;           // When cliff period ends
        uint256 fiveYearEnd;        // When 5-year hold ends (if applicable)
        bool matured;               // Whether tokens have been minted
        uint256 subscriptionTime;   // When subscription was made
    }
    
    // Configuration
    uint256 public entryPriceUSD = 20000e18;    // $20k per 1kg token (18 decimals)
    uint256 public cliffDurationDays = 150;      // 5 months cliff period
    uint256 public fiveYearDurationDays = 1825;  // 5 years in days
    
    // Contract references
    FTHG public immutable fthgToken;
    IdentitySBT public immutable identitySBT;
    ComplianceRegistry public immutable complianceRegistry;
    GatewayRouter public immutable gatewayRouter;
    
    // Subscription tracking
    mapping(address => Subscription[]) public userSubscriptions;
    mapping(address => uint256) public userSubscriptionCount;
    uint256 public totalSubscriptions;
    uint256 public totalKGAllocated;
    uint256 public totalUSDRaised;
    
    // Supported deposit tokens
    mapping(address => bool) public acceptedTokens;
    address[] public acceptedTokenList;
    
    // Treasury and fee handling
    address public treasury;
    uint256 public subscriptionFeeBps = 250; // 2.5% subscription fee
    
    // Limits and controls
    uint256 public maxTotalKG = 100000e18;        // 100,000 kg program cap
    uint256 public minSubscriptionUSD = 20000e18; // Minimum $20k
    uint256 public maxSubscriptionUSD = 1000000e18; // Maximum $1M per subscription
    bool public subscriptionsActive = true;
    
    event Subscribed(
        address indexed user,
        uint256 indexed subscriptionId,
        uint256 depositAmount,
        uint256 kgAllocated,
        LockMode lockMode,
        uint256 cliffEnd
    );
    
    event Matured(
        address indexed user,
        uint256 indexed subscriptionId,
        uint256 fthgMinted
    );
    
    event AcceptedTokenAdded(address indexed token);
    event AcceptedTokenRemoved(address indexed token);
    event ConfigurationUpdated(string parameter, uint256 newValue);
    
    error NotKYCVerified(address user);
    error ComplianceCheckFailed(address user, bytes32 action);
    error InvalidDepositAmount(uint256 amount, uint256 expected);
    error TokenNotAccepted(address token);
    error SubscriptionsInactive();
    error ProgramCapExceeded(uint256 requested, uint256 available);
    error AlreadyMatured(uint256 subscriptionId);
    error CliffNotEnded(uint256 cliffEnd, uint256 currentTime);
    error InsufficientBalance(address token, uint256 required, uint256 available);
    
    constructor(
        address admin,
        address _fthgToken,
        address _identitySBT,
        address _complianceRegistry,
        address _gatewayRouter,
        address _treasury
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(TREASURY_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
        
        fthgToken = FTHG(_fthgToken);
        identitySBT = IdentitySBT(_identitySBT);
        complianceRegistry = ComplianceRegistry(_complianceRegistry);
        gatewayRouter = GatewayRouter(payable(_gatewayRouter));
        treasury = _treasury;
    }
    
    /**
     * @notice Subscribe to FTH-GOLD program with ERC20 tokens
     * @param depositToken Token to deposit (must be accepted)
     * @param depositAmount Amount to deposit (in token decimals)
     * @param lockMode Standard (5-month) or FiveYear lock
     */
    function subscribe(
        address depositToken,
        uint256 depositAmount,
        LockMode lockMode
    ) external whenNotPaused {
        _validateSubscription(msg.sender, depositAmount);
        
        // Check token acceptance
        if (!acceptedTokens[depositToken]) revert TokenNotAccepted(depositToken);
        
        // Convert deposit amount to USD equivalent (simplified - would use oracle)
        uint256 usdAmount = _convertToUSD(depositToken, depositAmount);
        
        // Validate deposit amount matches entry price
        if (usdAmount < entryPriceUSD) {
            revert InvalidDepositAmount(usdAmount, entryPriceUSD);
        }
        
        // Calculate kg allocation (1 USD = proportional kg based on entry price)
        uint256 kgAllocated = (usdAmount * 1e18) / entryPriceUSD;
        
        // Check program capacity
        if (totalKGAllocated + kgAllocated > maxTotalKG) {
            revert ProgramCapExceeded(kgAllocated, maxTotalKG - totalKGAllocated);
        }
        
        // Transfer tokens to treasury
        IERC20(depositToken).transferFrom(msg.sender, treasury, depositAmount);
        
        // Calculate cliff end time
        uint256 cliffEnd = block.timestamp + (cliffDurationDays * 1 days);
        uint256 fiveYearEnd = lockMode == LockMode.FiveYear ? 
            block.timestamp + (fiveYearDurationDays * 1 days) : 0;
        
        // Create subscription record
        uint256 subscriptionId = userSubscriptionCount[msg.sender];
        userSubscriptions[msg.sender].push(Subscription({
            user: msg.sender,
            depositAmount: usdAmount,
            kgAllocated: kgAllocated,
            lockMode: lockMode,
            cliffEnd: cliffEnd,
            fiveYearEnd: fiveYearEnd,
            matured: false,
            subscriptionTime: block.timestamp
        }));
        
        // Update counters
        userSubscriptionCount[msg.sender]++;
        totalSubscriptions++;
        totalKGAllocated += kgAllocated;
        totalUSDRaised += usdAmount;
        
        emit Subscribed(msg.sender, subscriptionId, usdAmount, kgAllocated, lockMode, cliffEnd);
    }
    
    /**
     * @notice Subscribe using Gateway Router credits (from cross-chain deposits)
     * @param usdAmount Amount in USD credits to use (18 decimals)
     * @param lockMode Standard or FiveYear lock
     */
    function subscribeWithCredits(
        uint256 usdAmount,
        LockMode lockMode
    ) external whenNotPaused {
        _validateSubscription(msg.sender, usdAmount);
        
        // Validate amount matches entry price
        if (usdAmount < entryPriceUSD) {
            revert InvalidDepositAmount(usdAmount, entryPriceUSD);
        }
        
        // Check user has sufficient credits in Gateway Router
        uint256 availableCredits = gatewayRouter.getCreditBalance(msg.sender);
        if (availableCredits < usdAmount) {
            revert InsufficientBalance(address(gatewayRouter), usdAmount, availableCredits);
        }
        
        // Calculate kg allocation
        uint256 kgAllocated = (usdAmount * 1e18) / entryPriceUSD;
        
        // Check program capacity
        if (totalKGAllocated + kgAllocated > maxTotalKG) {
            revert ProgramCapExceeded(kgAllocated, maxTotalKG - totalKGAllocated);
        }
        
        // Withdraw credits from Gateway Router (this transfers to treasury)
        // Note: This would require Gateway Router to have a function that allows
        // authorized contracts to spend user credits
        
        // For now, we'll track the subscription and handle settlement separately
        uint256 cliffEnd = block.timestamp + (cliffDurationDays * 1 days);
        uint256 fiveYearEnd = lockMode == LockMode.FiveYear ? 
            block.timestamp + (fiveYearDurationDays * 1 days) : 0;
        
        // Create subscription record
        uint256 subscriptionId = userSubscriptionCount[msg.sender];
        userSubscriptions[msg.sender].push(Subscription({
            user: msg.sender,
            depositAmount: usdAmount,
            kgAllocated: kgAllocated,
            lockMode: lockMode,
            cliffEnd: cliffEnd,
            fiveYearEnd: fiveYearEnd,
            matured: false,
            subscriptionTime: block.timestamp
        }));
        
        // Update counters
        userSubscriptionCount[msg.sender]++;
        totalSubscriptions++;
        totalKGAllocated += kgAllocated;
        totalUSDRaised += usdAmount;
        
        emit Subscribed(msg.sender, subscriptionId, usdAmount, kgAllocated, lockMode, cliffEnd);
    }
    
    /**
     * @notice Mature a subscription after cliff period ends
     * @param user User address
     * @param subscriptionId Subscription index
     */
    function matureSubscription(address user, uint256 subscriptionId) external whenNotPaused {
        require(subscriptionId < userSubscriptionCount[user], "Invalid subscription ID");
        
        Subscription storage sub = userSubscriptions[user][subscriptionId];
        
        if (sub.matured) revert AlreadyMatured(subscriptionId);
        if (block.timestamp < sub.cliffEnd) revert CliffNotEnded(sub.cliffEnd, block.timestamp);
        
        // Mint FTH-G tokens (1e18 per kg allocated)
        uint256 tokensToMint = sub.kgAllocated;
        sub.matured = true;
        
        // Set cliff period on FTH-G token to prevent transfers
        if (sub.lockMode == LockMode.FiveYear && sub.fiveYearEnd > block.timestamp) {
            fthgToken.setCliff(user, sub.fiveYearEnd);
        }
        
        // Mint tokens to user
        fthgToken.mint(user, tokensToMint);
        
        emit Matured(user, subscriptionId, tokensToMint);
    }
    
    /**
     * @notice Batch mature multiple subscriptions
     * @param users Array of user addresses
     * @param subscriptionIds Array of subscription IDs
     */
    function batchMatureSubscriptions(
        address[] calldata users,
        uint256[] calldata subscriptionIds
    ) external onlyRole(OPERATOR_ROLE) whenNotPaused {
        require(users.length == subscriptionIds.length, "Array length mismatch");
        
        for (uint256 i = 0; i < users.length; i++) {
            // Call internal mature function to avoid duplicate checks
            _matureSubscriptionInternal(users[i], subscriptionIds[i]);
        }
    }
    
    function _matureSubscriptionInternal(address user, uint256 subscriptionId) internal {
        if (subscriptionId >= userSubscriptionCount[user]) return; // Skip invalid IDs
        
        Subscription storage sub = userSubscriptions[user][subscriptionId];
        
        if (sub.matured || block.timestamp < sub.cliffEnd) return; // Skip if already matured or not ready
        
        uint256 tokensToMint = sub.kgAllocated;
        sub.matured = true;
        
        if (sub.lockMode == LockMode.FiveYear && sub.fiveYearEnd > block.timestamp) {
            fthgToken.setCliff(user, sub.fiveYearEnd);
        }
        
        fthgToken.mint(user, tokensToMint);
        emit Matured(user, subscriptionId, tokensToMint);
    }
    
    /**
     * @notice Get user's subscription details
     * @param user User address
     * @param subscriptionId Subscription index
     * @return subscription Subscription details
     */
    function getUserSubscription(address user, uint256 subscriptionId) 
        external view returns (Subscription memory subscription) {
        require(subscriptionId < userSubscriptionCount[user], "Invalid subscription ID");
        return userSubscriptions[user][subscriptionId];
    }
    
    /**
     * @notice Get all subscriptions for a user
     * @param user User address
     * @return subscriptions Array of user's subscriptions
     */
    function getAllUserSubscriptions(address user) 
        external view returns (Subscription[] memory subscriptions) {
        return userSubscriptions[user];
    }
    
    /**
     * @notice Check if user can subscribe
     * @param user User address
     * @return canSubscribe True if user passes all checks
     * @return reason Reason if cannot subscribe
     */
    function canUserSubscribe(address user) 
        external view returns (bool canSubscribe, string memory reason) {
        
        if (!subscriptionsActive) {
            return (false, "Subscriptions inactive");
        }
        
        if (!identitySBT.isVerified(user)) {
            return (false, "KYC not verified");
        }
        
        if (!complianceRegistry.check(user, "SUBSCRIBE")) {
            return (false, "Compliance check failed");
        }
        
        if (totalKGAllocated >= maxTotalKG) {
            return (false, "Program capacity reached");
        }
        
        return (true, "");
    }
    
    function _validateSubscription(address user, uint256 amount) internal view {
        if (!subscriptionsActive) revert SubscriptionsInactive();
        if (!identitySBT.isVerified(user)) revert NotKYCVerified(user);
        if (!complianceRegistry.check(user, "SUBSCRIBE")) {
            revert ComplianceCheckFailed(user, "SUBSCRIBE");
        }
        
        require(amount >= minSubscriptionUSD, "Below minimum subscription");
        require(amount <= maxSubscriptionUSD, "Above maximum subscription");
    }
    
    function _convertToUSD(address token, uint256 amount) internal pure returns (uint256) {
        // Simplified conversion - in production would use ChainlinkPriceFeeds
        // Assume USDT/USDC are 1:1 with USD, ETH needs price conversion
        if (token == address(0)) {
            // ETH - assume $2000 per ETH for demo
            return (amount * 2000e18) / 1e18;
        } else {
            // Assume stablecoins are 1:1 with USD, normalize decimals to 18
            return amount; // Simplified
        }
    }
    
    /**
     * @notice Add accepted deposit token
     * @param token Token address to accept
     */
    function addAcceptedToken(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!acceptedTokens[token]) {
            acceptedTokens[token] = true;
            acceptedTokenList.push(token);
            emit AcceptedTokenAdded(token);
        }
    }
    
    /**
     * @notice Remove accepted deposit token
     * @param token Token address to remove
     */
    function removeAcceptedToken(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (acceptedTokens[token]) {
            acceptedTokens[token] = false;
            emit AcceptedTokenRemoved(token);
        }
    }
    
    /**
     * @notice Update subscription configuration
     */
    function updateConfiguration(
        uint256 _entryPriceUSD,
        uint256 _cliffDurationDays,
        uint256 _maxTotalKG
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_entryPriceUSD > 0) {
            entryPriceUSD = _entryPriceUSD;
            emit ConfigurationUpdated("entryPriceUSD", _entryPriceUSD);
        }
        if (_cliffDurationDays > 0) {
            cliffDurationDays = _cliffDurationDays;
            emit ConfigurationUpdated("cliffDurationDays", _cliffDurationDays);
        }
        if (_maxTotalKG > 0) {
            maxTotalKG = _maxTotalKG;
            emit ConfigurationUpdated("maxTotalKG", _maxTotalKG);
        }
    }
    
    /**
     * @notice Toggle subscription acceptance
     * @param active Whether to accept new subscriptions
     */
    function setSubscriptionsActive(bool active) external onlyRole(DEFAULT_ADMIN_ROLE) {
        subscriptionsActive = active;
    }
    
    /**
     * @notice Emergency pause contract
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Resume contract operations
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}