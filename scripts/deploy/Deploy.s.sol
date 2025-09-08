// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {FTHG} from "../../contracts/core/FTHG.sol";

/**
 * @title Deploy FTH-GOLD System
 * @notice Foundry deployment script for complete FTH-GOLD infrastructure
 * @dev Run with: forge script scripts/deploy/Deploy.s.sol --rpc-url sepolia --broadcast
 */
contract Deploy is Script {
    // Environment variables
    uint256 public deployerKey = vm.envUint("PRIVATE_KEY");
    uint256 public adminKey = vm.envUint("ADMIN_PRIVATE_KEY");
    
    address public deployer = vm.addr(deployerKey);
    address public admin = vm.addr(adminKey);
    
    // Configuration from .env
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
    FTHG public fthg;
    
    function run() external {
        console.log("Deploying FTH-GOLD System...");
        console.log("Deployer:", deployer);
        console.log("Admin:", admin);
        console.log("Entry Price:", entryPrice);
        console.log("Lock Days:", lockDays);
        
        vm.startBroadcast(deployerKey);
        
        // Deploy FTHG token
        fthg = new FTHG(admin, admin);
        console.log("FTHG deployed at:", address(fthg));
        
        vm.stopBroadcast();
        
        // Log deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Network:", block.chainid);
        console.log("FTHG Token:", address(fthg));
        console.log("Admin Address:", admin);
        console.log("Entry Price USD:", entryPrice);
        console.log("Lock Period Days:", lockDays);
        console.log("Payout Rate BPS:", payoutRate);
        
        // Save deployment info
        _saveDeployment();
    }
    
    function _saveDeployment() internal {
        string memory deploymentInfo = string.concat(
            "# FTH-GOLD Deployment\n",
            "Network: ", vm.toString(block.chainid), "\n",
            "Deployer: ", vm.toString(deployer), "\n", 
            "Admin: ", vm.toString(admin), "\n",
            "FTHG Token: ", vm.toString(address(fthg)), "\n",
            "Block Number: ", vm.toString(block.number), "\n",
            "Timestamp: ", vm.toString(block.timestamp), "\n"
        );
        
        vm.writeFile("deployments/latest.md", deploymentInfo);
        console.log("Deployment info saved to deployments/latest.md");
    }
}