# FTH-GOLD Operations Runbook

**Version:** 1.0  
**Environment:** Production + Staging  
**Last Updated:** January 2025  
**On-Call Rotation:** 24/7 Coverage Required

---

## 🎯 Operations Overview

This runbook provides step-by-step procedures for operating the FTH-GOLD private placement system, including routine maintenance, incident response, and emergency procedures.

---

## 📋 Daily Operations Checklist

### Morning Checks (09:00 UTC)
```bash
# System health verification
./scripts/ops/health-check.sh

# Oracle status validation  
./scripts/ops/oracle-status.sh

# Coverage ratio monitoring
./scripts/ops/check-coverage.sh

# Payout eligibility review
./scripts/ops/payout-queue.sh
```

#### Expected Outputs
- ✅ All contracts operational and not paused
- ✅ Oracle feeds updated within last 24 hours
- ✅ Coverage ratio ≥ 105% (warning if < 102%)
- ✅ Payout queue contains eligible addresses

#### Escalation Triggers
- ❌ Coverage ratio < 100% → **IMMEDIATE** escalation to Risk Committee
- ❌ Oracle feeds stale > 48 hours → Engineering team notification
- ❌ Contract paused unexpectedly → Senior operations review

---

## 🔄 Monthly Payout Operations

### Payout Execution Process

#### Day 1: Rate Calculation & Approval
```bash
# Calculate new monthly rate based on mining performance
node scripts/ops/calculate-payout-rate.js

# Submit rate to PayoutRateOracle (requires admin approval)
./scripts/ops/submit-payout-rate.sh [RATE_BPS]

# Generate payout preview report
./scripts/ops/generate-payout-preview.sh
```

#### Day 2-3: Payout Review & Approval
- **Risk Committee Review:** Rate calculation methodology validation
- **Compliance Review:** Sanctions screening of all eligible addresses  
- **Finance Review:** Treasury balance validation for USDT payouts
- **Board Approval:** Monthly payout authorization (>$1M threshold)

#### Day 4: Payout Execution
```bash
# Execute monthly payouts (run in batches of 50)
./scripts/ops/run-payouts.sh --batch-size 50 --dry-run false

# Verify payout completion
./scripts/ops/verify-payouts.sh

# Generate payout confirmation report  
./scripts/ops/generate-payout-report.sh
```

#### Post-Payout Validation
- All eligible addresses received correct payout amounts
- Treasury balance updated correctly
- Compliance notifications sent for large payouts (>$10k)
- Payout event data indexed correctly in subgraph

---

## 🏗️ Mine Partner Onboarding

### New Mine Integration Process

#### Phase 1: Documentation Review (Day 1-7)
```bash
# Upload NI 43-101 technical report to IPFS
./scripts/ops/upload-mine-docs.sh [MINE_ID] [REPORT_PATH]

# Add mine evidence to ProofOfGold contract
./scripts/ops/add-mine-evidence.sh [MINE_ID] [IPFS_CID] [REPORT_TYPE]

# Generate mine profile summary
./scripts/ops/create-mine-profile.sh [MINE_ID]
```

#### Phase 2: Reserve Validation (Day 8-14)
- **Independent Auditor Review:** Third-party validation of NI 43-101
- **Reserve Oracle Update:** Add mine reserves to total coverage calculation
- **Insurance Verification:** Mine-specific insurance coverage confirmation
- **Environmental Compliance:** ESG screening and documentation

#### Phase 3: Production Integration (Day 15-21) 
```bash
# Configure mine production API endpoint
./scripts/ops/add-mine-api.sh [MINE_ID] [API_ENDPOINT] [AUTH_TOKEN]

# Test production data integration
./scripts/ops/test-mine-integration.sh [MINE_ID]

# Add mine to production monitoring
./scripts/ops/enable-mine-monitoring.sh [MINE_ID]
```

#### Phase 4: Go-Live (Day 22+)
- **Soft Launch:** Monitor production for 30 days with manual validation
- **Full Integration:** Auto-include in payout rate calculations
- **Regular Reporting:** Monthly production and reserve updates

---

## 🏦 Vault Operations & Reconciliation

### Weekly Vault Reconciliation

```bash
# Download vault position files (every Monday 10:00 UTC)
./scripts/ops/fetch-vault-positions.sh

# Cross-reference with internal records
./scripts/ops/reconcile-vault-positions.sh

# Update reserve oracle with latest positions
./scripts/ops/update-reserves.sh

# Generate reconciliation report
./scripts/ops/vault-reconciliation-report.sh
```

#### Vault Position File Format
```json
{
  "vault_id": "BRINKS_DUBAI_01",
  "reporting_date": "2025-01-15",
  "client": "FTH-GOLD",
  "positions": [
    {
      "bar_serial": "ABC123456",
      "weight_kg": 12.441,
      "purity": 0.9999,
      "assay_certificate": "CERT789",
      "location": "VAULT_A_SHELF_15"
    }
  ],
  "total_client_kg": 1247.891,
  "signature": "vault_admin_signature"
}
```

### Monthly Physical Audit Procedures

#### Pre-Audit Preparation (Day -3)
- Schedule vault access with security team
- Prepare audit checklist and bar sampling methodology  
- Coordinate with independent auditor and vault staff
- Generate expected inventory report from system

#### Audit Day Procedures
1. **Physical Count:** Sample 10% of bars using statistical sampling
2. **Weight Verification:** Verify bar weights against certificates  
3. **Assay Validation:** XRF testing on 5% of sampled bars
4. **Chain of Custody:** Document all handling and testing procedures
5. **Discrepancy Recording:** Note any variances > 0.1% for investigation

#### Post-Audit (Day +1 to +3)
```bash  
# Process audit results
./scripts/ops/process-audit-results.sh [AUDIT_ID] [RESULTS_FILE]

# Update reserves if discrepancies found
./scripts/ops/adjust-reserves.sh [ADJUSTMENT_KG] [REASON]

# Generate audit compliance report
./scripts/ops/audit-compliance-report.sh [AUDIT_ID]
```

---

## 🔄 Refinery Operations Management

### Gold Delivery & Settlement Process

#### Delivery Scheduling
```bash
# Schedule gold delivery to refinery
./scripts/ops/schedule-delivery.sh [REFINERY_ID] [KG_AMOUNT] [DELIVERY_DATE]

# Generate transport documentation
./scripts/ops/generate-transport-docs.sh [DELIVERY_ID]

# Coordinate with security transport provider
./scripts/ops/notify-transport-provider.sh [DELIVERY_ID]
```

#### Settlement Processing
```bash
# Process refinery settlement (after assay completion)
./scripts/ops/process-settlement.sh [SETTLEMENT_ID] [ASSAY_RESULTS]

# Update mining revenue in rate calculation
./scripts/ops/update-mining-revenue.sh [REVENUE_AMOUNT] [SETTLEMENT_DATE]

# Generate settlement report for accounting
./scripts/ops/settlement-report.sh [SETTLEMENT_ID]
```

### Assay Dispute Resolution
```bash
# Initiate dispute process (if settlement < expected by >1%)
./scripts/ops/initiate-assay-dispute.sh [SETTLEMENT_ID] [DISPUTE_REASON]

# Upload counter-assay results
./scripts/ops/upload-counter-assay.sh [DISPUTE_ID] [COUNTER_ASSAY_FILE]

# Calculate settlement adjustment
./scripts/ops/calculate-dispute-resolution.sh [DISPUTE_ID]
```

---

## 🚨 Incident Response Procedures

### Level 1: Coverage Breach (< 100%)

#### Immediate Actions (0-30 minutes)
```bash
# Verify coverage calculation
./scripts/ops/verify-coverage-calculation.sh

# Pause payouts and new issuance automatically triggered
# Check CircuitBreaker status  
./scripts/ops/check-circuit-breaker.sh

# Notify all stakeholders
./scripts/ops/send-breach-notification.sh [COVERAGE_PERCENTAGE]
```

#### Investigation Phase (30 minutes - 4 hours)
- **Root Cause Analysis:** Determine source of coverage shortfall
- **Data Validation:** Cross-check all vault positions and audit records
- **Impact Assessment:** Calculate required reserve additions
- **Remediation Planning:** Develop coverage restoration timeline

#### Resolution (4+ hours)
```bash
# Add additional reserves (after physical verification)
./scripts/ops/add-emergency-reserves.sh [KG_AMOUNT] [SOURCE]

# Update oracle with new coverage data  
./scripts/ops/emergency-coverage-update.sh

# Resume operations (after coverage > 102%)
./scripts/ops/resume-operations.sh
```

### Level 2: Oracle Failure

#### Primary Oracle Failover
```bash
# Check oracle health status
./scripts/ops/oracle-health-check.sh

# Switch to backup oracle feeds
./scripts/ops/activate-backup-oracles.sh

# Validate backup feed data quality
./scripts/ops/validate-backup-feeds.sh
```

#### Manual Override Mode
```bash
# If all automated oracles fail, switch to manual mode
./scripts/ops/enable-manual-oracle-mode.sh

# Submit manual attestation (requires 3-of-5 multisig)
./scripts/ops/manual-oracle-update.sh [COVERAGE_RATIO] [RATE_BPS]

# Schedule oracle repair and testing
./scripts/ops/schedule-oracle-repair.sh
```

### Level 3: Smart Contract Exploit

#### Emergency Response
```bash
# Emergency pause all operations
./scripts/ops/emergency-pause-all.sh

# Take system snapshot for analysis
./scripts/ops/system-snapshot.sh [INCIDENT_ID]

# Notify security team and auditors
./scripts/ops/security-incident-notification.sh [INCIDENT_ID]
```

#### Investigation & Recovery
- **Exploit Analysis:** Technical review with external security experts
- **Impact Assessment:** Determine affected users and financial impact
- **Recovery Planning:** Contract migration strategy if required
- **User Communication:** Transparent updates every 4 hours

---

## 🔑 Access Control & Key Management

### Administrative Access Levels

#### Level 1: Read-Only Operations
- **Scope:** System monitoring, report generation, status checks
- **Access:** Single-key access via operations accounts
- **Personnel:** Operations team, customer support

#### Level 2: Routine Operations  
- **Scope:** Payout execution, oracle updates, mine data management
- **Access:** 2-of-3 multisig required
- **Personnel:** Senior operations manager, finance director, compliance officer

#### Level 3: System Administration
- **Scope:** Contract parameters, emergency pause, vault updates
- **Access:** 3-of-5 multisig required  
- **Personnel:** CTO, CFO, CRO, CEO, Board representative

#### Level 4: Emergency Powers
- **Scope:** Contract migration, asset recovery, system rebuild
- **Access:** 4-of-7 multisig + board resolution
- **Personnel:** Full board + external trustees

### Key Rotation Schedule
```bash
# Monthly rotation of operational keys
./scripts/ops/rotate-operational-keys.sh

# Quarterly rotation of admin multisig keys
./scripts/ops/rotate-admin-keys.sh

# Annual rotation of emergency multisig keys
./scripts/ops/rotate-emergency-keys.sh
```

---

## 📊 Monitoring & Alerting

### Critical Alerts (Immediate Response Required)
- Coverage ratio drops below 100%
- Oracle feeds fail for >2 hours  
- Smart contract exploit detected
- Unauthorized admin access attempt
- Vault security breach reported

### Warning Alerts (4 Hour Response SLA)
- Coverage ratio drops below 102%
- Oracle feed deviation >3%
- Large withdrawal requests (>10 tokens)
- Failed payout transactions
- API rate limiting exceeded

### Info Alerts (Next Business Day)
- Daily operation summaries
- Weekly performance reports
- Monthly compliance summaries
- Quarterly risk assessments

### Monitoring Dashboard URLs
- **System Health:** https://dashboard.fthgold.com/health
- **Oracle Status:** https://dashboard.fthgold.com/oracles
- **Coverage Monitor:** https://dashboard.fthgold.com/coverage  
- **Payout Tracker:** https://dashboard.fthgold.com/payouts

---

## 📞 Emergency Contact Directory

### Primary On-Call (24/7)
- **Operations Manager:** +971-50-XXX-1001
- **Technical Lead:** +971-50-XXX-1002  
- **Compliance Officer:** +971-50-XXX-1003

### Secondary Escalation
- **CTO:** +971-50-XXX-2001
- **CFO:** +971-50-XXX-2002
- **CEO:** +971-50-XXX-2003

### External Partners
- **Vault Provider Emergency:** Brinks +971-4-XXX-3001
- **Primary Refinery:** +1-XXX-XXX-3002
- **Security Auditor:** +44-20-XXX-3003
- **Legal Counsel:** Al Tamimi +971-4-XXX-3004

---

## 📚 Operational Scripts Reference

All operational scripts are located in `/scripts/ops/` and require proper authentication:

### Daily Operations
- `health-check.sh` - System status verification
- `oracle-status.sh` - Oracle feed validation
- `check-coverage.sh` - Coverage ratio monitoring
- `payout-queue.sh` - Eligible payout addresses

### Monthly Procedures  
- `calculate-payout-rate.js` - Rate calculation based on mining data
- `run-payouts.sh` - Execute monthly payout distribution
- `vault-reconciliation.sh` - Weekly vault position reconciliation
- `generate-reports.sh` - Monthly operational reports

### Incident Response
- `emergency-pause-all.sh` - System-wide emergency pause
- `circuit-breaker-check.sh` - Validate circuit breaker status
- `activate-backup-oracles.sh` - Failover to backup data feeds
- `coverage-breach-response.sh` - Coverage breach procedures

### Mine & Vault Management
- `add-mine-evidence.sh` - Upload mine documentation to IPFS
- `update-reserves.sh` - Update reserve oracle with latest data
- `schedule-delivery.sh` - Coordinate refinery deliveries
- `process-settlement.sh` - Handle refinery settlement processing

---

**Next Review Date:** April 2025  
**Document Owner:** Head of Operations  
**Approval Authority:** Executive Committee

*This runbook is a living document updated based on operational experience and system changes.*