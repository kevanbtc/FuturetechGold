# FTH-G Add-ons: Non-Breaking Chainlink Integrations

**Safe, modular extensions for FTH-G core system**

This package provides Chainlink integrations and enhanced distribution systems that read from your existing FTH-G core contracts without requiring any modifications to the core system.

## 🎯 Overview

All add-ons in this package are:
- ✅ **Non-breaking**: No changes to core FTH-G contracts required
- ✅ **Read-only integrations**: Use minimal interfaces to read core state
- ✅ **Fully isolated**: Can be deployed/removed without affecting core
- ✅ **Production-ready**: Comprehensive testing and security controls

## 📦 Add-on Modules

### 1. Chainlink Price Feeds (`FTHGPriceFeedConsumer`)
Real-time price data for gold, ETH, and stablecoins with staleness protection.

**Features:**
- ETH/USD, XAU/USD, USDT/USD price feeds
- Cross-rate calculations (ETH per gold ounce)
- Staleness detection and circuit breakers
- Multi-network support (Ethereum, Polygon, Base, Arbitrum)

### 2. Proof of Reserves Monitor (`FTHGProofOfReserves`) 
Automated monitoring of gold reserve coverage with alert system.

**Features:**
- Real-time coverage ratio monitoring
- Configurable minimum coverage thresholds
- Event emission for external monitoring
- Emergency pause integration capability

### 3. Yield Distribution System (`FTHGYieldDistributor`)
Pull-based monthly yield distribution with epoch management.

**Features:**
- Monthly distribution epochs with configurable rates (5-10%)
- Pull-based claiming (users claim when ready)
- Multi-epoch claiming support
- Rate controls and emergency pause

### 4. Chainlink Automation (`FTHGKeepersPayout`)
Automated monthly payout window management using Chainlink Keepers.

**Features:**
- Automated monthly epoch triggering
- Chainlink Keepers compatible
- Gas-efficient upkeep checks
- Integration with yield distributor

## 🚀 Quick Start

### Prerequisites
```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install dependencies
forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 --no-commit
forge install OpenZeppelin/openzeppelin-contracts --no-commit
```

### Environment Setup
```bash
# Copy environment template
cp .env.example .env

# Configure your values:
# - RPC_URL: Your RPC endpoint
# - PRIVATE_KEY: Deployment key
# - FTHG_CORE: Your deployed core contract address
# - USDT: USDT contract address for your network
# - Chainlink feed addresses (see .env.example for network-specific feeds)
```

### Deploy All Add-ons
```bash
# Deploy to testnet
forge script script/DeployAddons.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify

# Deploy to mainnet (when ready)
forge script script/DeployAddons.s.sol \
  --rpc-url mainnet \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

## 🔧 Integration Guide

### Core Contract Interface Requirements

Your core FTH-G contract should implement these view functions for add-ons to work:

```solidity
interface IFTHGCore {
    function isEligible(address user) external view returns (bool);
    function balanceOf(address user) external view returns (uint256);
    function isInCliff(address user) external view returns (bool);
    function totalSupply() external view returns (uint256);
}
```

If your core contract doesn't have these exact function names, you can create a simple adapter contract that implements this interface and forwards calls to your core contract.

### Price Feed Usage

```solidity
// Get latest gold price
(int256 goldPrice, uint256 timestamp) = priceFeedConsumer.getGoldPrice();

// Get ETH price  
(int256 ethPrice, uint256 timestamp) = priceFeedConsumer.getETHPrice();

// Calculate ETH per gold ounce
uint256 ethPerOunce = priceFeedConsumer.getETHPerGoldOunce();

// Convert USD to ETH
uint256 ethAmount = priceFeedConsumer.convertUSDToETH(1000e6); // $1000
```

### Yield Distribution Usage

```solidity
// Users claim yields (pull-based)
yieldDistributor.claimYield(epochNumber);

// Claim multiple epochs at once
uint256[] memory epochs = [1, 2, 3];
yieldDistributor.claimMultipleEpochs(epochs);

// Check claimable amount
uint256 claimable = yieldDistributor.getClaimableAmount(epochNumber, userAddress);

// Admin: start new epoch with custom rate
yieldDistributor.startNewEpoch(1000); // 10% rate
```

### Monitoring Integration

```solidity
// Check coverage status
(bool healthy, uint256 coverageBps) = proofOfReserves.check();

// Monitor events
event ProgramStatus(bool healthy, uint256 coverageBps, uint256 timestamp);
```

## 🌐 Network Configuration

### Supported Networks

| Network | Chain ID | ETH/USD Feed | XAU/USD Feed | USDT Address |
|---------|----------|--------------|--------------|--------------|
| Ethereum Mainnet | 1 | 0x5f4eC3...19 | 0x214eD9...D6 | 0xdAC17F...ec7 |
| Ethereum Sepolia | 11155111 | 0x694AA1...06 | Custom | Custom |
| Polygon Mainnet | 137 | 0xF9680D...45 | 0x0C4665...10 | 0xc2132D...F |
| Base Mainnet | 8453 | 0x71041d...70 | - | 0xfde4C9...b2 |
| Arbitrum One | 42161 | 0x639Fe6...12 | 0x1F954D...2c | 0xFd086b...b9 |

See `.env.example` for complete feed addresses.

### TRON Integration Note

For TRON USDT integration, you'll need a custom bridge solution since Chainlink feeds aren't directly available on TRON. Consider:

1. **Cross-chain Oracle**: Use Chainlink CCIP or custom bridge
2. **Proof-based System**: Verify TRON transactions off-chain, submit proofs on-chain
3. **Multi-signature Bridge**: Trusted operator model with stake slashing

## 🧪 Testing

```bash
# Run all tests
forge test

# Run with verbose output
forge test -vv

# Run specific test file
forge test --match-path test/Addons.t.sol

# Generate coverage report
forge coverage
```

## 📊 Usage Examples

### Monthly Distribution Workflow

1. **Epoch Management**: Keepers automatically trigger monthly epochs
2. **Rate Setting**: Admin sets distribution rate (5-10%) based on mining performance  
3. **User Claims**: Users pull their yield when ready (no forced distributions)
4. **Multi-epoch Claims**: Users can claim multiple months at once

### Price Feed Integration

1. **Gold Price Tracking**: Monitor XAU/USD for NAV calculations
2. **ETH Conversion**: Convert between ETH and USD for multi-asset support
3. **Staleness Protection**: Automatic fallback when feeds go stale
4. **Cross-rate Calculations**: Compute complex asset relationships

### Reserve Monitoring

1. **Real-time Coverage**: Monitor gold reserves vs issued tokens
2. **Automated Alerts**: Event emission for external monitoring systems
3. **Threshold Management**: Configurable minimum coverage requirements
4. **Integration Ready**: Can trigger emergency pauses if needed

## 🔒 Security Considerations

- **Read-only Access**: Add-ons only read from core contracts
- **No Storage Conflicts**: Complete isolation from core contract storage
- **Emergency Controls**: Pause functionality for all distribution systems
- **Rate Limits**: Maximum distribution rates to prevent economic attacks
- **Staleness Protection**: Guards against stale or manipulated price feeds

## 📁 File Structure

```
addons/
├── contracts/
│   ├── interfaces/
│   │   ├── IFTHGCore.sol          # Core contract interface
│   │   └── IUSDT.sol              # USDT interface
│   ├── chainlink/
│   │   ├── FTHGPriceFeedConsumer.sol    # Price feeds
│   │   ├── FTHGProofOfReserves.sol      # PoR monitoring  
│   │   └── FTHGKeepersPayout.sol        # Automation
│   └── payments/
│       └── FTHGYieldDistributor.sol     # Distribution system
├── script/
│   └── DeployAddons.s.sol         # Deployment script
├── test/
│   └── Addons.t.sol              # Comprehensive tests
├── deployments/                   # Generated deployment files
├── .env.example                   # Environment template
├── foundry.toml                   # Foundry configuration
├── remappings.txt                # Import path mappings  
└── README.md                     # This file
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add comprehensive tests
4. Ensure all existing tests pass
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 📞 Support

- **GitHub Issues**: For bug reports and feature requests
- **Documentation**: See individual contract files for detailed API docs
- **Integration Help**: Create an issue with your specific integration questions

---

*Built as non-breaking add-ons for FTH-G system • Chainlink integration ready • Production tested*