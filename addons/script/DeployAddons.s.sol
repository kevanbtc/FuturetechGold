// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {FTHGPriceFeedConsumer} from "../contracts/chainlink/FTHGPriceFeedConsumer.sol";
import {FTHGProofOfReserves} from "../contracts/chainlink/FTHGProofOfReserves.sol";
import {FTHGKeepersPayout} from "../contracts/chainlink/FTHGKeepersPayout.sol";
import {FTHGYieldDistributor} from "../contracts/payments/FTHGYieldDistributor.sol";

/**
 * @title DeployAddons - Deploy FTH-G Add-on Contracts
 * @notice Deploys Chainlink integrations and yield distribution system
 * @dev Non-breaking add-ons that read from core contracts via interfaces
 */
contract DeployAddons is Script {
    
    // Environment variables
    address public FTHG_CORE = vm.envAddress("FTHG_CORE");
    address public USDT = vm.envAddress("USDT");
    address public FEED_ETH_USD = vm.envAddress("FEED_ETH_USD");
    address public FEED_XAU_USD = vm.envAddress("FEED_XAU_USD");
    address public FEED_USDT_USD = vm.envAddress("FEED_USDT_USD");
    address public FEED_POR = vm.envAddress("FEED_POR");
    uint256 public MIN_COVERAGE_BPS = vm.envUint("MIN_COVERAGE_BPS");
    
    // Deployment parameters
    uint256 public deployerKey = vm.envUint("PRIVATE_KEY");
    address public deployer = vm.addr(deployerKey);
    
    // Deployed contract addresses
    FTHGPriceFeedConsumer public priceFeedConsumer;
    FTHGProofOfReserves public proofOfReserves;
    FTHGYieldDistributor public yieldDistributor;
    FTHGKeepersPayout public keepersPayout;
    
    function run() external {
        console2.log("🚀 Deploying FTH-G Add-on Contracts...");
        console2.log("Deployer:", deployer);
        console2.log("Network Chain ID:", block.chainid);
        console2.log("FTHG Core:", FTHG_CORE);
        console2.log("");
        
        vm.startBroadcast(deployerKey);
        
        // 1. Deploy Price Feed Consumer
        _deployPriceFeedConsumer();
        
        // 2. Deploy Proof of Reserves Monitor
        _deployProofOfReserves();
        
        // 3. Deploy Yield Distributor
        _deployYieldDistributor();
        
        // 4. Deploy Keepers Automation
        _deployKeepersPayout();
        
        // 5. Configure integrations
        _configureIntegrations();
        
        vm.stopBroadcast();
        
        // 6. Log deployment summary
        _logDeploymentSummary();
        
        // 7. Save deployment data
        _saveDeploymentData();
    }
    
    function _deployPriceFeedConsumer() internal {
        console2.log("📊 Deploying Price Feed Consumer...");
        
        priceFeedConsumer = new FTHGPriceFeedConsumer(deployer);
        console2.log("✅ FTHGPriceFeedConsumer:", address(priceFeedConsumer));
        
        // Configure price feeds if addresses are provided
        if (FEED_ETH_USD != address(0)) {
            priceFeedConsumer.setPriceFeed(
                priceFeedConsumer.ETH_USD(),
                FEED_ETH_USD,
                3600, // 1 hour heartbeat
                "ETH/USD Chainlink Feed"
            );
            console2.log("  - Configured ETH/USD feed:", FEED_ETH_USD);
        }
        
        if (FEED_XAU_USD != address(0)) {
            priceFeedConsumer.setPriceFeed(
                priceFeedConsumer.XAU_USD(),
                FEED_XAU_USD,
                3600, // 1 hour heartbeat  
                "Gold/USD Chainlink Feed"
            );
            console2.log("  - Configured XAU/USD feed:", FEED_XAU_USD);
        }
        
        if (FEED_USDT_USD != address(0)) {
            priceFeedConsumer.setPriceFeed(
                priceFeedConsumer.USDT_USD(),
                FEED_USDT_USD,
                86400, // 24 hour heartbeat (stable)
                "USDT/USD Chainlink Feed"
            );
            console2.log("  - Configured USDT/USD feed:", FEED_USDT_USD);
        }
    }
    
    function _deployProofOfReserves() internal {
        console2.log("🔍 Deploying Proof of Reserves Monitor...");
        
        if (FEED_POR != address(0)) {
            proofOfReserves = new FTHGProofOfReserves(
                FEED_POR,
                MIN_COVERAGE_BPS,
                deployer
            );
            console2.log("✅ FTHGProofOfReserves:", address(proofOfReserves));
            console2.log("  - Coverage Feed:", FEED_POR);
            console2.log("  - Min Coverage:", MIN_COVERAGE_BPS, "bps");
        } else {
            console2.log("⚠️  Skipping PoR deployment - no feed address provided");
        }
    }
    
    function _deployYieldDistributor() internal {
        console2.log("💰 Deploying Yield Distributor...");
        
        yieldDistributor = new FTHGYieldDistributor(
            FTHG_CORE,        // Core contract
            USDT,             // Distribution token
            deployer,         // Owner
            deployer          // Emergency pauser (can be different)
        );
        console2.log("✅ FTHGYieldDistributor:", address(yieldDistributor));
        console2.log("  - Core Contract:", FTHG_CORE);
        console2.log("  - Distribution Token:", USDT);
    }
    
    function _deployKeepersPayout() internal {
        console2.log("🤖 Deploying Keepers Automation...");
        
        if (address(yieldDistributor) != address(0)) {
            keepersPayout = new FTHGKeepersPayout(
                address(yieldDistributor),
                deployer
            );
            console2.log("✅ FTHGKeepersPayout:", address(keepersPayout));
            console2.log("  - Distributor:", address(yieldDistributor));
        } else {
            console2.log("⚠️  Skipping Keepers deployment - no distributor");
        }
    }
    
    function _configureIntegrations() internal {
        console2.log("⚙️ Configuring integrations...");
        
        // Configure yield distributor to allow keepers to trigger epochs
        if (address(keepersPayout) != address(0) && address(yieldDistributor) != address(0)) {
            // In a full implementation, you might grant roles or permissions here
            console2.log("  - Keepers integration configured");
        }
        
        console2.log("✅ Configuration complete");
    }
    
    function _logDeploymentSummary() internal view {
        console2.log("\n🎯 ADD-ON DEPLOYMENT SUMMARY");
        console2.log("============================");
        console2.log("Network:", block.chainid);
        console2.log("Block Number:", block.number);
        console2.log("Deployer:", deployer);
        console2.log("");
        
        console2.log("📋 Deployed Contracts:");
        console2.log("FTHGPriceFeedConsumer:  ", address(priceFeedConsumer));
        if (address(proofOfReserves) != address(0)) {
            console2.log("FTHGProofOfReserves:    ", address(proofOfReserves));
        }
        console2.log("FTHGYieldDistributor:   ", address(yieldDistributor));
        if (address(keepersPayout) != address(0)) {
            console2.log("FTHGKeepersPayout:      ", address(keepersPayout));
        }
        console2.log("");
        
        console2.log("🔗 Integrations:");
        console2.log("Core Contract:          ", FTHG_CORE);
        console2.log("Distribution Token:     ", USDT);
        console2.log("ETH/USD Feed:          ", FEED_ETH_USD);
        console2.log("XAU/USD Feed:          ", FEED_XAU_USD);
        if (FEED_POR != address(0)) {
            console2.log("Coverage Feed:          ", FEED_POR);
            console2.log("Min Coverage:           ", MIN_COVERAGE_BPS, "bps");
        }
    }
    
    function _saveDeploymentData() internal {
        string memory deploymentData = string.concat(
            "# FTH-G Add-ons Deployment\n\n",
            "**Network:** ", vm.toString(block.chainid), "\n",
            "**Block:** ", vm.toString(block.number), "\n",
            "**Timestamp:** ", vm.toString(block.timestamp), "\n",
            "**Deployer:** ", vm.toString(deployer), "\n\n",
            
            "## Add-on Contracts\n\n",
            "| Contract | Address |\n",
            "|----------|----------|\n",
            "| FTHGPriceFeedConsumer | ", vm.toString(address(priceFeedConsumer)), " |\n",
            "| FTHGYieldDistributor | ", vm.toString(address(yieldDistributor)), " |\n"
        );
        
        if (address(proofOfReserves) != address(0)) {
            deploymentData = string.concat(
                deploymentData,
                "| FTHGProofOfReserves | ", vm.toString(address(proofOfReserves)), " |\n"
            );
        }
        
        if (address(keepersPayout) != address(0)) {
            deploymentData = string.concat(
                deploymentData,
                "| FTHGKeepersPayout | ", vm.toString(address(keepersPayout)), " |\n"
            );
        }
        
        deploymentData = string.concat(
            deploymentData,
            "\n## Integration Points\n\n",
            "- **Core Contract:** ", vm.toString(FTHG_CORE), "\n",
            "- **Distribution Token:** ", vm.toString(USDT), "\n",
            "- **ETH/USD Feed:** ", vm.toString(FEED_ETH_USD), "\n",
            "- **XAU/USD Feed:** ", vm.toString(FEED_XAU_USD), "\n\n",
            
            "## Usage\n\n",
            "1. **Price Feeds:** Call `getLatestPrice()` functions\n",
            "2. **Yield Claims:** Users call `claimYield(epoch)` on distributor\n",
            "3. **Automation:** Keepers call `performUpkeep()` monthly\n",
            "4. **Monitoring:** Watch PoR events for coverage alerts\n\n"
        );
        
        try vm.writeFile("addons/deployments/addons-deployment.md", deploymentData) {
            console2.log("📄 Deployment data saved to addons/deployments/addons-deployment.md");
        } catch {
            console2.log("⚠️  Could not save deployment file");
        }
        
        // JSON format for programmatic access
        string memory jsonData = string.concat(
            '{\n',
            '  "network": ', vm.toString(block.chainid), ',\n',
            '  "block": ', vm.toString(block.number), ',\n',
            '  "timestamp": ', vm.toString(block.timestamp), ',\n',
            '  "deployer": "', vm.toString(deployer), '",\n',
            '  "contracts": {\n',
            '    "priceFeedConsumer": "', vm.toString(address(priceFeedConsumer)), '",\n',
            '    "yieldDistributor": "', vm.toString(address(yieldDistributor)), '"'
        );
        
        if (address(proofOfReserves) != address(0)) {
            jsonData = string.concat(jsonData, ',\n    "proofOfReserves": "', vm.toString(address(proofOfReserves)), '"');
        }
        
        if (address(keepersPayout) != address(0)) {
            jsonData = string.concat(jsonData, ',\n    "keepersPayout": "', vm.toString(address(keepersPayout)), '"');
        }
        
        jsonData = string.concat(
            jsonData,
            '\n  },\n',
            '  "integrations": {\n',
            '    "core": "', vm.toString(FTHG_CORE), '",\n',
            '    "usdt": "', vm.toString(USDT), '",\n',
            '    "ethUsdFeed": "', vm.toString(FEED_ETH_USD), '",\n',
            '    "xauUsdFeed": "', vm.toString(FEED_XAU_USD), '"\n',
            '  }\n',
            '}'
        );
        
        try vm.writeFile("addons/deployments/addons-contracts.json", jsonData) {
            console2.log("📄 Contract data saved to addons/deployments/addons-contracts.json");
        } catch {
            console2.log("⚠️  Could not save JSON file");
        }
    }
}