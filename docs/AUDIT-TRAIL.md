# FTH-GOLD Audit Trail Specifications

**Version:** 1.0  
**Compliance Standard:** Dubai DMCC + International Audit Standards  
**Last Updated:** January 2025

---

## 🎯 Audit Trail Overview

The FTH-GOLD system maintains comprehensive audit trails across all operational, financial, and compliance activities to ensure transparency, regulatory compliance, and operational integrity.

---

## 📊 Audit Data Categories

### 1. Transaction Audit Trail

#### On-Chain Events
```solidity
// All critical events are emitted and indexed
event Subscribed(address indexed user, uint256 amount, uint256 kgAllocated, uint256 cliffEnd);
event TokenMinted(address indexed user, uint256 amount, uint256 blockNumber);
event PayoutDistributed(address indexed user, uint256 amount, address token, uint256 epoch);
event CoverageUpdated(uint256 kgReserves, uint256 kgIssued, uint256 ratio, uint256 timestamp);
event ReserveEvidenceAdded(uint256 indexed mineId, string ipfsCid, bytes32 documentType);
event CircuitBreakerTriggered(string reason, uint256 timestamp);
```

#### Transaction Data Structure
```json
{
  "transaction_id": "tx_001_20250115",
  "event_type": "payout_distributed",
  "timestamp": "2025-01-15T10:30:00Z",
  "block_number": 19234567,
  "transaction_hash": "0xabc123...",
  "user_address": "0x456def...",
  "amount": "2000.000000",
  "token": "USDT",
  "payout_epoch": 12,
  "pre_balance": "1000.000000",
  "post_balance": "3000.000000",
  "gas_used": 45821,
  "gas_price": "20.0"
}
```

### 2. Reserve & Custody Audit Trail

#### Vault Position Changes
```json
{
  "audit_id": "vault_20250115_001",
  "vault_provider": "Brinks Dubai DMCC",
  "reporting_date": "2025-01-15",
  "audit_type": "daily_reconciliation",
  "positions": [
    {
      "bar_serial": "BRK2025001001",
      "previous_weight_kg": 12.441,
      "current_weight_kg": 12.441,
      "movement_type": "none",
      "location": "VAULT_A_SHELF_15",
      "custody_status": "allocated_fthgold",
      "last_assay_date": "2024-12-01",
      "assay_certificate": "ASSAY_CERT_789456"
    }
  ],
  "summary": {
    "total_kg_previous": 1247.891,
    "total_kg_current": 1247.891,
    "net_change_kg": 0.000,
    "discrepancy_tolerance": 0.001,
    "reconciliation_status": "clean"
  },
  "signatures": {
    "vault_custodian": "John Smith",
    "fth_representative": "Jane Doe",
    "timestamp": "2025-01-15T16:00:00Z"
  }
}
```

#### Mine Production Records
```json
{
  "production_id": "mine_001_202501",
  "mine_name": "Desert Star Gold Mine",
  "reporting_period": "2025-01",
  "production_data": {
    "ore_processed_tonnes": 15420.5,
    "gold_produced_kg": 125.8,
    "recovery_rate_percent": 94.2,
    "direct_costs_usd": 2850000,
    "cost_per_kg_usd": 22648
  },
  "quality_metrics": {
    "average_purity": 0.9987,
    "assay_variance": 0.0008,
    "refinery_acceptance": "approved"
  },
  "compliance": {
    "ni_43_101_compliant": true,
    "environmental_permits": "current",
    "safety_incidents": 0,
    "audit_status": "passed"
  }
}
```

### 3. Oracle & Rate Calculation Audit Trail

#### Payout Rate Calculation History
```json
{
  "calculation_id": "rate_calc_202501",
  "calculation_date": "2025-01-31T23:59:59Z",
  "inputs": {
    "base_rate_bps": 750,
    "production_forecast_kg": 500.0,
    "actual_production_kg": 485.2,
    "refinery_revenue_usd": 31250000,
    "operating_costs_usd": 18500000,
    "hedge_pnl_usd": 125000,
    "coverage_ratio": 1.048
  },
  "calculation_steps": {
    "production_multiplier": 0.954,
    "pnl_adjustment": 1.012,
    "coverage_adjustment": 1.000,
    "raw_rate_bps": 731,
    "smoothing_applied": true,
    "previous_rate_bps": 780,
    "smoothed_rate_bps": 749
  },
  "final_rate": {
    "rate_bps": 749,
    "rate_percentage": 7.49,
    "effective_date": "2025-02-01T00:00:00Z",
    "approved_by": "risk_committee",
    "approval_timestamp": "2025-01-31T20:30:00Z"
  }
}
```

#### Oracle Feed History
```json
{
  "feed_update_id": "oracle_20250115_143022",
  "timestamp": "2025-01-15T14:30:22Z",
  "feed_type": "coverage_ratio",
  "data_sources": {
    "chainlink_feed": {
      "value": 10482,
      "timestamp": "2025-01-15T14:29:45Z",
      "deviation_from_median": 0.2
    },
    "auditor_feed": {
      "value": 10478,
      "timestamp": "2025-01-15T14:28:30Z", 
      "deviation_from_median": -0.2
    },
    "admin_manual": {
      "value": null,
      "timestamp": null,
      "note": "not_required"
    }
  },
  "aggregation": {
    "median_value": 10480,
    "final_value": 10480,
    "confidence_score": 0.998,
    "validation_passed": true
  }
}
```

### 4. Compliance & KYC Audit Trail

#### KYC Verification Records
```json
{
  "kyc_record_id": "kyc_202501_user_456",
  "user_address": "0x456def...",
  "verification_date": "2025-01-15T09:15:00Z",
  "kyc_level": "enhanced_due_diligence",
  "documents_verified": [
    {
      "document_type": "passport",
      "document_number": "P123456789",
      "issuing_country": "AE",
      "verification_method": "automated_ocr",
      "verification_status": "verified",
      "expiry_date": "2028-03-15"
    },
    {
      "document_type": "proof_of_address",
      "verification_method": "manual_review",
      "verification_status": "verified",
      "document_date": "2024-12-20"
    }
  ],
  "screening_results": {
    "sanctions_screening": "passed",
    "pep_screening": "passed",
    "adverse_media": "passed",
    "screening_provider": "Dow Jones Risk Center",
    "screening_date": "2025-01-15T09:16:00Z"
  },
  "risk_assessment": {
    "risk_score": 25,
    "risk_category": "low",
    "geographic_risk": "low",
    "product_risk": "medium",
    "customer_risk": "low"
  }
}
```

#### Sanctions Screening Logs
```json
{
  "screening_id": "sanctions_20250115_001",
  "screening_date": "2025-01-15T02:00:00Z",
  "screening_type": "daily_batch",
  "total_addresses_screened": 1247,
  "matches_found": 0,
  "false_positives": 3,
  "screening_lists": [
    "OFAC_SDN",
    "UN_1267_Sanctions", 
    "EU_Consolidated",
    "UAE_Local_Sanctions"
  ],
  "performance_metrics": {
    "processing_time_seconds": 45.2,
    "api_calls_made": 1247,
    "api_success_rate": 1.0
  }
}
```

---

## 📋 Audit Report Generation

### Monthly Compliance Report

#### Report Structure
```yaml
report_metadata:
  report_id: "compliance_202501"
  reporting_period: "2025-01"
  generated_date: "2025-02-01T00:00:00Z"
  report_type: "monthly_compliance"
  
executive_summary:
  total_active_users: 1247
  total_fthg_issued: 2847.5
  coverage_ratio: 104.8%
  payouts_distributed_usd: 5695000
  compliance_incidents: 0
  
transaction_summary:
  new_subscriptions: 23
  token_maturations: 45
  payout_distributions: 1189
  redemption_requests: 2
  
reserve_summary:
  vault_positions_kg: 2985.2
  monthly_production_kg: 485.2
  refinery_settlements_kg: 234.1
  net_reserve_change_kg: 251.1
  
compliance_metrics:
  kyc_completions: 23
  sanctions_screenings: 31
  pep_reviews: 8
  adverse_media_alerts: 1
  
regulatory_reporting:
  dmcc_position_report: "submitted_on_time"
  fiu_large_transactions: 15
  suspicious_activity_reports: 0
  regulatory_inquiries: 0
```

### Quarterly Audit Package

#### Financial Reconciliation
```json
{
  "reconciliation_id": "q4_2024_financial",
  "period": "Q4 2024",
  "reconciliation_items": {
    "customer_deposits": {
      "blockchain_balance": "56940000.000000",
      "custodial_balance": "56940000.000000",
      "variance": "0.000000",
      "status": "reconciled"
    },
    "gold_reserves": {
      "vault_certificates_kg": "2847.5",
      "blockchain_issued_kg": "2847.5",
      "variance_kg": "0.0",
      "coverage_ratio": "100.0%",
      "status": "reconciled"
    },
    "payout_accruals": {
      "calculated_accrual": "4271550.00",
      "distributed_amount": "4271550.00",
      "pending_amount": "0.00",
      "status": "reconciled"
    }
  }
}
```

#### Operational KPIs
```yaml
operational_kpis:
  system_uptime: 99.97%
  oracle_availability: 99.99%
  payout_success_rate: 100.0%
  average_response_time_ms: 150
  
security_metrics:
  security_incidents: 0
  failed_login_attempts: 23
  api_rate_limit_hits: 156
  unauthorized_access_attempts: 0
  
compliance_metrics:
  kyc_approval_rate: 96.8%
  sanctions_screening_coverage: 100.0%
  regulatory_reporting_timeliness: 100.0%
  audit_findings_remediated: 100.0%
```

---

## 🔍 Forensic Audit Capabilities

### Transaction Tracing
```sql
-- Example query for complete transaction history
SELECT 
    t.transaction_hash,
    t.block_number,
    t.timestamp,
    t.from_address,
    t.to_address,
    t.amount,
    t.event_type,
    u.kyc_status,
    u.risk_category
FROM transactions t
JOIN users u ON t.from_address = u.wallet_address
WHERE t.timestamp >= '2025-01-01'
    AND t.amount > 10000
ORDER BY t.timestamp DESC;
```

### Reserve Movement Tracking
```sql
-- Track all gold movements across the system
SELECT 
    r.movement_id,
    r.timestamp,
    r.movement_type,
    r.kg_amount,
    r.source_location,
    r.destination_location,
    r.authorization_signature,
    v.vault_provider
FROM reserve_movements r
JOIN vaults v ON r.vault_id = v.vault_id
WHERE r.timestamp >= '2024-01-01'
ORDER BY r.timestamp ASC;
```

### Anomaly Detection Queries
```sql
-- Detect unusual payout patterns
SELECT 
    user_address,
    COUNT(*) as payout_count,
    SUM(amount) as total_payouts,
    AVG(amount) as avg_payout,
    STDDEV(amount) as payout_stddev
FROM payouts 
WHERE payout_date >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
GROUP BY user_address
HAVING avg_payout > (
    SELECT AVG(amount) * 3 FROM payouts 
    WHERE payout_date >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
)
ORDER BY total_payouts DESC;
```

---

## 📊 Real-Time Monitoring Dashboard

### Key Metrics Display
```javascript
// Dashboard configuration for audit monitoring
const auditDashboard = {
  realTimeMetrics: [
    {
      name: "Coverage Ratio",
      query: "SELECT latest_coverage_ratio FROM reserve_oracle",
      threshold: { warning: 1.02, critical: 1.00 },
      updateFrequency: "1min"
    },
    {
      name: "Active Payouts", 
      query: "SELECT COUNT(*) FROM pending_payouts",
      threshold: { warning: 100, critical: 500 },
      updateFrequency: "5min"
    },
    {
      name: "Oracle Staleness",
      query: "SELECT TIMESTAMPDIFF(SECOND, last_update, NOW()) FROM oracle_feeds",
      threshold: { warning: 3600, critical: 7200 },
      updateFrequency: "1min"
    }
  ],
  
  auditAlerts: [
    {
      name: "Large Transaction Alert",
      condition: "amount > 50000",
      action: "immediate_notification",
      recipients: ["compliance@fth.com", "audit@fth.com"]
    },
    {
      name: "Sanctions Hit Alert", 
      condition: "sanctions_match = true",
      action: "freeze_account",
      recipients: ["legal@fth.com", "compliance@fth.com"]
    }
  ]
};
```

---

## 🔐 Audit Data Security & Retention

### Data Encryption & Storage
- **At Rest:** AES-256 encryption for all audit databases
- **In Transit:** TLS 1.3 for all audit data transmission
- **Key Management:** Hardware Security Modules (HSM) for encryption keys
- **Access Control:** Role-based access with multi-factor authentication

### Retention Policies
| Data Category | Retention Period | Storage Location | Access Level |
|---------------|------------------|------------------|--------------|
| Transaction Records | 7 years | Primary Database + Cold Storage | Auditor + Compliance |
| KYC Documents | 7 years post-relationship | Encrypted Archive | Compliance Only |
| Oracle Feed History | 2 years | Time-series Database | Operations Team |
| System Logs | 1 year | Log Aggregation System | Technical Team |
| Compliance Reports | Permanent | Regulatory Archive | Board + Regulators |

### Backup & Recovery
```yaml
backup_strategy:
  frequency: "daily"
  retention: "90 days hot, 7 years cold"
  encryption: "AES-256"
  verification: "weekly restore test"
  
disaster_recovery:
  rto_target: "4 hours"
  rpo_target: "1 hour" 
  backup_locations: ["primary_dc", "secondary_dc", "cloud_archive"]
  restore_priority: ["transaction_data", "kyc_records", "reserve_data"]
```

---

## 📞 Audit Support Contacts

### Internal Audit Team
- **Chief Audit Officer:** audit@futuretechholdings.com | +971-50-XXX-4001
- **Compliance Auditor:** compliance-audit@fth.com | +971-50-XXX-4002  
- **Technical Auditor:** tech-audit@fth.com | +971-50-XXX-4003

### External Auditors
- **Financial Audit:** PwC Middle East | +971-4-304-3100
- **Security Audit:** Trail of Bits | security@trailofbits.com
- **Compliance Audit:** KPMG UAE | +971-4-403-0300

### Regulatory Contacts
- **DMCC Compliance:** compliance@dmcc.ae | +971-4-424-7900
- **UAE FIU:** reporting@cbuae.ae | +971-2-691-9999
- **External Counsel:** Al Tamimi & Company | +971-4-364-1777

---

*Audit trail specifications are reviewed quarterly and updated based on regulatory requirements and operational needs.*

**Document Owner:** Chief Audit Officer  
**Next Review:** April 2025  
**Approval:** Audit Committee + Board of Directors