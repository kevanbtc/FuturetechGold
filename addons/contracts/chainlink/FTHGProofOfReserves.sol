// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title FTHGProofOfReserves - Coverage Monitoring System
 * @notice Non-breaking add-on for monitoring gold reserve coverage
 * @dev Listens to PoR feeds and emits status events for external monitoring
 */
contract FTHGProofOfReserves is Ownable {
    
    AggregatorV3Interface public coverageFeed;
    uint256 public minCoverageBps;      // Minimum coverage in basis points (10000 = 100%)
    uint256 public maxFeedAge;          // Maximum feed age in seconds
    
    // Status tracking
    bool public lastStatusHealthy;
    uint256 public lastUpdateTime;
    uint256 public consecutiveUnhealthyChecks;
    uint256 public constant MAX_CONSECUTIVE_UNHEALTHY = 3;
    
    // Events
    event ProgramStatus(bool healthy, uint256 coverageBps, uint256 timestamp);
    event CoverageThresholdBreached(uint256 coverageBps, uint256 threshold, uint256 timestamp);
    event FeedStale(uint256 lastUpdate, uint256 maxAge, uint256 timestamp);
    event ConfigurationUpdated(string parameter, uint256 oldValue, uint256 newValue);
    
    // Errors
    error FeedNotConfigured();
    error InvalidCoverageFeed();
    error InvalidConfiguration();
    error StaleFeed(uint256 lastUpdate, uint256 maxAge);
    error UnhealthyCoverage(uint256 coverage, uint256 required);
    
    constructor(
        address _coverageFeed,
        uint256 _minCoverageBps,
        address _owner
    ) Ownable(_owner) {
        require(_coverageFeed != address(0), "Invalid feed address");
        require(_minCoverageBps >= 5000 && _minCoverageBps <= 50000, "Invalid coverage range"); // 50% - 500%
        
        coverageFeed = AggregatorV3Interface(_coverageFeed);
        minCoverageBps = _minCoverageBps;
        maxFeedAge = 3 hours; // Default 3 hour staleness threshold
        
        // Verify feed is working
        try coverageFeed.latestRoundData() returns (uint80, int256 answer, uint256, uint256, uint80) {
            require(answer > 0, "Invalid feed response");
        } catch {
            revert InvalidCoverageFeed();
        }
    }
    
    /**
     * @notice Check current coverage status
     * @return healthy True if coverage is above threshold and feed is fresh
     * @return coverageBps Current coverage in basis points
     * @return lastUpdate Timestamp of last feed update
     */
    function check() public view returns (bool healthy, uint256 coverageBps, uint256 lastUpdate) {
        if (address(coverageFeed) == address(0)) revert FeedNotConfigured();
        
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = coverageFeed.latestRoundData();
        
        // Validate feed response
        require(answer > 0, "Invalid coverage value");
        require(updatedAt > 0, "Invalid timestamp");
        require(answeredInRound >= roundId, "Stale round data");
        
        coverageBps = uint256(answer);
        lastUpdate = updatedAt;
        
        // Check if feed is stale
        bool feedFresh = block.timestamp - updatedAt <= maxFeedAge;
        
        // Check if coverage is above threshold
        bool coverageHealthy = coverageBps >= minCoverageBps;
        
        healthy = feedFresh && coverageHealthy;
    }
    
    /**
     * @notice Ping the system to check status and emit events
     * @dev Can be called by anyone for monitoring purposes
     */
    function ping() external {
        (bool healthy, uint256 coverageBps, uint256 lastUpdate) = check();
        
        // Update tracking
        lastUpdateTime = block.timestamp;
        
        if (healthy) {
            consecutiveUnhealthyChecks = 0;
        } else {
            consecutiveUnhealthyChecks++;
        }
        
        // Emit status event
        emit ProgramStatus(healthy, coverageBps, block.timestamp);
        
        // Emit specific alerts
        if (!healthy) {
            if (block.timestamp - lastUpdate > maxFeedAge) {
                emit FeedStale(lastUpdate, maxFeedAge, block.timestamp);
            }
            
            if (coverageBps < minCoverageBps) {
                emit CoverageThresholdBreached(coverageBps, minCoverageBps, block.timestamp);
            }
        }
        
        lastStatusHealthy = healthy;
    }
    
    /**
     * @notice Get current coverage percentage (human readable)
     * @return percentage Coverage as percentage (e.g., 105.5 for 105.5%)
     */
    function getCoveragePercentage() external view returns (uint256 percentage) {
        (, uint256 coverageBps, ) = check();
        percentage = coverageBps / 100; // Convert basis points to percentage
    }
    
    /**
     * @notice Check if system has been unhealthy for too long
     * @return criticalStatus True if system needs immediate attention
     * @return consecutiveFailures Number of consecutive unhealthy checks
     */
    function getCriticalStatus() external view returns (bool criticalStatus, uint256 consecutiveFailures) {
        criticalStatus = consecutiveUnhealthyChecks >= MAX_CONSECUTIVE_UNHEALTHY;
        consecutiveFailures = consecutiveUnhealthyChecks;
    }
    
    /**
     * @notice Get feed information
     * @return feedAddress Coverage feed contract address
     * @return minCoverage Minimum required coverage in bps
     * @return maxAge Maximum feed age in seconds
     * @return lastHealth Last known health status
     */
    function getFeedInfo() external view returns (
        address feedAddress,
        uint256 minCoverage,
        uint256 maxAge,
        bool lastHealth
    ) {
        return (
            address(coverageFeed),
            minCoverageBps,
            maxFeedAge,
            lastStatusHealthy
        );
    }
    
    /**
     * @notice Update coverage threshold
     * @param newMinCoverageBps New minimum coverage in basis points
     */
    function updateCoverageThreshold(uint256 newMinCoverageBps) external onlyOwner {
        require(newMinCoverageBps >= 5000 && newMinCoverageBps <= 50000, "Invalid coverage range");
        
        uint256 oldValue = minCoverageBps;
        minCoverageBps = newMinCoverageBps;
        
        emit ConfigurationUpdated("minCoverageBps", oldValue, newMinCoverageBps);
    }
    
    /**
     * @notice Update maximum feed age
     * @param newMaxAge New maximum age in seconds
     */
    function updateMaxFeedAge(uint256 newMaxAge) external onlyOwner {
        require(newMaxAge >= 1 hours && newMaxAge <= 24 hours, "Invalid age range");
        
        uint256 oldValue = maxFeedAge;
        maxFeedAge = newMaxAge;
        
        emit ConfigurationUpdated("maxFeedAge", oldValue, newMaxAge);
    }
    
    /**
     * @notice Update coverage feed address
     * @param newFeedAddress New feed contract address
     */
    function updateCoverageFeed(address newFeedAddress) external onlyOwner {
        require(newFeedAddress != address(0), "Invalid feed address");
        
        // Test the new feed
        AggregatorV3Interface newFeed = AggregatorV3Interface(newFeedAddress);
        try newFeed.latestRoundData() returns (uint80, int256 answer, uint256, uint256, uint80) {
            require(answer > 0, "Invalid feed response");
        } catch {
            revert InvalidCoverageFeed();
        }
        
        address oldFeed = address(coverageFeed);
        coverageFeed = newFeed;
        
        emit ConfigurationUpdated("coverageFeed", uint256(uint160(oldFeed)), uint256(uint160(newFeedAddress)));
    }
    
    /**
     * @notice Automated upkeep check for Chainlink Keepers
     * @return upkeepNeeded True if ping() should be called
     * @return performData Data to pass to performUpkeep (empty)
     */
    function checkUpkeep(bytes calldata) external view returns (bool upkeepNeeded, bytes memory performData) {
        // Check if it's been more than 1 hour since last ping
        upkeepNeeded = block.timestamp - lastUpdateTime >= 1 hours;
        performData = "";
    }
    
    /**
     * @notice Perform automated upkeep (Chainlink Keepers compatible)
     * @param performData Data from checkUpkeep (unused)
     */
    function performUpkeep(bytes calldata performData) external {
        // Verify upkeep is needed (prevent spam)
        require(block.timestamp - lastUpdateTime >= 1 hours, "Upkeep not needed");
        
        ping();
    }
    
    /**
     * @notice Emergency function to manually mark system as unhealthy
     * @dev Only owner can call, for emergency situations
     */
    function emergencyMarkUnhealthy() external onlyOwner {
        lastStatusHealthy = false;
        consecutiveUnhealthyChecks = MAX_CONSECUTIVE_UNHEALTHY;
        
        emit ProgramStatus(false, 0, block.timestamp);
        emit CoverageThresholdBreached(0, minCoverageBps, block.timestamp);
    }
    
    /**
     * @notice Get historical status summary
     * @return lastCheck Timestamp of last check
     * @return wasHealthy Last known health status
     * @return failures Consecutive unhealthy checks
     * @return needsAttention True if system needs attention
     */
    function getStatusSummary() external view returns (
        uint256 lastCheck,
        bool wasHealthy,
        uint256 failures,
        bool needsAttention
    ) {
        return (
            lastUpdateTime,
            lastStatusHealthy,
            consecutiveUnhealthyChecks,
            consecutiveUnhealthyChecks >= MAX_CONSECUTIVE_UNHEALTHY
        );
    }
}