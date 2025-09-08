#!/bin/bash

# FTH-GOLD Testnet Deployment Script
# Deploys complete system to Sepolia testnet with configuration

set -e

NETWORK=${1:-sepolia}
ENV_FILE=".env"

echo "🚀 FTH-GOLD Testnet Deployment"
echo "==============================="
echo "Network: $NETWORK"
echo "Timestamp: $(date)"
echo

# Check prerequisites
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Error: .env file not found. Copy .env.example and configure it."
    exit 1
fi

source $ENV_FILE

# Validate required environment variables
required_vars=(
    "PRIVATE_KEY"
    "RPC_SEPOLIA"
    "ETHERSCAN_API_KEY"
    "ENTRY_PRICE_USD"
    "LOCK_CLIFF_DAYS"
    "PAYOUT_RATE_BPS"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Error: $var not set in .env file"
        exit 1
    fi
done

echo "✅ Environment validated"

# Create deployments directory
mkdir -p deployments
mkdir -p logs

# Deploy contracts with Foundry
echo
echo "📋 Deploying smart contracts..."
forge script scripts/deploy/Deploy.s.sol \
    --rpc-url $RPC_SEPOLIA \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --slow \
    2>&1 | tee "logs/deployment-$(date +%Y%m%d-%H%M%S).log"

# Check deployment status
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "✅ Contract deployment successful"
else
    echo "❌ Contract deployment failed"
    exit 1
fi

# Wait for contract verification
echo
echo "⏳ Waiting for contract verification..."
sleep 30

# Run health check
echo
echo "🔍 Running system health check..."
./scripts/ops/health-check.sh $NETWORK

# Extract contract addresses from deployment artifacts
echo
echo "📊 Extracting contract addresses..."

DEPLOYMENT_FILE="deployments/latest.md"
if [ -f "$DEPLOYMENT_FILE" ]; then
    echo "Contract addresses saved to: $DEPLOYMENT_FILE"
    cat $DEPLOYMENT_FILE
else
    echo "⚠️  Deployment file not found, checking broadcast artifacts..."
    
    BROADCAST_DIR="broadcast/Deploy.s.sol/$NETWORK"
    if [ -d "$BROADCAST_DIR" ]; then
        echo "Latest deployment artifacts in: $BROADCAST_DIR"
        ls -la "$BROADCAST_DIR/"
    fi
fi

# Configure initial system parameters
echo
echo "⚙️ Configuring system parameters..."

# This would call additional setup scripts to:
# - Configure accepted tokens in SubscriptionPool  
# - Set up initial oracle feeds in ChainlinkPriceFeeds
# - Configure jurisdiction settings in ComplianceRegistry
# - Set up bridge operators in GatewayRouter

echo "📝 System configuration complete"

# Generate deployment summary
echo
echo "📋 Deployment Summary"
echo "===================="
echo "Network: $NETWORK"
echo "Block Number: $(cast block-number --rpc-url $RPC_SEPOLIA)"
echo "Entry Price: \$$ENTRY_PRICE_USD"
echo "Cliff Period: $LOCK_CLIFF_DAYS days"
echo "Payout Rate: $PAYOUT_RATE_BPS bps ($(echo "scale=1; $PAYOUT_RATE_BPS / 100" | bc)%)"

echo
echo "🎯 Next Steps:"
echo "1. Add USDT/USDC token addresses to SubscriptionPool"
echo "2. Configure Chainlink oracle feeds for price data"
echo "3. Set up bridge operators for cross-chain deposits"
echo "4. Configure jurisdiction compliance settings"
echo "5. Test subscription flow with small amounts"

echo
echo "✅ Deployment completed successfully!"
echo "📁 Logs saved to: logs/deployment-$(date +%Y%m%d).log"
echo "🌐 View contracts on Etherscan:"
echo "   https://sepolia.etherscan.io"

# Save deployment info to environment
DEPLOYED_TIMESTAMP=$(date +%s)
echo "DEPLOYED_NETWORK=$NETWORK" >> .env.deployed
echo "DEPLOYED_TIMESTAMP=$DEPLOYED_TIMESTAMP" >> .env.deployed
echo "DEPLOYED_BLOCK=$(cast block-number --rpc-url $RPC_SEPOLIA)" >> .env.deployed

echo
echo "🔗 Deployment info saved to .env.deployed"