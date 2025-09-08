#!/bin/bash

# FTH-GOLD System Health Check Script
# Usage: ./scripts/ops/health-check.sh [network]

set -e

NETWORK=${1:-sepolia}
ENV_FILE=".env"

if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Error: .env file not found"
    exit 1
fi

source $ENV_FILE

echo "🔍 FTH-GOLD System Health Check"
echo "================================"
echo "Network: $NETWORK"
echo "Timestamp: $(date)"
echo

# Check RPC connection
echo "📡 Checking RPC connection..."
RPC_VAR="RPC_$(echo $NETWORK | tr '[:lower:]' '[:upper:]')"
RPC_URL=${!RPC_VAR}

if [ -z "$RPC_URL" ]; then
    echo "❌ RPC URL not configured for network: $NETWORK"
    exit 1
fi

LATEST_BLOCK=$(cast block-number --rpc-url "$RPC_URL" 2>/dev/null)
if [ -z "$LATEST_BLOCK" ]; then
    echo "❌ Failed to connect to RPC"
    exit 1
else
    echo "✅ RPC connected - Latest block: $LATEST_BLOCK"
fi

# Check contract deployments (if deployment file exists)
DEPLOYMENT_FILE="deployments/latest.md"
if [ -f "$DEPLOYMENT_FILE" ]; then
    echo
    echo "📋 Checking contract deployments..."
    
    FTHG_ADDRESS=$(grep "FTHG Token:" "$DEPLOYMENT_FILE" | cut -d' ' -f3)
    if [ -n "$FTHG_ADDRESS" ]; then
        echo "FTHG Token: $FTHG_ADDRESS"
        
        # Check if contract is deployed
        CODE=$(cast code "$FTHG_ADDRESS" --rpc-url "$RPC_URL" 2>/dev/null)
        if [ "$CODE" = "0x" ]; then
            echo "❌ FTHG contract not deployed at $FTHG_ADDRESS"
        else
            echo "✅ FTHG contract deployed"
            
            # Check token details
            NAME=$(cast call "$FTHG_ADDRESS" "name()" --rpc-url "$RPC_URL" 2>/dev/null | cast to-ascii)
            SYMBOL=$(cast call "$FTHG_ADDRESS" "symbol()" --rpc-url "$RPC_URL" 2>/dev/null | cast to-ascii)
            TOTAL_SUPPLY=$(cast call "$FTHG_ADDRESS" "totalSupply()" --rpc-url "$RPC_URL" 2>/dev/null)
            
            echo "  Name: $NAME"
            echo "  Symbol: $SYMBOL" 
            echo "  Total Supply: $(cast to-dec $TOTAL_SUPPLY) tokens"
        fi
    fi
else
    echo "ℹ️  No deployment file found - run deployment first"
fi

# Check environment configuration
echo
echo "⚙️  Configuration Status:"
echo "Entry Price USD: $ENTRY_PRICE_USD"
echo "Lock Cliff Days: $LOCK_CLIFF_DAYS"
echo "Payout Rate BPS: $PAYOUT_RATE_BPS"
echo "Coverage Floor BPS: $COVERAGE_FLOOR_BPS"

# Check external dependencies
echo
echo "🔗 External Dependencies:"

if [ -n "$USDT_SEPOLIA" ]; then
    USDT_CODE=$(cast code "$USDT_SEPOLIA" --rpc-url "$RPC_URL" 2>/dev/null)
    if [ "$USDT_CODE" = "0x" ]; then
        echo "❌ USDT contract not found at $USDT_SEPOLIA"
    else
        echo "✅ USDT contract verified"
    fi
else
    echo "⚠️  USDT address not configured"
fi

# System resource checks
echo
echo "💻 System Resources:"
echo "Disk space: $(df -h . | tail -1 | awk '{print $4}') available"
echo "Memory: $(free -h | grep Mem | awk '{print $7}') available"

# Final summary
echo
echo "✅ Health check completed at $(date)"
echo "📊 Check ./logs/health-check-$(date +%Y%m%d).log for details"

# Create log directory if it doesn't exist
mkdir -p logs

# Save health check results
{
    echo "Health Check Results - $(date)"
    echo "Network: $NETWORK"
    echo "Latest Block: $LATEST_BLOCK"
    echo "FTHG Address: $FTHG_ADDRESS"
    echo "RPC Status: Connected"
} > "logs/health-check-$(date +%Y%m%d).log"