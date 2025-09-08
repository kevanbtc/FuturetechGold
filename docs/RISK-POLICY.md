# FTH-GOLD Risk Management Policy

**Version:** 1.0  
**Last Updated:** January 2025  
**Jurisdiction:** Dubai DMCC  

---

## 🎯 Executive Summary

This document outlines comprehensive risk management policies for the FTH-GOLD private placement program, covering commodity risk, operational risk, regulatory compliance, and protocol security measures.

---

## 📊 Risk Categories & Mitigation

### 1. Commodity & Market Risk

#### **Gold Price Volatility**
- **Risk:** Spot gold price fluctuations affecting token NAV vs. redemption value
- **Mitigation:** 
  - Fixed entry price ($20k) provides buffer vs. spot market
  - Monthly payouts decouple from spot price movements
  - Optional hedging via futures/options (see Hedging Policy below)
- **Monitoring:** Daily spot vs. entry price variance tracking

#### **Mining Production Risk** 
- **Risk:** Lower than projected kg production affecting payout sustainability
- **Mitigation:**
  - Diversified mine portfolio with NI 43-101 verified reserves
  - Conservative production estimates (P90 confidence)
  - Coverage ratio monitoring (≥100% reserves to issued tokens)
- **Escalation:** Coverage < 100% triggers auto-pause of payouts/issuance

#### **Refinery & Processing Risk**
- **Risk:** Refinery delays, assay disputes, or processing bottlenecks
- **Mitigation:**
  - Multiple refinery partnerships with SLA contracts
  - 30-day assay dispute resolution window
  - Force majeure insurance coverage
- **Monitoring:** Monthly processing throughput vs. targets

---

### 2. Hedging Policy

#### **Hedge Objectives**
- Protect mining production revenue stream
- Stabilize monthly payout capacity  
- Manage FX exposure (USD/local currencies)

#### **Hedge Instruments**
- **Gold Futures:** COMEX GC contracts for price protection
- **Options Collars:** Downside protection with upside participation
- **Forward Sales:** 12-month rolling hedge of projected production
- **FX Forwards:** Hedge non-USD operating expenses

#### **Hedge Limits**
- Maximum 80% of 12-month projected production
- No naked short positions
- Daily VAR limit: 2% of total program NAV
- Counterparty exposure: Max 25% with any single institution

#### **Hedge Execution**
- **Authority:** CFO + Risk Committee approval required
- **Documentation:** Trade confirmations logged on-chain via ProofOfGold.sol
- **P&L Flow:** Hedge gains/losses feed into PayoutRateOracle calculation
- **Reporting:** Monthly hedge performance review to token holders

---

### 3. Operational Risk

#### **Vault & Custody**
- **Provider:** [TBD - Brinks, Malca-Amit, or equivalent Tier 1]
- **Insurance:** $50M all-risk coverage per vault location
- **Segregation:** FTH-GOLD inventory separately allocated and marked
- **Audit Frequency:** Monthly physical reconciliation + bi-annual independent audit
- **Chain of Custody:** Sealed transport protocols with GPS tracking

#### **Key Personnel Risk**
- **Coverage:** Key-person insurance on technical and operational leads
- **Succession Planning:** Cross-trained backup personnel for all critical functions
- **Access Controls:** Multi-signature requirements for all protocol changes
- **Background Checks:** Enhanced due diligence on all personnel with system access

#### **Technology & Infrastructure**
- **Smart Contract Risk:** Formal verification + comprehensive test coverage
- **Oracle Risk:** Multi-source feeds with consensus mechanisms
- **Private Key Security:** Hardware wallets + multi-party computation
- **Business Continuity:** Hot/cold backups with 4-hour RTO target

---

### 4. Regulatory & Compliance Risk

#### **Licensing Compliance**
- **Primary License:** Dubai DMCC Precious Metals Trading License #[TBD]
- **Regulatory Reporting:** Monthly position reports to DMCC
- **Capital Requirements:** Maintain minimum AED 1M regulatory capital
- **Audit Requirements:** Annual DMCC-approved auditor review

#### **Cross-Border Compliance**
- **Investor Qualification:** Private placement exemptions verified per jurisdiction
- **Tax Reporting:** Beneficial ownership reporting where required
- **Sanctions Screening:** Real-time OFAC/UN/EU sanctions list monitoring
- **Travel Rule:** >$3k payout metadata collection and transmission

#### **Securities Law Risk**
- **Token Classification:** Utility token with commodity delivery rights (not security)
- **Transfer Restrictions:** Private placement transfer limitations enforced on-chain
- **Disclosure Requirements:** Risk factors prominently disclosed in offering materials
- **Investor Suitability:** Accredited/professional investor verification required

---

### 5. Protocol & Smart Contract Risk

#### **Code Security**
- **Audit Coverage:** Minimum 2 independent security audits before mainnet
- **Bug Bounty:** $100k+ reward program for critical vulnerability disclosure
- **Upgrade Mechanisms:** Timelock + multi-sig governance for contract changes
- **Circuit Breakers:** Auto-pause mechanisms on coverage breach or oracle failure

#### **Economic Attack Vectors**
- **Flash Loan Attacks:** Read-only reentrancy guards on all price/balance calls
- **Oracle Manipulation:** Price feeds with TWAP smoothing and deviation limits
- **Governance Attacks:** Multi-sig threshold requires 60%+ consensus
- **Liquidity Attacks:** Payout rate caps prevent excessive token dilution

#### **Operational Security**
- **Multi-Signature Requirements:** 3-of-5 for admin functions, 2-of-3 for routine ops
- **Role Separation:** Oracle writers, rate setters, and pausers are separate entities
- **Access Logging:** All administrative actions logged on-chain with timestamps
- **Incident Response:** Pre-defined escalation procedures with 2-hour response SLA

---

## 🚨 Incident Response Procedures

### Level 1: Coverage Breach (< 100%)
1. **Auto-Actions:** CircuitBreaker.sol pauses payouts and new issuance
2. **Notification:** Immediate alert to all token holders via dashboard
3. **Investigation:** 24-hour root cause analysis and remediation plan
4. **Resolution:** Resume operations only after coverage restored to ≥102%

### Level 2: Oracle Failure
1. **Auto-Actions:** System falls back to manual admin attestation mode
2. **Response Time:** 6-hour maximum to restore automated oracle feeds  
3. **Validation:** Cross-reference against backup data sources
4. **Documentation:** Incident report filed with regulator within 48 hours

### Level 3: Smart Contract Exploit
1. **Emergency Pause:** All contract interactions halted immediately
2. **Assessment:** Technical team + external auditors assess impact
3. **Communication:** Token holder notification within 4 hours
4. **Recovery:** Migration to new contracts if necessary, with token holder vote

### Level 4: Regulatory Action
1. **Legal Counsel:** Immediate engagement of Dubai regulatory counsel
2. **Compliance Review:** Full audit of affected operations and procedures
3. **Stakeholder Communication:** Transparent updates to all participants
4. **Remediation:** Implement required changes to maintain license compliance

---

## 📊 Risk Monitoring & Reporting

### Daily Monitoring
- Coverage ratio (target: ≥105%)
- Oracle feed health and deviation alerts
- Payout rate calculation inputs
- Sanctions list updates and screening results

### Weekly Reporting  
- Production vs. forecast variance
- Hedge position P&L and effectiveness
- Vault reconciliation and inventory movements
- System performance metrics and uptime

### Monthly Board Review
- Comprehensive risk dashboard review
- Incident summary and lessons learned
- Policy updates and parameter adjustments
- External audit findings and remediation status

### Quarterly Assessments
- Full risk framework review and stress testing
- Regulatory compliance audit and certification
- Insurance coverage adequacy assessment
- Business continuity plan testing and updates

---

## 📋 Policy Governance

### Risk Committee
- **Composition:** 3 board members + CRO + external risk advisor
- **Meeting Frequency:** Monthly (ad-hoc for Level 2+ incidents)
- **Authority:** Approve risk limits, policy changes, and escalation procedures
- **Reporting:** Quarterly risk report to full board and token holders

### Policy Updates
- **Review Cycle:** Semi-annual policy review and update process
- **Approval Process:** Risk committee recommendation → Board approval
- **Implementation:** 30-day notice period for material changes
- **Version Control:** All versions maintained with change logs

### External Validation
- **Independent Review:** Annual risk assessment by external consultant
- **Regulatory Review:** DMCC compliance review and sign-off
- **Insurance Review:** Annual coverage adequacy assessment with underwriters
- **Audit Validation:** Risk controls testing by external auditors

---

## ⚠️ Risk Disclosures for Token Holders

### Material Risks
- **Commodity Price Risk:** Gold prices may decline, affecting redemption value
- **Production Risk:** Mining operations may produce less than projected
- **Regulatory Risk:** Licensing or regulatory changes may affect operations
- **Technology Risk:** Smart contract bugs or exploits may cause losses
- **Liquidity Risk:** Secondary market may be limited or non-existent

### Risk Factors Not Covered by Insurance
- Market losses due to gold price volatility
- Regulatory changes affecting token transferability  
- Force majeure events affecting multiple mine sites simultaneously
- Technology obsolescence or protocol migration costs

---

*This risk policy is reviewed semi-annually and updated as needed. Last review: January 2025*

**Contact:** risk@futuretechholdings.com | Dubai DMCC License #[TBD]