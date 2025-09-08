// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title FTHGPriceFeedConsumer - Chainlink Price Feed Integration
 * @notice Non-breaking add-on for reading precious metals and crypto prices
 * @dev Provides price data for FTH-G system without modifying core contracts
 */
contract FTHGPriceFeedConsumer is Ownable {
    
    struct PriceFeed {
        AggregatorV3Interface aggregator;
        uint256 heartbeat;     // Maximum staleness in seconds
        uint8 decimals;
        bool active;
        string description;
    }
    
    // Price feeds by asset
    mapping(bytes32 => PriceFeed) public priceFeeds;
    
    // Asset identifiers
    bytes32 public constant ETH_USD = keccak256("ETH/USD");
    bytes32 public constant XAU_USD = keccak256("XAU/USD"); // Gold per troy ounce
    bytes32 public constant USDT_USD = keccak256("USDT/USD");
    bytes32 public constant USDC_USD = keccak256("USDC/USD");
    
    event PriceFeedUpdated(bytes32 indexed asset, address aggregator, uint256 heartbeat);
    event PriceQueried(bytes32 indexed asset, int256 price, uint256 timestamp);
    
    error StalePriceFeed(bytes32 asset, uint256 lastUpdate, uint256 maxAge);
    error InvalidPrice(bytes32 asset, int256 price);
    error FeedNotFound(bytes32 asset);
    
    constructor(address owner) Ownable(owner) {}
    
    /**
     * @notice Set price feed for an asset
     * @param asset Asset identifier (e.g., ETH_USD)
     * @param aggregator Chainlink aggregator address
     * @param heartbeat Maximum staleness in seconds
     * @param description Human-readable description
     */
    function setPriceFeed(
        bytes32 asset,
        address aggregator,
        uint256 heartbeat,
        string calldata description
    ) external onlyOwner {
        require(aggregator != address(0), "Invalid aggregator");
        
        AggregatorV3Interface feed = AggregatorV3Interface(aggregator);
        uint8 decimals = feed.decimals();
        
        priceFeeds[asset] = PriceFeed({
            aggregator: feed,
            heartbeat: heartbeat,
            decimals: decimals,
            active: true,
            description: description
        });
        
        emit PriceFeedUpdated(asset, aggregator, heartbeat);
    }
    
    /**
     * @notice Get latest price for an asset
     * @param asset Asset identifier
     * @return price Latest price (in feed's native decimals)
     * @return timestamp Last update timestamp
     * @return decimals Price decimals
     */
    function getLatestPrice(bytes32 asset) 
        external 
        view 
        returns (int256 price, uint256 timestamp, uint8 decimals) 
    {
        PriceFeed memory feed = priceFeeds[asset];
        if (!feed.active) revert FeedNotFound(asset);
        
        (
            uint80 roundId,
            int256 rawPrice,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = feed.aggregator.latestRoundData();
        
        // Validate price data
        if (rawPrice <= 0) revert InvalidPrice(asset, rawPrice);
        if (updatedAt == 0) revert InvalidPrice(asset, rawPrice);
        if (answeredInRound < roundId) revert InvalidPrice(asset, rawPrice);
        
        // Check staleness
        if (block.timestamp - updatedAt > feed.heartbeat) {
            revert StalePriceFeed(asset, updatedAt, feed.heartbeat);
        }
        
        return (rawPrice, updatedAt, feed.decimals);
    }
    
    /**
     * @notice Get ETH price in USD
     * @return price ETH price in USD (8 decimals typically)
     * @return timestamp Last update timestamp
     */
    function getETHPrice() external view returns (int256 price, uint256 timestamp) {
        (price, timestamp, ) = this.getLatestPrice(ETH_USD);
    }
    
    /**
     * @notice Get gold price in USD per troy ounce
     * @return price Gold price in USD (8 decimals typically)
     * @return timestamp Last update timestamp
     */
    function getGoldPrice() external view returns (int256 price, uint256 timestamp) {
        (price, timestamp, ) = this.getLatestPrice(XAU_USD);
    }
    
    /**
     * @notice Calculate ETH per troy ounce of gold
     * @return ethPerOunce ETH amount per troy ounce (18 decimals)
     */
    function getETHPerGoldOunce() external view returns (uint256 ethPerOunce) {
        (int256 ethPrice, , uint8 ethDecimals) = this.getLatestPrice(ETH_USD);
        (int256 goldPrice, , uint8 goldDecimals) = this.getLatestPrice(XAU_USD);
        
        // Normalize both prices to 18 decimals, then divide
        uint256 normalizedGold = uint256(goldPrice) * (10 ** (18 - goldDecimals));
        uint256 normalizedETH = uint256(ethPrice) * (10 ** (18 - ethDecimals));
        
        // ETH per ounce = (Gold price in USD) / (ETH price in USD)
        ethPerOunce = (normalizedGold * 1e18) / normalizedETH;
    }
    
    /**
     * @notice Convert USD amount to ETH using latest price
     * @param usdAmount USD amount (assumed 6 decimals like USDC)
     * @return ethAmount ETH amount (18 decimals)
     */
    function convertUSDToETH(uint256 usdAmount) external view returns (uint256 ethAmount) {
        (int256 ethPrice, , uint8 decimals) = this.getLatestPrice(ETH_USD);
        
        // Normalize USD amount to 18 decimals
        uint256 normalizedUSD = usdAmount * (10 ** (18 - 6)); // Assume 6 decimals for USD
        
        // Normalize ETH price to 18 decimals
        uint256 normalizedETHPrice = uint256(ethPrice) * (10 ** (18 - decimals));
        
        // ETH amount = USD amount / ETH price
        ethAmount = (normalizedUSD * 1e18) / normalizedETHPrice;
    }
    
    /**
     * @notice Check if price feed is healthy (not stale)
     * @param asset Asset to check
     * @return healthy True if price is fresh
     * @return lastUpdate Last update timestamp
     * @return maxAge Maximum allowed age
     */
    function isPriceFeedHealthy(bytes32 asset) 
        external 
        view 
        returns (bool healthy, uint256 lastUpdate, uint256 maxAge) 
    {
        PriceFeed memory feed = priceFeeds[asset];
        if (!feed.active) return (false, 0, 0);
        
        (, , , uint256 updatedAt, ) = feed.aggregator.latestRoundData();
        lastUpdate = updatedAt;
        maxAge = feed.heartbeat;
        healthy = (block.timestamp - updatedAt) <= feed.heartbeat;
    }
    
    /**
     * @notice Get price feed configuration
     * @param asset Asset identifier
     * @return feed Price feed configuration
     */
    function getPriceFeedConfig(bytes32 asset) external view returns (PriceFeed memory feed) {
        return priceFeeds[asset];
    }
    
    /**
     * @notice Emergency disable a price feed
     * @param asset Asset to disable
     */
    function disablePriceFeed(bytes32 asset) external onlyOwner {
        priceFeeds[asset].active = false;
    }
    
    /**
     * @notice Emergency enable a price feed
     * @param asset Asset to enable
     */
    function enablePriceFeed(bytes32 asset) external onlyOwner {
        require(address(priceFeeds[asset].aggregator) != address(0), "Feed not configured");
        priceFeeds[asset].active = true;
    }
}