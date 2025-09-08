// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../payments/FTHGYieldDistributor.sol";

/**
 * @title FTHGKeepersPayout - Chainlink Automation for Monthly Payouts
 * @notice Automated monthly epoch management using Chainlink Keepers
 * @dev Triggers new payout epochs on a monthly schedule
 */
contract FTHGKeepersPayout is Ownable {
    
    FTHGYieldDistributor public immutable distributor;
    
    // Timing configuration
    uint256 public epoch;
    uint256 public nextTriggerTime;
    uint256 public constant EPOCH_DURATION = 30 days;
    uint256 public constant TRIGGER_WINDOW = 1 hours; // Window for triggering
    
    // Rate configuration
    uint256 public defaultRateBps = 1000;  // 10% default rate
    uint256 public lastUsedRate;
    
    // Automation controls
    bool public automationEnabled = true;
    uint256 public lastUpkeepTime;
    uint256 public totalUpkeepsPerformed;
    
    // Events
    event EpochTriggered(
        uint256 indexed epoch,
        uint256 rateBps,
        uint256 timestamp,
        address triggeredBy
    );
    event AutomationConfigured(bool enabled, uint256 defaultRate);
    event NextTriggerScheduled(uint256 nextTime);
    event UpkeepPerformed(uint256 timestamp, uint256 gasUsed);
    
    // Errors
    error AutomationDisabled();
    error TriggerWindowMissed(uint256 current, uint256 window);
    error UpkeepNotNeeded(uint256 nextTrigger, uint256 currentTime);
    error InvalidRate(uint256 rate);
    error DistributorError(string reason);
    
    constructor(
        address _distributor,
        address _owner
    ) Ownable(_owner) {
        require(_distributor != address(0), "Invalid distributor");
        
        distributor = FTHGYieldDistributor(_distributor);
        
        // Schedule first trigger 30 days from deployment
        nextTriggerTime = block.timestamp + EPOCH_DURATION;
        epoch = 0;
        lastUsedRate = defaultRateBps;
        
        emit NextTriggerScheduled(nextTriggerTime);
    }
    
    /**
     * @notice Check if upkeep is needed (Chainlink Keepers compatible)
     * @return upkeepNeeded True if performUpkeep should be called
     * @return performData Encoded data for performUpkeep
     */
    function checkUpkeep(bytes calldata) external view returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = _shouldTrigger();
        performData = abi.encode(defaultRateBps);
    }
    
    /**
     * @notice Perform upkeep (Chainlink Keepers compatible)
     * @param performData Encoded data from checkUpkeep
     */
    function performUpkeep(bytes calldata performData) external {
        if (!_shouldTrigger()) revert UpkeepNotNeeded(nextTriggerTime, block.timestamp);
        if (!automationEnabled) revert AutomationDisabled();
        
        uint256 gasStart = gasleft();
        
        // Decode rate from performData
        uint256 rateBps = abi.decode(performData, (uint256));
        
        // Validate rate
        if (rateBps == 0) {
            rateBps = defaultRateBps; // Fallback to default
        }
        
        _triggerNewEpoch(rateBps);
        
        // Update metrics
        lastUpkeepTime = block.timestamp;
        totalUpkeepsPerformed++;
        
        uint256 gasUsed = gasStart - gasleft();
        emit UpkeepPerformed(block.timestamp, gasUsed);
    }
    
    /**
     * @notice Manually trigger a new epoch (owner only)
     * @param rateBps Distribution rate in basis points
     */
    function manualTrigger(uint256 rateBps) external onlyOwner {
        if (rateBps < 500 || rateBps > 1500) revert InvalidRate(rateBps); // 5-15% range
        
        _triggerNewEpoch(rateBps);
    }
    
    /**
     * @notice Emergency trigger with default rate
     */
    function emergencyTrigger() external onlyOwner {
        _triggerNewEpoch(defaultRateBps);
    }
    
    function _triggerNewEpoch(uint256 rateBps) internal {
        epoch++;
        lastUsedRate = rateBps;
        
        // Call distributor to start new epoch
        try distributor.startNewEpoch(rateBps) {
            // Success - schedule next trigger
            nextTriggerTime = block.timestamp + EPOCH_DURATION;
            
            emit EpochTriggered(epoch, rateBps, block.timestamp, msg.sender);
            emit NextTriggerScheduled(nextTriggerTime);
            
        } catch Error(string memory reason) {
            revert DistributorError(reason);
        } catch (bytes memory) {
            revert DistributorError("Unknown distributor error");
        }
    }
    
    function _shouldTrigger() internal view returns (bool) {
        if (!automationEnabled) return false;
        
        // Check if we're in the trigger window
        uint256 currentTime = block.timestamp;
        
        // Can trigger if current time is past trigger time and within window
        return currentTime >= nextTriggerTime && 
               currentTime <= nextTriggerTime + TRIGGER_WINDOW;
    }
    
    /**
     * @notice Set default payout rate
     * @param newRateBps New default rate in basis points
     */
    function setDefaultRate(uint256 newRateBps) external onlyOwner {
        if (newRateBps < 500 || newRateBps > 1500) revert InvalidRate(newRateBps);
        
        defaultRateBps = newRateBps;
        emit AutomationConfigured(automationEnabled, newRateBps);
    }
    
    /**
     * @notice Enable or disable automation
     * @param enabled True to enable automation
     */
    function setAutomationEnabled(bool enabled) external onlyOwner {
        automationEnabled = enabled;
        emit AutomationConfigured(enabled, defaultRateBps);
    }
    
    /**
     * @notice Manually set next trigger time (emergency use)
     * @param newTriggerTime New trigger timestamp
     */
    function setNextTriggerTime(uint256 newTriggerTime) external onlyOwner {
        require(newTriggerTime > block.timestamp, "Trigger time must be future");
        require(newTriggerTime <= block.timestamp + 60 days, "Trigger time too far");
        
        nextTriggerTime = newTriggerTime;
        emit NextTriggerScheduled(newTriggerTime);
    }
    
    /**
     * @notice Get automation status and timing
     * @return enabled Whether automation is enabled
     * @return nextTrigger Next trigger timestamp
     * @return timeUntilNext Seconds until next trigger
     * @return canTrigger Whether trigger window is active
     */
    function getAutomationStatus() external view returns (
        bool enabled,
        uint256 nextTrigger,
        uint256 timeUntilNext,
        bool canTrigger
    ) {
        enabled = automationEnabled;
        nextTrigger = nextTriggerTime;
        
        if (block.timestamp >= nextTriggerTime) {
            timeUntilNext = 0;
        } else {
            timeUntilNext = nextTriggerTime - block.timestamp;
        }
        
        canTrigger = _shouldTrigger();
    }
    
    /**
     * @notice Get epoch and performance metrics
     * @return currentEpoch Current epoch number
     * @return lastRate Last used payout rate
     * @return totalUpkeeps Total upkeeps performed
     * @return lastUpkeep Timestamp of last upkeep
     */
    function getMetrics() external view returns (
        uint256 currentEpoch,
        uint256 lastRate,
        uint256 totalUpkeeps,
        uint256 lastUpkeep
    ) {
        return (
            epoch,
            lastUsedRate,
            totalUpkeepsPerformed,
            lastUpkeepTime
        );
    }
    
    /**
     * @notice Calculate time remaining until next trigger window
     * @return timeRemaining Seconds until trigger window opens
     * @return windowEnd Timestamp when trigger window closes
     */
    function getTimeToNext() external view returns (uint256 timeRemaining, uint256 windowEnd) {
        uint256 currentTime = block.timestamp;
        
        if (currentTime >= nextTriggerTime) {
            timeRemaining = 0;
        } else {
            timeRemaining = nextTriggerTime - currentTime;
        }
        
        windowEnd = nextTriggerTime + TRIGGER_WINDOW;
    }
    
    /**
     * @notice Check if we're currently in a trigger window
     * @return inWindow True if currently in trigger window
     * @return windowStart Start of current trigger window
     * @return windowEnd End of current trigger window
     */
    function getCurrentWindow() external view returns (
        bool inWindow,
        uint256 windowStart,
        uint256 windowEnd
    ) {
        windowStart = nextTriggerTime;
        windowEnd = nextTriggerTime + TRIGGER_WINDOW;
        inWindow = block.timestamp >= windowStart && block.timestamp <= windowEnd;
    }
    
    /**
     * @notice Emergency reset of automation state
     * @dev Only for emergency use - resets all timing
     */
    function emergencyReset() external onlyOwner {
        nextTriggerTime = block.timestamp + EPOCH_DURATION;
        epoch = 0;
        totalUpkeepsPerformed = 0;
        lastUpkeepTime = 0;
        
        emit NextTriggerScheduled(nextTriggerTime);
    }
    
    /**
     * @notice Get configuration summary
     * @return distributorAddress Address of yield distributor
     * @return epochDuration Duration between epochs in seconds
     * @return triggerWindow Window for triggering in seconds
     * @return currentDefaultRate Current default rate in bps
     */
    function getConfiguration() external view returns (
        address distributorAddress,
        uint256 epochDuration,
        uint256 triggerWindow,
        uint256 currentDefaultRate
    ) {
        return (
            address(distributor),
            EPOCH_DURATION,
            TRIGGER_WINDOW,
            defaultRateBps
        );
    }
}