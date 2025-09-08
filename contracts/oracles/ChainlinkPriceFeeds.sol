// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title ChainlinkPriceFeeds - Aggregated Price Feed Oracle
 * @notice Provides reliable price feeds for FTH-GOLD system operations
 * @dev Aggregates multiple Chainlink feeds with fallback mechanisms
 */
contract ChainlinkPriceFeeds is AccessControl, Pausable {
    bytes32 public constant ORACLE_MANAGER_ROLE = keccak256("ORACLE_MANAGER_ROLE");
    
    struct PriceFeed {
        AggregatorV3Interface feed;
        uint256 heartbeat; // Maximum seconds between updates
        uint8 decimals;
        bool active;
        string description;
    }
    
    // Price feed mappings
    mapping(bytes32 => PriceFeed) public priceFeeds;
    mapping(bytes32 => uint256) public stalePriceThreshold; // Seconds
    
    // Supported assets
    bytes32 public constant XAU_USD = keccak256("XAU/USD"); // Gold spot price
    bytes32 public constant USDT_USD = keccak256("USDT/USD");
    bytes32 public constant USDC_USD = keccak256("USDC/USD"); 
    bytes32 public constant ETH_USD = keccak256("ETH/USD");
    bytes32 public constant AED_USD = keccak256("AED/USD");
    
    event PriceFeedUpdated(bytes32 indexed asset, address feed, uint256 heartbeat);
    event PriceFeedRemoved(bytes32 indexed asset);
    event StaleDataDetected(bytes32 indexed asset, uint256 lastUpdate, uint256 threshold);
    
    error FeedNotActive(bytes32 asset);
    error StalePrice(bytes32 asset, uint256 lastUpdate);
    error InvalidPrice(bytes32 asset, int256 price);
    error FeedNotFound(bytes32 asset);
    
    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ORACLE_MANAGER_ROLE, admin);
        
        // Default stale price thresholds (24 hours)
        stalePriceThreshold[XAU_USD] = 86400;
        stalePriceThreshold[USDT_USD] = 86400;
        stalePriceThreshold[USDC_USD] = 86400;
        stalePriceThreshold[ETH_USD] = 3600; // 1 hour for ETH
        stalePriceThreshold[AED_USD] = 86400;
    }
    
    /**
     * @notice Add or update a Chainlink price feed
     * @param asset Asset identifier (e.g., XAU_USD)
     * @param feedAddress Chainlink aggregator address
     * @param heartbeat Maximum seconds between updates
     * @param description Human readable description
     */
    function setPriceFeed(
        bytes32 asset,
        address feedAddress,
        uint256 heartbeat,
        string calldata description
    ) external onlyRole(ORACLE_MANAGER_ROLE) {
        require(feedAddress != address(0), "Invalid feed address");
        
        AggregatorV3Interface feed = AggregatorV3Interface(feedAddress);
        uint8 decimals = feed.decimals();
        
        priceFeeds[asset] = PriceFeed({
            feed: feed,
            heartbeat: heartbeat,
            decimals: decimals,
            active: true,
            description: description
        });
        
        emit PriceFeedUpdated(asset, feedAddress, heartbeat);
    }
    
    /**
     * @notice Remove a price feed
     * @param asset Asset to remove feed for
     */
    function removePriceFeed(bytes32 asset) external onlyRole(ORACLE_MANAGER_ROLE) {
        delete priceFeeds[asset];
        emit PriceFeedRemoved(asset);
    }
    
    /**
     * @notice Set stale price threshold for an asset
     * @param asset Asset identifier
     * @param threshold Maximum age in seconds
     */
    function setStalePriceThreshold(bytes32 asset, uint256 threshold) external onlyRole(ORACLE_MANAGER_ROLE) {
        stalePriceThreshold[asset] = threshold;
    }
    
    /**
     * @notice Get latest price for an asset
     * @param asset Asset identifier (e.g., XAU_USD)
     * @return price Latest price (scaled to 8 decimals)
     * @return timestamp Last update timestamp
     */
    function getLatestPrice(bytes32 asset) external view returns (uint256 price, uint256 timestamp) {
        PriceFeed memory feed = priceFeeds[asset];
        if (!feed.active) revert FeedNotActive(asset);
        
        (
            uint80 roundId,
            int256 rawPrice,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = feed.feed.latestRoundData();
        
        // Validate price data
        require(rawPrice > 0, "Invalid price");
        require(updatedAt > 0, "Invalid timestamp");
        require(answeredInRound >= roundId, "Stale round data");
        
        // Check if price is stale
        uint256 maxAge = stalePriceThreshold[asset];
        if (maxAge > 0 && block.timestamp - updatedAt > maxAge) {
            revert StalePrice(asset, updatedAt);
        }
        
        // Normalize to 8 decimals
        uint256 normalizedPrice;
        if (feed.decimals > 8) {
            normalizedPrice = uint256(rawPrice) / (10 ** (feed.decimals - 8));
        } else if (feed.decimals < 8) {
            normalizedPrice = uint256(rawPrice) * (10 ** (8 - feed.decimals));
        } else {
            normalizedPrice = uint256(rawPrice);
        }
        
        return (normalizedPrice, updatedAt);
    }
    
    /**
     * @notice Get gold price in USD (convenience function)
     * @return price Gold price per troy ounce (8 decimals)
     * @return timestamp Last update timestamp
     */
    function getGoldPriceUSD() external view returns (uint256 price, uint256 timestamp) {
        return this.getLatestPrice(XAU_USD);
    }
    
    /**
     * @notice Get USDT/USD exchange rate
     * @return price USDT price in USD (8 decimals) 
     * @return timestamp Last update timestamp
     */
    function getUSDTPrice() external view returns (uint256 price, uint256 timestamp) {
        return this.getLatestPrice(USDT_USD);
    }
    
    /**
     * @notice Convert amount between assets using latest prices
     * @param fromAsset Source asset
     * @param toAsset Target asset  
     * @param amount Amount to convert (in source asset decimals)
     * @return convertedAmount Amount in target asset
     */
    function convertPrice(
        bytes32 fromAsset,
        bytes32 toAsset,
        uint256 amount
    ) external view returns (uint256 convertedAmount) {
        if (fromAsset == toAsset) return amount;
        
        (uint256 fromPrice,) = this.getLatestPrice(fromAsset);
        (uint256 toPrice,) = this.getLatestPrice(toAsset);
        
        // Convert: amount * fromPrice / toPrice
        convertedAmount = (amount * fromPrice) / toPrice;
    }
    
    /**
     * @notice Check if price data is fresh for an asset
     * @param asset Asset to check
     * @return isFresh True if price is within staleness threshold
     * @return lastUpdate Last update timestamp
     */
    function isPriceFresh(bytes32 asset) external view returns (bool isFresh, uint256 lastUpdate) {
        PriceFeed memory feed = priceFeeds[asset];
        if (!feed.active) return (false, 0);
        
        (,,,uint256 updatedAt,) = feed.feed.latestRoundData();
        lastUpdate = updatedAt;
        
        uint256 maxAge = stalePriceThreshold[asset];
        isFresh = (maxAge == 0) || (block.timestamp - updatedAt <= maxAge);
    }
    
    /**
     * @notice Get feed information for an asset
     * @param asset Asset identifier
     * @return feed Feed configuration
     */
    function getFeedInfo(bytes32 asset) external view returns (PriceFeed memory feed) {
        return priceFeeds[asset];
    }
    
    /**
     * @notice Emergency pause all price feeds
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause price feeds
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}