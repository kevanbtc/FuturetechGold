# FTH-GOLD Oracle Specifications

**Version:** 1.0  
**Network:** Ethereum Mainnet + Sepolia Testnet  
**Last Updated:** January 2025  

---

## 🎯 Oracle Architecture Overview

FTH-GOLD employs a multi-source oracle system to ensure reliable, tamper-resistant data feeds for critical system operations. The oracle infrastructure supports coverage monitoring, payout rate calculation, and emergency circuit breaker activation.

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Chainlink     │    │   Independent    │    │   Manual Admin  │
│   Proof of      │────┤    Auditor       │────┤   Attestation   │
│   Reserves      │    │    Feeds         │    │   (Backup)      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                        │                        │
         └────────────────────────┼────────────────────────┘
                                  │
                        ┌─────────▼──────────┐
                        │  MedianizedOracle  │
                        │   (2-of-3 feeds)   │
                        └─────────┬──────────┘
                                  │
                   ┌──────────────┼──────────────┐
                   │              │              │
         ┌─────────▼──────────┐   │   ┌─────────▼──────────┐
         │   ReserveOracle    │   │   │ PayoutRateOracle   │
         │  (Coverage Ratio)  │   │   │ (5-10% Monthly)    │
         └────────────────────┘   │   └────────────────────┘
                                  │
                        ┌─────────▼──────────┐
                        │  CircuitBreaker    │
                        │  (Auto-halt on     │
                        │   coverage < 100%) │
                        └────────────────────┘
```

---

## 📊 Data Feed Specifications

### 1. Reserve Coverage Oracle

**Purpose:** Monitor kg gold reserves vs. issued FTH-G tokens  
**Update Frequency:** Every 24 hours (or on-demand for coverage < 105%)  
**Precision:** 3 decimal places (e.g., 1.023 = 102.3% coverage)

#### Data Sources
1. **Chainlink Proof of Reserves Adapter**
   - Custom external adapter connected to vault APIs
   - Real-time bar list reconciliation
   - Automated assay report parsing

2. **Independent Auditor Feed**
   - Monthly certified reports from licensed precious metals auditor
   - Cross-verification with vault provider data
   - Manual override capability for discrepancies

3. **Admin Manual Attestation** 
   - Backup feed for emergency situations
   - Multi-sig required (3-of-5) for manual updates
   - Time-locked for 6 hours to prevent abuse

#### Feed Aggregation Logic
```solidity
function updateCoverageRatio() external {
    uint256 chainlinkValue = chainlinkFeed.latestAnswer();
    uint256 auditorValue = auditorFeed.latestAnswer();
    uint256 adminValue = adminFeed.latestAnswer();
    
    // Require at least 2 valid feeds
    require(validFeeds >= 2, "Insufficient data sources");
    
    // Use median of available feeds
    uint256 medianValue = calculateMedian(chainlinkValue, auditorValue, adminValue);
    
    // Deviation check: reject if >5% difference from median
    require(abs(medianValue - chainlinkValue) <= medianValue * 500 / 10000, "Chainlink deviation");
    require(abs(medianValue - auditorValue) <= medianValue * 500 / 10000, "Auditor deviation");
    
    coverageRatio = medianValue;
    emit CoverageUpdate(medianValue, block.timestamp);
}
```

---

### 2. Payout Rate Oracle

**Purpose:** Calculate monthly payout rate (5-10%) based on mining performance  
**Update Frequency:** Monthly (1st day of each month)  
**Rate Range:** 500-1000 basis points (5-10%)  

#### Input Variables
- **Production KG:** Actual gold production vs. forecast
- **Refinery Sales:** Net proceeds from gold sales
- **Hedge P&L:** Hedging gains/losses from futures/options
- **Operating Expenses:** Direct mining and processing costs
- **Coverage Buffer:** Maintain 2-5% coverage above 100%

#### Rate Calculation Formula
```
PayoutRate = BaseRate × ProductionMultiplier × PnLAdjustment × CoverageAdjustment

Where:
- BaseRate = 750 bps (7.5% baseline)
- ProductionMultiplier = (ActualKG / ForecastKG) × 0.6 + 0.4
- PnLAdjustment = 1.0 + (NetPnL / TotalCapital) × 0.3
- CoverageAdjustment = min(1.0, CoverageRatio / 1.02)

Final Rate = max(500, min(1000, PayoutRate))
```

#### Rate Smoothing & Limits
- **Maximum Change:** ±100 bps per epoch to prevent rate volatility
- **EMA Smoothing:** 30% weight to new rate, 70% to previous rate
- **Emergency Floor:** Rate forced to 0 if coverage drops below 100%
- **Historical Tracking:** Last 12 months of rates stored on-chain

---

### 3. Price Feed Oracles (Supporting)

#### Gold Spot Price
- **Source:** Chainlink XAU/USD feed (proxy: 0x...)
- **Purpose:** NAV calculations and redemption pricing
- **Heartbeat:** 1 hour updates or 1% price movement
- **Fallback:** London Bullion Market Association (LBMA) API

#### Stablecoin Prices  
- **USDT/USD:** Chainlink feed for deposit normalization
- **USDC/USD:** Primary reference for USD calculations  
- **ETH/USD:** For ETH deposit conversion to USD equivalent

#### FX Rates (Mining Operations)
- **USD/AED:** For Dubai operational expense hedging
- **USD/CAD:** For Canadian mining operations
- **USD/AUD:** For Australian mining operations

---

## 🔧 Oracle Infrastructure

### Chainlink Node Configuration

```toml
[ChainlinkNode]
URL = "wss://sepolia.infura.io/ws/v3/YOUR_PROJECT_ID"
MinContractPayment = "0.1"
HTTPServerWriteTimeout = "30s"

[P2P]
PeerID = "12D3KooWPjceQrSwdWXPyLLeABRXmuqt69Rg3qdgzT4r7y3N"
ListenAddresses = ["/ip4/0.0.0.0/tcp/6689"]

[FeedsManager]
ContractAddress = "0x..." # FeedRegistry address
JobIDs = [
  "proof-of-reserves-job-id",
  "payout-rate-calculation-job",
  "gold-price-aggregation-job"
]
```

### External Adapter Specifications

#### Reserve Monitoring Adapter
```javascript
// External adapter for vault API integration
const adapter = {
  name: 'vault-reserves-adapter',
  endpoint: 'https://vault-api.brinks.com/v2/positions',
  authentication: 'Bearer JWT_TOKEN',
  
  processData: (vaultData) => {
    const totalKG = vaultData.positions
      .filter(pos => pos.client === 'FTH-GOLD')
      .reduce((sum, pos) => sum + pos.kg_refined, 0);
    
    const issuedTokens = fthgContract.totalSupply() / 1e18;
    const coverageRatio = (totalKG / issuedTokens) * 10000; // basis points
    
    return {
      coverage: Math.round(coverageRatio),
      timestamp: Date.now(),
      source: 'brinks-vault-api'
    };
  }
};
```

#### Mining Performance Adapter
```javascript
// Adapter for mining production data
const miningAdapter = {
  name: 'mining-production-adapter',
  sources: [
    'https://mine-api-1.fthholdings.com/production',
    'https://mine-api-2.fthholdings.com/production',
    'https://refinery-api.fthholdings.com/settlements'
  ],
  
  aggregateData: (miningData, refineryData) => {
    const monthlyProduction = miningData.reduce((sum, mine) => 
      sum + mine.monthly_kg_produced, 0);
    
    const refineryRevenue = refineryData.settlements
      .filter(s => s.settlement_date >= startOfMonth)
      .reduce((sum, s) => sum + s.usd_amount, 0);
    
    const productionRatio = monthlyProduction / FORECAST_MONTHLY_KG;
    const revenuePerKG = refineryRevenue / monthlyProduction;
    
    return {
      productionRatio,
      revenuePerKG,
      timestamp: Date.now()
    };
  }
};
```

---

## 🛡️ Oracle Security & Resilience

### Sybil Attack Prevention
- **Node Diversity:** Minimum 3 independent oracle nodes
- **Operator Diversity:** Different organizations running nodes  
- **Geographic Distribution:** Nodes in different countries/regions
- **Reputation System:** Historical accuracy scoring for oracle operators

### Oracle Manipulation Protection
- **Deviation Limits:** Reject feeds deviating >5% from median
- **Time-weighted Average:** TWAP calculations to smooth price manipulation
- **Circuit Breakers:** Auto-halt on suspicious oracle behavior
- **Multi-feed Validation:** Cross-reference multiple independent sources

### Data Source Verification
- **API Authentication:** JWT tokens with short expiration
- **SSL/TLS Encryption:** All data transmission encrypted in transit
- **Data Signing:** Cryptographic signatures on all data submissions
- **Audit Trail:** Complete logging of all oracle updates with timestamps

### Failover & Recovery Procedures

#### Primary Failover Sequence
1. **Chainlink Node Failure:** Switch to backup Chainlink nodes (round-robin)
2. **API Endpoint Failure:** Failover to mirror APIs within 30 seconds  
3. **Multiple Feed Failure:** Switch to manual admin attestation mode
4. **Complete Oracle Failure:** Emergency pause all payouts/issuance

#### Recovery Procedures
- **Service Restoration:** Automated health checks every 60 seconds
- **Data Backfill:** Historical data validation upon service restoration  
- **Gradual Resumption:** Phased resumption of automated operations
- **Post-Incident Review:** Root cause analysis and system improvements

---

## 📊 Oracle Performance Monitoring

### Key Performance Indicators
- **Uptime:** Target 99.9% availability (8.76 hours downtime per year)
- **Latency:** <30 second response time for critical updates
- **Accuracy:** <1% deviation from independently verified values  
- **Timeliness:** Updates delivered within scheduled windows

### Monitoring & Alerting
```yaml
# Oracle monitoring configuration
monitoring:
  metrics:
    - oracle_uptime_percentage
    - feed_deviation_from_median
    - update_latency_seconds
    - failed_update_count
    
  alerts:
    - name: "Oracle Deviation Alert"
      condition: "deviation > 5%"
      severity: "critical"
      notification: ["ops-team@fth.com", "pager-duty"]
    
    - name: "Feed Staleness Alert" 
      condition: "last_update_age > 2 hours"
      severity: "warning"
      notification: ["ops-team@fth.com"]
      
    - name: "Coverage Breach Alert"
      condition: "coverage_ratio < 10000" # 100%
      severity: "critical"  
      notification: ["all-hands@fth.com"]
      action: "trigger_circuit_breaker"
```

### Performance Dashboards
- **Real-time Oracle Status:** Live feed health and update timestamps
- **Historical Accuracy:** Deviation tracking over time  
- **Coverage Monitoring:** Real-time gold reserves vs. issued tokens
- **Rate Calculation Transparency:** Show all inputs to payout rate formula

---

## 🔧 Oracle Administration

### Access Controls & Permissions
```solidity
// Oracle admin role structure
contract OracleManager {
    bytes32 public constant ORACLE_WRITER_ROLE = keccak256("ORACLE_WRITER");
    bytes32 public constant ORACLE_ADMIN_ROLE = keccak256("ORACLE_ADMIN");
    bytes32 public constant EMERGENCY_PAUSE_ROLE = keccak256("EMERGENCY_PAUSE");
    
    modifier onlyOracleWriter() {
        require(hasRole(ORACLE_WRITER_ROLE, msg.sender), "Not authorized");
        _;
    }
    
    modifier onlyOracleAdmin() {
        require(hasRole(ORACLE_ADMIN_ROLE, msg.sender), "Not authorized"); 
        _;
    }
}
```

### Role Assignments
- **ORACLE_WRITER:** Chainlink nodes, auditor feed, backup admin multisig
- **ORACLE_ADMIN:** Protocol admin multisig (3-of-5)
- **EMERGENCY_PAUSE:** Circuit breaker contract, ops multisig (2-of-3)

### Key Rotation Procedures
1. **Scheduled Rotation:** Quarterly key rotation for all oracle accounts
2. **Emergency Rotation:** Immediate rotation if key compromise suspected
3. **Multi-sig Updates:** 5-day timelock for oracle admin role changes
4. **Backup Keys:** Offline backup keys stored in hardware security modules

---

## 📋 Oracle Deployment Checklist

### Mainnet Deployment
- [ ] Deploy OracleManager contract with proper role assignments
- [ ] Configure Chainlink nodes with job specifications
- [ ] Deploy external adapters with API authentication  
- [ ] Set up monitoring and alerting infrastructure
- [ ] Test failover procedures with simulated outages
- [ ] Configure circuit breaker thresholds and actions
- [ ] Complete security audit of oracle contracts
- [ ] Train operations team on oracle maintenance procedures

### Testnet Validation  
- [ ] Deploy complete oracle infrastructure on Sepolia
- [ ] Test all data feed integrations with mock data
- [ ] Simulate various failure scenarios and validate failover
- [ ] Verify circuit breaker activation on coverage breach
- [ ] Test manual admin attestation procedures
- [ ] Validate rate calculation formula with historical data
- [ ] Load test oracle infrastructure under high transaction volume

---

## 📞 Oracle Support & Contacts

### Technical Contacts
- **Oracle Lead:** oracle-team@futuretechholdings.com
- **Chainlink Support:** support@chain.link (Enterprise SLA)
- **Infrastructure Team:** infra@futuretechholdings.com
- **Emergency Hotline:** +971-50-XXX-XXXX (24/7 on-call)

### Vendor Contacts  
- **Vault API Support:** Brinks Digital API Team - api-support@brinks.com
- **Mining Data:** Mine Operations - data@fthoperations.com  
- **Auditor Feed:** Precious Metals Auditor - oracles@auditor.com

### Escalation Matrix
1. **Level 1:** Oracle monitoring alerts → Ops team (30 min response)
2. **Level 2:** Feed failures → Senior engineering team (1 hour response)  
3. **Level 3:** Coverage breach → CTO + Risk committee (immediate)
4. **Level 4:** Critical system failure → CEO + Board (immediate)

---

*Oracle specifications are reviewed quarterly and updated as needed. Next review: April 2025*

**Document Owner:** Chief Technology Officer  
**Approval:** Engineering Committee + Risk Committee