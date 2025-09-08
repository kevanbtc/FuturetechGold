// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

// Core contracts
import {FTHG} from "../../contracts/core/FTHG.sol";
import {SubscriptionPool} from "../../contracts/core/SubscriptionPool.sol";

// Compliance contracts
import {IdentitySBT} from "../../contracts/compliance/IdentitySBT.sol";
import {ComplianceRegistry} from "../../contracts/compliance/ComplianceRegistry.sol";

// Oracle contracts
import {ChainlinkPriceFeeds} from "../../contracts/oracles/ChainlinkPriceFeeds.sol";
import {ReserveOracle} from "../../contracts/oracles/ReserveOracle.sol";

// Rail contracts
import {GatewayRouter} from "../../contracts/rails/GatewayRouter.sol";

/**
 * @title DeployExtended - Complete FTH-GOLD System Deployment
 * @notice Deploys all contracts and configures the complete ecosystem
 * @dev Extended deployment with full contract suite and configuration
 */
contract DeployExtended is Script {
    // Environment variables
    uint256 public deployerKey = vm.envUint("PRIVATE_KEY");
    uint256 public adminKey = vm.envUint("ADMIN_PRIVATE_KEY");
    
    address public deployer = vm.addr(deployerKey);
    address public admin = vm.addr(adminKey);
    
    // Configuration
    uint256 public entryPrice = vm.envUint("ENTRY_PRICE_USD");
    uint256 public lockDays = vm.envUint("LOCK_CLIFF_DAYS");
    uint256 public payoutRate = vm.envUint("PAYOUT_RATE_BPS");
    uint256 public coverageFloor = vm.envUint("COVERAGE_FLOOR_BPS");
    
    // External addresses
    address public usdt = vm.envAddress("USDT_SEPOLIA");
    address public kycSigner = vm.envAddress("KYC_SIGNER");
    address public oracleWriter = vm.envAddress("ORACLE_WRITER");
    address public adminMultisig = vm.envAddress("ADMIN_MULTISIG");
    
    // Deployed contracts
    FTHG public fthgToken;
    IdentitySBT public identitySBT;
    ComplianceRegistry public complianceRegistry;
    ChainlinkPriceFeeds public priceFeeds;
    ReserveOracle public reserveOracle;
    GatewayRouter public gatewayRouter;
    SubscriptionPool public subscriptionPool;
    
    function run() external {
        console.log("🚀 Deploying Complete FTH-GOLD System...");
        console.log("Deployer:", deployer);
        console.log("Admin:", admin);
        console.log("Network Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerKey);
        
        // 1. Deploy core FTHG token
        fthgToken = new FTHG(admin, admin);
        console.log("✅ FTHG Token deployed:", address(fthgToken));
        
        // 2. Deploy compliance infrastructure
        identitySBT = new IdentitySBT(admin, kycSigner);
        console.log("✅ IdentitySBT deployed:", address(identitySBT));
        
        complianceRegistry = new ComplianceRegistry(admin);
        console.log("✅ ComplianceRegistry deployed:", address(complianceRegistry));
        
        // 3. Deploy oracle infrastructure
        priceFeeds = new ChainlinkPriceFeeds(admin);
        console.log("✅ ChainlinkPriceFeeds deployed:", address(priceFeeds));
        
        reserveOracle = new ReserveOracle(admin, admin); // admin as circuit breaker for now
        console.log("✅ ReserveOracle deployed:", address(reserveOracle));
        
        // 4. Deploy gateway router for multi-chain deposits
        gatewayRouter = new GatewayRouter(admin, admin); // admin as fee recipient for now
        console.log("✅ GatewayRouter deployed:", address(gatewayRouter));
        
        // 5. Deploy subscription pool (core business logic)
        subscriptionPool = new SubscriptionPool(
            admin,
            address(fthgToken),
            address(identitySBT),
            address(complianceRegistry),
            address(gatewayRouter),
            admin // treasury recipient
        );
        console.log("✅ SubscriptionPool deployed:", address(subscriptionPool));
        
        // 6. Grant necessary roles and permissions
        _configureRoles();
        
        // 7. Configure initial system parameters
        _configureSystem();
        
        vm.stopBroadcast();
        
        // 8. Log deployment summary
        _logDeploymentSummary();
        
        // 9. Save deployment artifacts
        _saveDeploymentData();
    }
    
    function _configureRoles() internal {
        console.log("⚙️ Configuring roles and permissions...");
        
        // Grant SubscriptionPool permission to mint FTHG tokens
        fthgToken.grantRole(fthgToken.MINTER_ROLE(), address(subscriptionPool));
        
        // Grant admin oracle writer role on ReserveOracle
        reserveOracle.grantRole(reserveOracle.ORACLE_WRITER_ROLE(), oracleWriter);
        
        // Grant subscription pool compliance officer role for recording actions
        complianceRegistry.grantRole(complianceRegistry.COMPLIANCE_OFFICER_ROLE(), address(subscriptionPool));
        
        console.log("✅ Roles configured");
    }
    
    function _configureSystem() internal {
        console.log("⚙️ Configuring system parameters...");
        
        // Configure accepted tokens in subscription pool (USDT for now)
        if (usdt != address(0)) {
            subscriptionPool.addAcceptedToken(usdt);
        }
        
        // Configure some basic price feeds if available
        // Note: In production, these would be actual Chainlink feed addresses
        if (block.chainid == 11155111) { // Sepolia
            // These are example/test feeds - replace with real Chainlink addresses
            try {
                // Gold price feed (placeholder - use real Chainlink XAU/USD feed)
                priceFeeds.setPriceFeed(
                    keccak256("XAU/USD"),
                    address(0x0), // Placeholder - set real Chainlink aggregator
                    3600, // 1 hour heartbeat
                    "Gold spot price"
                );
            } catch {
                console.log("⚠️  Skipping price feed setup - no real feeds available");
            }
        }
        
        console.log("✅ System configured");
    }
    
    function _logDeploymentSummary() internal view {
        console.log("\n🎯 DEPLOYMENT SUMMARY");
        console.log("====================");
        console.log("Network:", block.chainid);
        console.log("Block Number:", block.number);
        console.log("Gas Price:", tx.gasprice);
        console.log("");
        
        console.log("📋 Contract Addresses:");
        console.log("FTHG Token:        ", address(fthgToken));
        console.log("IdentitySBT:       ", address(identitySBT));
        console.log("ComplianceRegistry:", address(complianceRegistry));
        console.log("ChainlinkPriceFeeds:", address(priceFeeds));
        console.log("ReserveOracle:     ", address(reserveOracle));
        console.log("GatewayRouter:     ", address(gatewayRouter));
        console.log("SubscriptionPool:  ", address(subscriptionPool));
        console.log("");
        
        console.log("⚙️ Configuration:");
        console.log("Entry Price:       $", entryPrice / 1e18);
        console.log("Lock Period:       ", lockDays, "days");
        console.log("Coverage Floor:    ", coverageFloor / 100, "%");
        console.log("Admin:             ", admin);
        console.log("KYC Signer:        ", kycSigner);
        console.log("Oracle Writer:     ", oracleWriter);
    }
    
    function _saveDeploymentData() internal {
        console.log("\n💾 Saving deployment data...");
        
        string memory deploymentData = string.concat(
            "# FTH-GOLD Extended Deployment\n\n",
            "**Network:** ", vm.toString(block.chainid), "\n",
            "**Block:** ", vm.toString(block.number), "\n",
            "**Timestamp:** ", vm.toString(block.timestamp), "\n",
            "**Deployer:** ", vm.toString(deployer), "\n",
            "**Admin:** ", vm.toString(admin), "\n\n",
            
            "## Contract Addresses\n\n",
            "| Contract | Address |\n",
            "|----------|----------|\n",
            "| FTHG Token | ", vm.toString(address(fthgToken)), " |\n",
            "| IdentitySBT | ", vm.toString(address(identitySBT)), " |\n", 
            "| ComplianceRegistry | ", vm.toString(address(complianceRegistry)), " |\n",
            "| ChainlinkPriceFeeds | ", vm.toString(address(priceFeeds)), " |\n",
            "| ReserveOracle | ", vm.toString(address(reserveOracle)), " |\n",
            "| GatewayRouter | ", vm.toString(address(gatewayRouter)), " |\n",
            "| SubscriptionPool | ", vm.toString(address(subscriptionPool)), " |\n\n",
            
            "## Configuration\n\n",
            "- **Entry Price:** $", vm.toString(entryPrice / 1e18), "\n",
            "- **Lock Period:** ", vm.toString(lockDays), " days\n",
            "- **Coverage Floor:** ", vm.toString(coverageFloor / 100), "%\n\n",
            
            "## Next Steps\n\n",
            "1. Configure real Chainlink price feeds\n",
            "2. Set up multi-sig for admin operations\n",
            "3. Configure bridge operators for GatewayRouter\n",
            "4. Test subscription flow with small amounts\n",
            "5. Set up monitoring and alerting\n\n",
            
            "## Verification Commands\n\n",
            "```bash\n",
            "forge verify-contract ", vm.toString(address(fthgToken)), " FTHG --chain ", vm.toString(block.chainid), "\n",
            "forge verify-contract ", vm.toString(address(subscriptionPool)), " SubscriptionPool --chain ", vm.toString(block.chainid), "\n",
            "```\n"
        );
        
        try {
            vm.writeFile("deployments/extended-deployment.md", deploymentData);
            console.log("✅ Deployment data saved to deployments/extended-deployment.md");
        } catch {
            console.log("⚠️  Could not save deployment file");
        }
        
        // Also create a JSON file for programmatic access
        string memory jsonData = string.concat(
            '{\n',
            '  "network": ', vm.toString(block.chainid), ',\n',
            '  "block": ', vm.toString(block.number), ',\n',
            '  "timestamp": ', vm.toString(block.timestamp), ',\n',
            '  "deployer": "', vm.toString(deployer), '",\n',
            '  "admin": "', vm.toString(admin), '",\n',
            '  "contracts": {\n',
            '    "FTHG": "', vm.toString(address(fthgToken)), '",\n',
            '    "IdentitySBT": "', vm.toString(address(identitySBT)), '",\n',
            '    "ComplianceRegistry": "', vm.toString(address(complianceRegistry)), '",\n',
            '    "ChainlinkPriceFeeds": "', vm.toString(address(priceFeeds)), '",\n',
            '    "ReserveOracle": "', vm.toString(address(reserveOracle)), '",\n',
            '    "GatewayRouter": "', vm.toString(address(gatewayRouter)), '",\n',
            '    "SubscriptionPool": "', vm.toString(address(subscriptionPool)), '"\n',
            '  },\n',
            '  "config": {\n',
            '    "entryPriceUSD": ', vm.toString(entryPrice), ',\n',
            '    "lockDays": ', vm.toString(lockDays), ',\n',
            '    "coverageFloorBps": ', vm.toString(coverageFloor), '\n',
            '  }\n',
            '}'
        );
        
        try {
            vm.writeFile("deployments/contracts.json", jsonData);
            console.log("✅ Contract addresses saved to deployments/contracts.json");
        } catch {
            console.log("⚠️  Could not save JSON file");
        }
    }
}