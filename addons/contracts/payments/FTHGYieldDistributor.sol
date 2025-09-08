// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IFTHGCore.sol";

/**
 * @title FTHGYieldDistributor - Monthly Yield Distribution System
 * @notice Non-breaking add-on for distributing monthly yields to FTH-G holders
 * @dev Pull-based distribution system with epoch management and rate controls
 */
contract FTHGYieldDistributor is Ownable, ReentrancyGuard {
    
    struct EpochData {
        uint256 startTime;
        uint256 endTime;
        uint256 totalDistributed;
        uint256 rateBps;           // Distribution rate in basis points
        uint256 eligibleSupply;   // Total eligible token supply
        bool finalized;
    }
    
    struct UserClaim {
        uint256 lastClaimedEpoch;
        uint256 totalClaimed;
    }
    
    // Core contracts
    IFTHGCore public immutable core;
    IERC20 public immutable distributionToken; // USDT typically
    
    // Epoch management
    uint256 public currentEpoch;
    uint256 public constant EPOCH_DURATION = 30 days;
    mapping(uint256 => EpochData) public epochs;
    
    // User tracking
    mapping(address => UserClaim) public userClaims;
    mapping(uint256 => mapping(address => bool)) public epochClaimed;
    
    // Rate controls
    uint256 public defaultRateBps = 1000;      // 10% default
    uint256 public maxRateBps = 1500;          // 15% maximum  
    uint256 public minRateBps = 500;           // 5% minimum
    
    // Emergency controls
    bool public distributionsPaused;
    address public emergencyPauser;
    
    // Events
    event EpochStarted(uint256 indexed epoch, uint256 startTime, uint256 rateBps);
    event EpochFinalized(uint256 indexed epoch, uint256 totalDistributed, uint256 eligibleSupply);
    event YieldClaimed(address indexed user, uint256 indexed epoch, uint256 amount);
    event RateUpdated(uint256 oldRate, uint256 newRate);
    event EmergencyPause(bool paused);
    event FundsWithdrawn(address indexed token, uint256 amount, address indexed to);
    
    // Errors
    error NotEligible(address user);
    error EpochNotActive(uint256 epoch);
    error EpochAlreadyClaimed(address user, uint256 epoch);
    error InsufficientFunds(uint256 required, uint256 available);
    error DistributionsPaused();
    error InvalidRate(uint256 rate);
    error EpochNotFinalized(uint256 epoch);
    error NotAuthorized();
    
    constructor(
        address _core,
        address _distributionToken,
        address _owner,
        address _emergencyPauser
    ) Ownable(_owner) {
        core = IFTHGCore(_core);
        distributionToken = IERC20(_distributionToken);
        emergencyPauser = _emergencyPauser;
        
        // Initialize first epoch
        _startNewEpoch(defaultRateBps);
    }
    
    modifier whenNotPaused() {
        if (distributionsPaused) revert DistributionsPaused();
        _;
    }
    
    modifier onlyAuthorized() {
        if (msg.sender != owner() && msg.sender != emergencyPauser) revert NotAuthorized();
        _;
    }
    
    /**
     * @notice Start a new distribution epoch
     * @param rateBps Distribution rate in basis points (10000 = 100%)
     */
    function startNewEpoch(uint256 rateBps) external onlyOwner {
        require(rateBps >= minRateBps && rateBps <= maxRateBps, "Rate out of bounds");
        
        // Finalize current epoch if not already done
        if (!epochs[currentEpoch].finalized) {
            _finalizeEpoch(currentEpoch);
        }
        
        _startNewEpoch(rateBps);
    }
    
    function _startNewEpoch(uint256 rateBps) internal {
        currentEpoch++;
        
        epochs[currentEpoch] = EpochData({
            startTime: block.timestamp,
            endTime: block.timestamp + EPOCH_DURATION,
            totalDistributed: 0,
            rateBps: rateBps,
            eligibleSupply: 0, // Will be set when finalized
            finalized: false
        });
        
        emit EpochStarted(currentEpoch, block.timestamp, rateBps);
    }
    
    /**
     * @notice Claim yield for a specific epoch
     * @param epoch Epoch number to claim
     */
    function claimYield(uint256 epoch) external nonReentrant whenNotPaused {
        if (!_isEligible(msg.sender)) revert NotEligible(msg.sender);
        if (!epochs[epoch].finalized) revert EpochNotFinalized(epoch);
        if (epochClaimed[epoch][msg.sender]) revert EpochAlreadyClaimed(msg.sender, epoch);
        
        uint256 userBalance = core.balanceOf(msg.sender);
        uint256 claimAmount = _calculateClaim(epoch, userBalance);
        
        if (claimAmount == 0) return; // Nothing to claim
        
        // Check contract has sufficient funds
        uint256 available = distributionToken.balanceOf(address(this));
        if (available < claimAmount) revert InsufficientFunds(claimAmount, available);
        
        // Mark as claimed
        epochClaimed[epoch][msg.sender] = true;
        userClaims[msg.sender].lastClaimedEpoch = epoch;
        userClaims[msg.sender].totalClaimed += claimAmount;
        epochs[epoch].totalDistributed += claimAmount;
        
        // Transfer yield
        require(distributionToken.transfer(msg.sender, claimAmount), "Transfer failed");
        
        emit YieldClaimed(msg.sender, epoch, claimAmount);
    }
    
    /**
     * @notice Claim yield for multiple epochs
     * @param epochIds Array of epoch numbers to claim
     */
    function claimMultipleEpochs(uint256[] calldata epochIds) external nonReentrant whenNotPaused {
        if (!_isEligible(msg.sender)) revert NotEligible(msg.sender);
        
        uint256 totalClaim = 0;
        uint256 userBalance = core.balanceOf(msg.sender);
        
        for (uint256 i = 0; i < epochIds.length; i++) {
            uint256 epoch = epochIds[i];
            
            if (!epochs[epoch].finalized) continue;
            if (epochClaimed[epoch][msg.sender]) continue;
            
            uint256 claimAmount = _calculateClaim(epoch, userBalance);
            if (claimAmount == 0) continue;
            
            epochClaimed[epoch][msg.sender] = true;
            totalClaim += claimAmount;
            epochs[epoch].totalDistributed += claimAmount;
            
            emit YieldClaimed(msg.sender, epoch, claimAmount);
        }
        
        if (totalClaim > 0) {
            uint256 available = distributionToken.balanceOf(address(this));
            if (available < totalClaim) revert InsufficientFunds(totalClaim, available);
            
            userClaims[msg.sender].totalClaimed += totalClaim;
            require(distributionToken.transfer(msg.sender, totalClaim), "Transfer failed");
        }
    }
    
    /**
     * @notice Calculate claimable amount for user in specific epoch
     * @param epoch Epoch to calculate for
     * @param user User address
     * @return claimAmount Amount user can claim
     */
    function getClaimableAmount(uint256 epoch, address user) external view returns (uint256 claimAmount) {
        if (!_isEligible(user)) return 0;
        if (!epochs[epoch].finalized) return 0;
        if (epochClaimed[epoch][user]) return 0;
        
        uint256 userBalance = core.balanceOf(user);
        return _calculateClaim(epoch, userBalance);
    }
    
    /**
     * @notice Get total claimable amount across all epochs
     * @param user User address
     * @return totalClaimable Total amount user can claim
     */
    function getTotalClaimable(address user) external view returns (uint256 totalClaimable) {
        if (!_isEligible(user)) return 0;
        
        uint256 userBalance = core.balanceOf(user);
        
        for (uint256 epoch = 1; epoch <= currentEpoch; epoch++) {
            if (!epochs[epoch].finalized) continue;
            if (epochClaimed[epoch][user]) continue;
            
            totalClaimable += _calculateClaim(epoch, userBalance);
        }
    }
    
    function _calculateClaim(uint256 epoch, uint256 userBalance) internal view returns (uint256) {
        EpochData memory epochData = epochs[epoch];
        if (epochData.eligibleSupply == 0) return 0;
        
        // Base calculation: userBalance * rateBps / 10000
        // This represents the percentage yield on their token holdings
        uint256 baseAmount = (userBalance * epochData.rateBps) / 10000;
        
        // For FTH-G, we assume 1 token = $20k entry, so yield is percentage of entry value
        // This would need to be adjusted based on actual tokenomics
        return baseAmount;
    }
    
    function _isEligible(address user) internal view returns (bool) {
        return core.isEligible(user) && !core.isInCliff(user) && core.balanceOf(user) > 0;
    }
    
    /**
     * @notice Finalize an epoch (admin function)
     * @param epoch Epoch to finalize
     */
    function finalizeEpoch(uint256 epoch) external onlyOwner {
        _finalizeEpoch(epoch);
    }
    
    function _finalizeEpoch(uint256 epoch) internal {
        EpochData storage epochData = epochs[epoch];
        require(!epochData.finalized, "Already finalized");
        
        // Calculate eligible supply by reading from core
        epochData.eligibleSupply = core.totalSupply(); // Simplified - could be more sophisticated
        epochData.finalized = true;
        
        emit EpochFinalized(epoch, epochData.totalDistributed, epochData.eligibleSupply);
    }
    
    /**
     * @notice Update default distribution rate
     * @param newRateBps New rate in basis points
     */
    function updateDefaultRate(uint256 newRateBps) external onlyOwner {
        require(newRateBps >= minRateBps && newRateBps <= maxRateBps, "Rate out of bounds");
        
        uint256 oldRate = defaultRateBps;
        defaultRateBps = newRateBps;
        
        emit RateUpdated(oldRate, newRateBps);
    }
    
    /**
     * @notice Update rate bounds
     * @param _minRateBps Minimum rate in basis points
     * @param _maxRateBps Maximum rate in basis points
     */
    function updateRateBounds(uint256 _minRateBps, uint256 _maxRateBps) external onlyOwner {
        require(_minRateBps < _maxRateBps, "Invalid bounds");
        require(_maxRateBps <= 5000, "Max rate too high"); // 50% cap
        
        minRateBps = _minRateBps;
        maxRateBps = _maxRateBps;
    }
    
    /**
     * @notice Emergency pause distributions
     * @param paused True to pause, false to unpause
     */
    function setDistributionsPaused(bool paused) external onlyAuthorized {
        distributionsPaused = paused;
        emit EmergencyPause(paused);
    }
    
    /**
     * @notice Withdraw tokens from contract (emergency or maintenance)
     * @param token Token address to withdraw
     * @param amount Amount to withdraw
     * @param to Recipient address
     */
    function withdrawFunds(address token, uint256 amount, address to) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        
        IERC20(token).transfer(to, amount);
        emit FundsWithdrawn(token, amount, to);
    }
    
    /**
     * @notice Get current epoch information
     * @return epoch Current epoch number
     * @return startTime Epoch start time
     * @return endTime Epoch end time
     * @return rateBps Current distribution rate
     */
    function getCurrentEpochInfo() external view returns (
        uint256 epoch,
        uint256 startTime,
        uint256 endTime,
        uint256 rateBps
    ) {
        EpochData memory current = epochs[currentEpoch];
        return (currentEpoch, current.startTime, current.endTime, current.rateBps);
    }
    
    /**
     * @notice Get user claim history
     * @param user User address
     * @return lastClaimedEpoch Last epoch user claimed
     * @return totalClaimed Total amount claimed by user
     */
    function getUserClaimHistory(address user) external view returns (
        uint256 lastClaimedEpoch,
        uint256 totalClaimed
    ) {
        UserClaim memory claim = userClaims[user];
        return (claim.lastClaimedEpoch, claim.totalClaimed);
    }
}