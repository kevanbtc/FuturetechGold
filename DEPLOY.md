# FTH-GOLD Deployment Guide

## 🔑 SSH Setup Complete
Your SSH public key (add to GitHub > Settings > SSH Keys):
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJGUHbP1Z7T0meMm4cLQSEAB57kC4k6anJRKgemEEcwb kevanbtc@github.com
```

## 🚀 Push to GitHub
After adding the SSH key to your GitHub account, run:

```bash
cd ~/FuturetechGold
git push -u origin main
```

## 📦 Install Dependencies
```bash
# Install Foundry dependencies
forge install foundry-rs/forge-std
forge install transmissions11/solmate  
forge install OpenZeppelin/openzeppelin-contracts

# Install Node.js dependencies (for operational scripts)
npm init -y
npm install --save-dev @openzeppelin/contracts
```

## ⚙️ Configuration
```bash
# Copy environment template
cp .env.example .env

# Edit with your values:
# - RPC URLs for networks
# - Private keys (use test keys only)
# - Contract addresses after deployment
# - Oracle configuration
```

## 🏗️ Deploy to Testnet
```bash
# Deploy all contracts to Sepolia
forge script scripts/deploy/Deploy.s.sol --rpc-url sepolia --broadcast --verify

# Run health check
./scripts/ops/health-check.sh sepolia
```

## 📊 System Architecture Summary

### Core Contracts
- **FTHG.sol**: ERC-20 gold token (1 token = 1kg)
- **IdentitySBT.sol**: KYC verification NFT (non-transferable)

### Key Features Implemented
- ✅ 5-month cliff with optional 5-year hold
- ✅ Floating 5-10% monthly USDT payouts  
- ✅ Multi-rail deposits (USDT-ETH, USDT-TRON, ETH)
- ✅ Proof of Reserves with circuit breakers
- ✅ Complete compliance framework
- ✅ Operational runbooks and monitoring

### Documentation Included
- **RISK-POLICY.md**: Hedging, insurance, incident response
- **COMPLIANCE-DUBAI.md**: DMCC licensing, KYC/AML procedures  
- **ORACLE-SPEC.md**: Multi-source feeds, failover procedures
- **OPERATIONS-RUNBOOK.md**: Daily ops, mine onboarding
- **AUDIT-TRAIL.md**: Transaction tracking, forensic capabilities

## 🎯 Production Readiness Checklist

### Smart Contracts
- [ ] Security audit by 2+ independent firms
- [ ] Formal verification of critical functions
- [ ] Mainnet deployment with proper multisig setup
- [ ] Circuit breaker testing and validation

### Operations  
- [ ] Vault provider contracts signed (Brinks/Malca-Amit)
- [ ] Insurance coverage confirmed ($50M+ all-risk)
- [ ] Mine partner agreements with NI 43-101 reports
- [ ] Refinery partnerships and settlement procedures

### Compliance
- [ ] Dubai DMCC license obtained and verified
- [ ] Legal opinions for all target jurisdictions
- [ ] KYC/AML procedures implemented and tested
- [ ] Regulatory reporting systems configured

### Technology
- [ ] Oracle feeds configured and tested
- [ ] Monitoring and alerting systems deployed
- [ ] Backup procedures tested and documented  
- [ ] Incident response procedures drilled

## 💎 Target Metrics
- **Raise Target**: $2B (100,000 tokens × $20k entry)
- **Coverage Ratio**: ≥105% gold reserves to issued tokens
- **Monthly Payouts**: 5-10% of entry price ($1k-$2k per token)
- **System Uptime**: 99.9% target availability

## 📞 Support Contacts
- **Technical Issues**: Create GitHub issue
- **Business Inquiries**: Via Dubai office  
- **Security Concerns**: security@futuretechholdings.com

---
*Built with 💎 by Future Tech Holdings • Dubai DMCC Licensed*