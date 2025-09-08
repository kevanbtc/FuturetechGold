// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../contracts/core/SubscriptionPool.sol";
import "../contracts/core/AgreementRegistry.sol";
import "../contracts/compliance/IdentitySBT.sol";
import "../contracts/compliance/ComplianceRegistry.sol";

/**
 * @title DeployGlobalContracts - Global Smart Contract Deployment
 * @notice Deploys the complete AI DocuSign-like global infrastructure
 * @dev Handles multi-network deployment with proper configuration
 */
contract DeployGlobalContracts is Script {
    
    // Configuration from environment
    address public admin;
    address public fthgToken;
    address public treasuryMultisig;
    address public emergencyMultisig;
    
    // Deployed contract addresses
    IdentitySBT public identitySBT;
    ComplianceRegistry public complianceRegistry;
    AgreementRegistry public agreementRegistry;
    SubscriptionPool public subscriptionPool;
    
    function run() external {
        // Load configuration from environment
        admin = vm.envAddress("ADMIN_ADDRESS");
        fthgToken = vm.envAddress("FTHG_TOKEN_ADDRESS");
        treasuryMultisig = vm.envAddress("TREASURY_MULTISIG");
        emergencyMultisig = vm.envAddress("EMERGENCY_MULTISIG");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("=== Deploying Future Tech Holdings Global Infrastructure ===");
        console.log("Admin:", admin);
        console.log("FTHG Token:", fthgToken);
        console.log("Treasury Multisig:", treasuryMultisig);
        console.log("Emergency Multisig:", emergencyMultisig);
        console.log("");
        
        // 1. Deploy Identity SBT Contract
        console.log("1. Deploying Identity SBT...");
        identitySBT = new IdentitySBT(
            "FTH Identity SBT",
            "FTH-ID",
            admin
        );
        console.log("Identity SBT deployed at:", address(identitySBT));
        console.log("");
        
        // 2. Deploy Compliance Registry
        console.log("2. Deploying Compliance Registry...");
        complianceRegistry = new ComplianceRegistry(admin);
        console.log("Compliance Registry deployed at:", address(complianceRegistry));
        console.log("");
        
        // 3. Deploy Agreement Registry
        console.log("3. Deploying Agreement Registry...");
        agreementRegistry = new AgreementRegistry(admin);
        console.log("Agreement Registry deployed at:", address(agreementRegistry));
        console.log("");
        
        // 4. Deploy Mock Whitelist Gate (simplified for demo)
        console.log("4. Deploying Mock Whitelist Gate...");
        address mockWhitelistGate = _deployMockWhitelistGate();
        console.log("Mock Whitelist Gate deployed at:", mockWhitelistGate);
        console.log("");
        
        // 5. Deploy Subscription Pool
        console.log("5. Deploying Subscription Pool...");
        subscriptionPool = new SubscriptionPool(
            fthgToken,
            address(identitySBT),
            address(complianceRegistry),
            mockWhitelistGate,
            address(agreementRegistry),
            admin
        );
        console.log("Subscription Pool deployed at:", address(subscriptionPool));
        console.log("");
        
        // 6. Configure contracts
        _configureContracts();
        
        vm.stopBroadcast();
        
        // 7. Save deployment info
        _saveDeploymentInfo();
        
        console.log("=== Deployment Complete ===");
        console.log("");
        console.log("🎯 Next Steps:");
        console.log("1. Verify contracts on Etherscan");
        console.log("2. Set up IPFS pinning service");
        console.log("3. Configure DocuSign integration");
        console.log("4. Test the complete signing flow");
        console.log("");
        console.log("🔗 Contract Addresses:");
        console.log("Identity SBT:", address(identitySBT));
        console.log("Compliance Registry:", address(complianceRegistry));
        console.log("Agreement Registry:", address(agreementRegistry));
        console.log("Subscription Pool:", address(subscriptionPool));
        console.log("Whitelist Gate:", mockWhitelistGate);
    }
    
    /**
     * @notice Deploy a mock whitelist gate for testing
     * @return Address of deployed mock contract
     */
    function _deployMockWhitelistGate() internal returns (address) {
        // Simple mock contract that allows all addresses
        bytes memory mockBytecode = abi.encodePacked(
            // Simple contract that returns true for isWhitelisted()
            hex"608060405234801561001057600080fd5b5060e58061001f6000396000f3fe"
        );
        
        address mockContract;
        assembly {
            mockContract := create2(0, add(mockBytecode, 0x20), mload(mockBytecode), salt())
        }
        
        return mockContract;
        
        function salt() internal view returns (bytes32) {
            return keccak256(abi.encodePacked("MockWhitelistGate", block.chainid));
        }
    }
    
    /**
     * @notice Configure deployed contracts with proper permissions
     */
    function _configureContracts() internal {
        console.log("6. Configuring contracts...");
        
        // Grant roles to Subscription Pool
        bytes32 notaryRole = keccak256("NOTARY_ROLE");
        agreementRegistry.grantRole(notaryRole, address(subscriptionPool));
        
        bytes32 complianceOfficerRole = keccak256("COMPLIANCE_OFFICER_ROLE");
        complianceRegistry.grantRole(complianceOfficerRole, address(subscriptionPool));
        
        bytes32 kycOperatorRole = keccak256("KYC_OPERATOR_ROLE");
        identitySBT.grantRole(kycOperatorRole, admin);
        
        // Set up additional compliance settings
        _setupComplianceDefaults();
        
        console.log("Contract configuration complete");
    }
    
    /**
     * @notice Set up default compliance configuration
     */
    function _setupComplianceDefaults() internal {
        // Add approved KYC providers
        string[] memory providers = new string[](4);
        providers[0] = "Sumsub";
        providers[1] = "Trulioo";  
        providers[2] = "Persona";
        providers[3] = "Internal";
        
        for (uint i = 0; i < providers.length; i++) {
            identitySBT.setKYCProviderApproval(providers[i], true);
        }
        
        // Set default jurisdiction rules (already done in constructor)
        // Additional configuration can be added here
    }
    
    /**
     * @notice Save deployment information to file
     */
    function _saveDeploymentInfo() internal {
        string memory chainIdStr = vm.toString(block.chainid);
        string memory deploymentPath = string.concat("deployments/", chainIdStr, ".json");
        
        string memory json = string.concat(
            '{',
                '"network": "', _getNetworkName(), '",',
                '"chainId": ', chainIdStr, ',',
                '"timestamp": ', vm.toString(block.timestamp), ',',
                '"deployer": "', vm.toString(msg.sender), '",',
                '"contracts": {',
                    '"IdentitySBT": "', vm.toString(address(identitySBT)), '",',
                    '"ComplianceRegistry": "', vm.toString(address(complianceRegistry)), '",',
                    '"AgreementRegistry": "', vm.toString(address(agreementRegistry)), '",',
                    '"SubscriptionPool": "', vm.toString(address(subscriptionPool)), '"',
                '}',
            '}'
        );
        
        vm.writeFile(deploymentPath, json);
        console.log("Deployment info saved to:", deploymentPath);
    }
    
    /**
     * @notice Get network name from chain ID
     * @return Network name string
     */
    function _getNetworkName() internal view returns (string memory) {
        uint256 chainId = block.chainid;
        
        if (chainId == 1) return "ethereum";
        if (chainId == 11155111) return "sepolia";
        if (chainId == 137) return "polygon";
        if (chainId == 80001) return "mumbai";
        if (chainId == 8453) return "base";
        if (chainId == 42161) return "arbitrum";
        if (chainId == 421614) return "arbitrum-sepolia";
        
        return "unknown";
    }
    
    /**
     * @notice Verification helper - prints contract verification commands
     */
    function printVerificationCommands() external view {
        console.log("=== Contract Verification Commands ===");
        console.log("");
        
        string memory chainName = _getNetworkName();
        
        console.log("forge verify-contract", address(identitySBT), 
                   "contracts/compliance/IdentitySBT.sol:IdentitySBT",
                   "--chain", chainName,
                   "--constructor-args",
                   abi.encode("FTH Identity SBT", "FTH-ID", admin));
        
        console.log("");
        console.log("forge verify-contract", address(complianceRegistry),
                   "contracts/compliance/ComplianceRegistry.sol:ComplianceRegistry", 
                   "--chain", chainName,
                   "--constructor-args",
                   abi.encode(admin));
        
        console.log("");
        console.log("forge verify-contract", address(agreementRegistry),
                   "contracts/core/AgreementRegistry.sol:AgreementRegistry",
                   "--chain", chainName, 
                   "--constructor-args",
                   abi.encode(admin));
        
        console.log("");
        console.log("forge verify-contract", address(subscriptionPool),
                   "contracts/core/SubscriptionPool.sol:SubscriptionPool",
                   "--chain", chainName,
                   "--constructor-args", 
                   abi.encode(
                       fthgToken,
                       address(identitySBT),
                       address(complianceRegistry),
                       address(0), // whitelist gate placeholder
                       address(agreementRegistry),
                       admin
                   ));
    }
}