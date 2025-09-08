// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title ReserveOracle - Gold Reserve Coverage Oracle
 * @notice Multi-source oracle for tracking gold reserves vs issued tokens
 * @dev Aggregates data from Chainlink PoR, independent auditors, and manual attestations
 */
contract ReserveOracle is AccessControl, Pausable {
    bytes32 public constant ORACLE_WRITER_ROLE = keccak256("ORACLE_WRITER_ROLE");
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");
    bytes32 public constant CIRCUIT_BREAKER_ROLE = keccak256("CIRCUIT_BREAKER_ROLE");
    
    struct DataSource {
        string name;
        address provider;
        uint256 lastUpdate;
        bool active;
        uint256 weight; // Basis points (10000 = 100%)
    }
    
    struct ReserveData {
        uint256 goldReservesKG; // Gold reserves in kg (18 decimals)
        uint256 tokensIssued;   // Total FTH-G tokens issued (18 decimals)  
        uint256 coverageRatio;  // Coverage ratio in basis points (10000 = 100%)
        uint256 timestamp;
        address source;
    }
    
    // Data sources
    mapping(bytes32 => DataSource) public dataSources;
    mapping(bytes32 => ReserveData) public sourceData;
    bytes32[] public activeSourceIds;
    
    // Aggregated data
    ReserveData public latestData;
    uint256 public minSourcesRequired = 2;
    uint256 public maxDeviationBps = 500; // 5% max deviation from median
    uint256 public coverageFloorBps = 10000; // 100% minimum coverage
    
    // Historical data
    ReserveData[] public historicalData;
    mapping(uint256 => uint256) public dailyCoverage; // timestamp => coverage ratio
    
    event SourceAdded(bytes32 indexed sourceId, string name, address provider, uint256 weight);
    event SourceUpdated(bytes32 indexed sourceId, uint256 goldKG, uint256 tokensIssued, uint256 coverage);
    event CoverageUpdated(uint256 goldKG, uint256 tokensIssued, uint256 coverageRatio, uint256 timestamp);
    event CoverageThresholdBreached(uint256 coverageRatio, uint256 threshold);
    event SourceDeactivated(bytes32 indexed sourceId, string reason);
    
    error InsufficientSources(uint256 available, uint256 required);
    error SourceNotActive(bytes32 sourceId);
    error DataTooOld(bytes32 sourceId, uint256 lastUpdate, uint256 maxAge);
    error ExcessiveDeviation(bytes32 sourceId, uint256 value, uint256 median, uint256 maxDev);
    error CoverageBreached(uint256 coverage, uint256 floor);
    
    constructor(
        address admin,
        address circuitBreaker
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ORACLE_WRITER_ROLE, admin);
        _grantRole(CIRCUIT_BREAKER_ROLE, circuitBreaker);
        
        // Initialize default sources
        _addDataSource("chainlink-por", "Chainlink Proof of Reserves", admin, 4000); // 40%
        _addDataSource("independent-auditor", "Independent Auditor", admin, 4000); // 40%  
        _addDataSource("manual-attestation", "Manual Admin Attestation", admin, 2000); // 20%
    }
    
    /**
     * @notice Add a new data source
     * @param sourceId Unique identifier for the source
     * @param name Human readable name
     * @param provider Address authorized to submit data
     * @param weight Weight in basis points (10000 = 100%)
     */
    function addDataSource(
        bytes32 sourceId,
        string calldata name,
        address provider,
        uint256 weight
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _addDataSource(sourceId, name, provider, weight);
    }
    
    function _addDataSource(
        bytes32 sourceId,
        string memory name,
        address provider,
        uint256 weight
    ) internal {
        require(weight <= 10000, "Weight exceeds 100%");
        require(!dataSources[sourceId].active, "Source already exists");
        
        dataSources[sourceId] = DataSource({
            name: name,
            provider: provider,
            lastUpdate: 0,
            active: true,
            weight: weight
        });
        
        activeSourceIds.push(sourceId);
        _grantRole(ORACLE_WRITER_ROLE, provider);
        
        emit SourceAdded(sourceId, name, provider, weight);
    }
    
    /**
     * @notice Update reserve data from authorized source
     * @param sourceId Source identifier
     * @param goldReservesKG Gold reserves in kg (18 decimals)
     * @param tokensIssued Total tokens issued (18 decimals)
     */
    function updateReserveData(
        bytes32 sourceId,
        uint256 goldReservesKG,
        uint256 tokensIssued
    ) external onlyRole(ORACLE_WRITER_ROLE) whenNotPaused {
        DataSource storage source = dataSources[sourceId];
        require(source.active, "Source not active");
        require(source.provider == msg.sender, "Unauthorized provider");
        
        // Calculate coverage ratio in basis points
        uint256 coverageRatio = tokensIssued == 0 ? 
            type(uint256).max : 
            (goldReservesKG * 10000) / tokensIssued;
        
        // Store source data
        sourceData[sourceId] = ReserveData({
            goldReservesKG: goldReservesKG,
            tokensIssued: tokensIssued,
            coverageRatio: coverageRatio,
            timestamp: block.timestamp,
            source: msg.sender
        });
        
        source.lastUpdate = block.timestamp;
        
        emit SourceUpdated(sourceId, goldReservesKG, tokensIssued, coverageRatio);
        
        // Aggregate data from all sources
        _aggregateData();
    }
    
    /**
     * @notice Aggregate data from all active sources
     */
    function _aggregateData() internal {
        // Collect data from active sources
        ReserveData[] memory sourcesData = new ReserveData[](activeSourceIds.length);
        uint256 validSources = 0;
        uint256 totalWeight = 0;
        
        for (uint256 i = 0; i < activeSourceIds.length; i++) {
            bytes32 sourceId = activeSourceIds[i];
            DataSource memory source = dataSources[sourceId];
            
            if (source.active && sourceData[sourceId].timestamp > 0) {
                // Check data freshness (24 hour max age)
                if (block.timestamp - sourceData[sourceId].timestamp <= 86400) {
                    sourcesData[validSources] = sourceData[sourceId];
                    totalWeight += source.weight;
                    validSources++;
                }
            }
        }
        
        require(validSources >= minSourcesRequired, "Insufficient valid sources");
        
        // Calculate weighted average
        uint256 weightedGoldKG = 0;
        uint256 weightedTokensIssued = 0;
        
        for (uint256 i = 0; i < validSources; i++) {
            bytes32 sourceId = activeSourceIds[i];
            uint256 weight = dataSources[sourceId].weight;
            
            weightedGoldKG += (sourcesData[i].goldReservesKG * weight) / 10000;
            weightedTokensIssued += (sourcesData[i].tokensIssued * weight) / 10000;
        }
        
        // Normalize by total weight
        if (totalWeight != 10000) {
            weightedGoldKG = (weightedGoldKG * 10000) / totalWeight;
            weightedTokensIssued = (weightedTokensIssued * 10000) / totalWeight;
        }
        
        // Calculate final coverage ratio
        uint256 finalCoverage = weightedTokensIssued == 0 ? 
            type(uint256).max : 
            (weightedGoldKG * 10000) / weightedTokensIssued;
        
        // Update latest data
        latestData = ReserveData({
            goldReservesKG: weightedGoldKG,
            tokensIssued: weightedTokensIssued,
            coverageRatio: finalCoverage,
            timestamp: block.timestamp,
            source: address(this)
        });
        
        // Store historical data
        historicalData.push(latestData);
        uint256 dayTimestamp = (block.timestamp / 86400) * 86400;
        dailyCoverage[dayTimestamp] = finalCoverage;
        
        emit CoverageUpdated(weightedGoldKG, weightedTokensIssued, finalCoverage, block.timestamp);
        
        // Check coverage threshold
        if (finalCoverage < coverageFloorBps) {
            emit CoverageThresholdBreached(finalCoverage, coverageFloorBps);
        }
    }
    
    /**
     * @notice Get current coverage ratio in basis points
     * @return coverage Current coverage ratio (10000 = 100%)
     */
    function getCoverageRatio() external view returns (uint256 coverage) {
        return latestData.coverageRatio;
    }
    
    /**
     * @notice Get latest reserve data
     * @return data Latest aggregated reserve data
     */
    function getLatestData() external view returns (ReserveData memory data) {
        return latestData;
    }
    
    /**
     * @notice Check if coverage is above minimum threshold
     * @return isHealthy True if coverage >= floor
     * @return coverage Current coverage ratio
     */
    function isCoverageHealthy() external view returns (bool isHealthy, uint256 coverage) {
        coverage = latestData.coverageRatio;
        isHealthy = coverage >= coverageFloorBps;
    }
    
    /**
     * @notice Get historical coverage data for a date range
     * @param startTimestamp Start date (unix timestamp)
     * @param endTimestamp End date (unix timestamp)  
     * @return timestamps Array of daily timestamps
     * @return coverageRatios Array of coverage ratios
     */
    function getHistoricalCoverage(
        uint256 startTimestamp,
        uint256 endTimestamp
    ) external view returns (uint256[] memory timestamps, uint256[] memory coverageRatios) {
        require(endTimestamp >= startTimestamp, "Invalid date range");
        
        uint256 days = (endTimestamp - startTimestamp) / 86400 + 1;
        timestamps = new uint256[](days);
        coverageRatios = new uint256[](days);
        
        for (uint256 i = 0; i < days; i++) {
            uint256 dayTimestamp = startTimestamp + (i * 86400);
            dayTimestamp = (dayTimestamp / 86400) * 86400; // Normalize to start of day
            
            timestamps[i] = dayTimestamp;
            coverageRatios[i] = dailyCoverage[dayTimestamp];
        }
    }
    
    /**
     * @notice Set minimum coverage threshold
     * @param newFloorBps New floor in basis points
     */
    function setCoverageFloor(uint256 newFloorBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newFloorBps <= 20000, "Floor too high"); // Max 200%
        coverageFloorBps = newFloorBps;
    }
    
    /**
     * @notice Set minimum required sources for aggregation
     * @param newMin New minimum source count
     */
    function setMinSourcesRequired(uint256 newMin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newMin > 0 && newMin <= activeSourceIds.length, "Invalid minimum");
        minSourcesRequired = newMin;
    }
    
    /**
     * @notice Emergency pause oracle updates
     */
    function pause() external onlyRole(CIRCUIT_BREAKER_ROLE) {
        _pause();
    }
    
    /**
     * @notice Resume oracle updates
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @notice Deactivate a data source
     * @param sourceId Source to deactivate
     * @param reason Reason for deactivation
     */
    function deactivateSource(bytes32 sourceId, string calldata reason) external onlyRole(DEFAULT_ADMIN_ROLE) {
        dataSources[sourceId].active = false;
        emit SourceDeactivated(sourceId, reason);
    }
}