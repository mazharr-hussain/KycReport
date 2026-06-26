# KYC Application — Compliance Validation Report

**Standard References:** FATF 40 Recommendations, Basel Committee KYC Guidelines, EU 6AMLD, FATF Guidance on Digital ID, OFAC/UN Sanctions Standards  
**Assessment Date:** June 2026  
**Application:** Qatari Diar KYC Report Management System  

**Legend:** ✅ Implemented | ⚠️ Partial / Weak | ❌ Missing / Not Found

---

## Executive Summary

The application covers the **core KYC onboarding workflow** competently and provides a solid foundation for compliance. However, it is missing several **critical controls** required by modern AML/KYC standards — particularly around **ongoing monitoring**, **sanctions screening integration**, **PEP identification**, **data retention policy enforcement**, and **risk-based triggers**. The gaps are significant enough that the system should be considered a **workflow management tool**, not a fully self-contained KYC compliance solution without compensating manual controls.

---

## Section 1: Customer Identification Program (CIP)

*FATF Recommendations 10 & 22 | Basel KYC Principle 2*

| Requirement | Standard Mandate | Status | Finding |
|---|---|---|---|
| Legal name capture | Mandatory for all customers | ✅ | `spName` in SearchPattern |
| Date of birth (natural persons) | Mandatory | ✅ | `qd_natural_person_dob` |
| Nationality | Mandatory | ✅ | `qd_natural_person_nationality` |
| Government-issued ID number | Mandatory | ✅ | `qd_person_id` (passport/ID) |
| ID expiry date | Good practice | ✅ | Captured for UBOs (`ubo_id_exp_date`) — not captured at entity level for natural persons |
| Country of residence / domicile | Required | ⚠️ | Only `spCountryLoc` (country of location) — no separate residence vs. nationality distinction |
| Address / place of business | Required for legal entities | ⚠️ | `qd_sp_head_quarters` is free text — no structured address (street, city, postal code) |
| Legal entity registration number | Mandatory for corporates | ✅ | `qd_legal_reg_no` |
| Country of incorporation | Required | ⚠️ | `spCountryLoc` likely serves this but is not labeled distinctly |
| Nature of business / purpose of relationship | Required | ❌ | No field for business purpose, industry sector, or nature of relationship |
| Source of funds / wealth | Required for EDD | ❌ | No field exists anywhere in the schema |
| Verification method / source of ID | Required | ⚠️ | UBO has `ubo_source` field but no equivalent at entity (SearchPattern) level |
| Document verified date | Good practice | ❌ | No verification date recorded for identity documents |

**Score: 7/13 — Partial**

---

## Section 2: Ultimate Beneficial Ownership (UBO)

*FATF Recommendation 24 | EU 5AMLD Article 30 | Basel KYC Principle 2.2*

| Requirement | Standard Mandate | Status | Finding |
|---|---|---|---|
| Identify natural persons owning >25% | Mandatory | ✅ | UBO table captures beneficial owners |
| UBO name | Mandatory | ✅ | `ubo_name` |
| UBO nationality | Mandatory | ✅ | `ubo_nationality` |
| UBO date of birth | Mandatory | ✅ | `ubo_dob` |
| UBO ID number | Mandatory | ✅ | `ubo_idno` |
| UBO ID expiry | Required | ✅ | `ubo_id_exp_date` |
| UBO percentage of ownership / shareholding | Mandatory | ❌ | No ownership percentage field in Ubo table |
| UBO country of residence | Required | ❌ | No separate residence field — only captured at entity level |
| UBO address | Required | ❌ | No address field in Ubo table |
| Control mechanism (direct/indirect) | Required | ❌ | No field to describe HOW control is exercised |
| Authorized signatories (non-UBO) | Good practice | ✅ | `ubo_type` = "UBO / Authorized Signatories" |
| Corporate structure diagram / ownership chain | Required for complex entities | ❌ | No organizational chart or ownership chain capability |
| Verification of UBO identity | Required | ⚠️ | `ubo_source` exists but is free text — no document upload linked to specific UBO |

**Score: 7/13 — Partial**

---

## Section 3: Risk-Based Approach (RBA)

*FATF Recommendation 1 | Basel KYC Principle 1*

| Requirement | Standard Mandate | Status | Finding |
|---|---|---|---|
| Risk classification (Low/Medium/High) | Mandatory | ✅ | Implemented at both KYC and entity level |
| Risk documented with justification | Required | ⚠️ | `qd_final_conclusion` and `spConclusion` exist but are free text — no structured risk factors |
| Geographic risk factor | Required | ⚠️ | Country captured but no FATF/OFAC high-risk country flagging |
| Industry/sector risk factor | Required | ❌ | No industry or sector field |
| Product/service risk factor | Required | ❌ | No product or transaction type risk captured |
| PEP (Politically Exposed Person) flag | Mandatory | ❌ | No dedicated PEP flag on entity or UBO — only free-text in results |
| Adverse media flag | Good practice | ❌ | No structured adverse media field |
| Risk scoring / weighted calculation | Best practice | ❌ | Risk level is manually entered — no automated scoring engine |
| Re-assessment triggers defined | Required | ❌ | No trigger rules (e.g., transaction threshold, new adverse info) |
| SDD / EDD criteria explicitly enforced | Required | ⚠️ | Types exist (Simplified/Enhanced) but no system-enforced criteria for when each applies |

**Score: 3/10 — Weak**

---

## Section 4: Sanctions & Adverse Screening

*FATF Recommendation 6 | OFAC/UN/EU Consolidated Lists*

| Requirement | Standard Mandate | Status | Finding |
|---|---|---|---|
| Sanctions list screening (OFAC, UN, EU) | Mandatory | ❌ | No integration with any sanctions database |
| PEP list screening | Mandatory | ❌ | No PEP database integration |
| Adverse media screening | Required for EDD | ❌ | No media/news screening integration |
| Screening result recorded | Mandatory | ⚠️ | `spResults` and `ubo_results` fields exist for free-text results — but no structured pass/fail/match |
| Screening source documented | Required | ⚠️ | `ubo_source` exists for UBOs only |
| Hit resolution process | Required | ❌ | No structured false-positive resolution workflow |
| Screening date recorded | Required | ❌ | No date field for when screening was performed |
| Periodic re-screening | Required | ❌ | No scheduled re-screening capability |
| Watchlist match escalation | Required | ❌ | No automated alert or escalation for matches |

> **Critical Gap:** The system treats screening as a manual, free-text entry process. There is no integration with any external sanctions or PEP database. Compliance officers type results manually into `spResults` — creating significant human error risk and auditability concerns.

**Score: 0/9 — Critical Gap**

---

## Section 5: Due Diligence Process

*FATF Recommendations 10, 12, 13 | Basel KYC Principle 2*

| Requirement | Standard Mandate | Status | Finding |
|---|---|---|---|
| CDD (Customer Due Diligence) process | Mandatory | ✅ | Standard KYC workflow implemented |
| SDD (Simplified Due Diligence) process | Mandatory | ✅ | "Simplified KYC" type exists |
| EDD (Enhanced Due Diligence) for high-risk | Mandatory | ⚠️ | "Enhanced KYC" type exists but no additional mandatory fields enforced for EDD |
| Senior management approval for high-risk | Required | ⚠️ | Two-level workflow provides some oversight but not explicitly tied to risk level |
| Correspondent relationship assessment | Required for banks | ❌ | No correspondent due diligence module |
| Ongoing due diligence / periodic review | Mandatory | ❌ | No review cycle, expiry date, or re-KYC scheduling |
| Next review date | Required | ❌ | No `next_review_date` or `kyc_expiry_date` field in schema |
| Transaction monitoring integration | Required | ❌ | No transaction data or monitoring capability |
| Relationship purpose documented | Required | ❌ | No field for intended relationship or transaction purpose |

**Score: 3/9 — Weak**

---

## Section 6: Approval Workflow & Governance

*Basel KYC Principle 3 | FATF R.2*

| Requirement | Standard Mandate | Status | Finding |
|---|---|---|---|
| Maker-checker separation | Mandatory | ✅ | Contributor creates; Approver reviews — cannot self-approve |
| Multi-level sign-off | Required for high-risk | ✅ | Two-level workflow (L1 + L2/RFI) |
| Approval with reason/comments | Required | ✅ | `KycWfComments` and `ProcessLog` capture this |
| Rejection with documented reason | Required | ✅ | Rejection comments captured in ProcessLog |
| RFI / information request capability | Best practice | ✅ | RFI workflow with comments implemented |
| Escalation path for high-risk | Required | ⚠️ | Both levels handle all risk types — no automatic escalation for High risk to senior management |
| Approval delegation controls | Required | ❌ | No delegation or out-of-office substitute mechanism |
| Four-eyes principle enforcement | Mandatory | ✅ | System enforces different user approval |
| Override / exception process | Required | ❌ | No exception handling workflow for deadline overrides |
| Approval SLA / turnaround tracking | Best practice | ❌ | No SLA timer, aging report, or deadline field |

**Score: 7/10 — Good**

---

## Section 7: Audit Trail & Record Keeping

*FATF Recommendation 11 | Basel KYC Principle 4 | EU GDPR Article 30*

| Requirement | Standard Mandate | Status | Finding |
|---|---|---|---|
| Audit log of all workflow actions | Mandatory | ✅ | ProcessLog captures all state transitions |
| Timestamp on all log entries | Mandatory | ✅ | `log_date` in ProcessLog |
| User attribution on all actions | Mandatory | ✅ | `log_user` in ProcessLog |
| Comment/reason recorded with action | Required | ✅ | `kyc_comments` in ProcessLog |
| Immutable log (insert-only) | Mandatory | ✅ | No update/delete endpoints on ProcessLog |
| Document retention (5-year minimum) | Mandatory | ⚠️ | Documents stored on filesystem but no retention policy enforcement, no automatic purge/archive |
| Record retention period per record | Required | ❌ | No `retention_expiry` or archival date field |
| Data export for regulatory requests | Required | ❌ | PDF export only — no structured data export (CSV, XML) for regulators |
| GDPR right to erasure handling | Required | ❌ | No data deletion workflow or consent management |
| Version history for edited records | Required | ✅ | Entity versioning (`qd_version_no`) implemented |
| Change log for KYC edits | Required | ⚠️ | ProcessLog captures workflow changes but not field-level edit history |

**Score: 8/11 — Good**

---

## Section 8: User Access & Security Controls

*Basel KYC Principle 5 | ISO 27001 | NIST*

| Requirement | Standard Mandate | Status | Finding |
|---|---|---|---|
| Role-based access control | Mandatory | ✅ | Three roles with separate queues |
| Authentication (username + password) | Mandatory | ✅ | Login implemented |
| Password hashing | Mandatory | ❌ | Password stored in plain text or weakly encrypted in Login table |
| Multi-factor authentication (MFA) | Required for sensitive systems | ❌ | No MFA capability |
| Session management | Required | ✅ | 30-minute timeout in web.xml |
| Failed login lockout | Required | ❌ | No lockout mechanism visible |
| User activity logging | Required | ⚠️ | ProcessLog tracks KYC actions but not login/logout events |
| Privileged access controls | Required | ❌ | Admin role has unrestricted access — no privileged access review |
| Password expiry policy | Required | ❌ | No password expiry mechanism |
| IP restriction / access from trusted networks only | Best practice | ❌ | No network-level restriction in app config |

**Score: 4/10 — Weak**

---

## Section 9: Ongoing Monitoring

*FATF Recommendation 10(d) | Basel KYC Principle 2.4*

| Requirement | Standard Mandate | Status | Finding |
|---|---|---|---|
| Periodic KYC review scheduling | Mandatory | ❌ | No review cycle or expiry date on KYC records |
| Risk-triggered re-review | Required | ❌ | No trigger mechanism for re-KYC |
| Transaction monitoring alerts | Required for financial institutions | ❌ | No transaction data integration |
| Change in circumstances detection | Required | ❌ | No trigger for name changes, ownership changes, adverse news |
| KYC expiry date | Best practice | ❌ | No `kyc_expiry_date` field in schema |
| Dashboard for overdue KYCs | Required | ❌ | Charts exist but no aging/overdue KYC view |
| Annual review reporting | Required | ❌ | No scheduled reporting capability |

**Score: 0/7 — Critical Gap**

---

## Section 10: Reporting & Suspicious Activity

*FATF Recommendation 20 | FINTRAC / FinCEN STR Requirements*

| Requirement | Standard Mandate | Status | Finding |
|---|---|---|---|
| Suspicious Activity Report (SAR) capability | Mandatory | ❌ | No SAR module or flag |
| STR (Suspicious Transaction Report) | Mandatory | ❌ | No STR workflow |
| Internal escalation for suspicious findings | Required | ❌ | No dedicated escalation path for suspicion |
| MLRO (Money Laundering Reporting Officer) role | Required | ❌ | No MLRO role in the system |
| SAR filing deadline tracking | Required | ❌ | Not applicable — no SAR module |
| Regulatory reporting (FATF, Central Bank) | Required | ❌ | No regulatory export format |

**Score: 0/6 — Critical Gap**

---

## Consolidated Gap Summary

| Domain | Score | Rating |
|---|---|---|
| Customer Identification Program (CIP) | 7/13 | ⚠️ Partial |
| Ultimate Beneficial Ownership (UBO) | 7/13 | ⚠️ Partial |
| Risk-Based Approach (RBA) | 3/10 | ❌ Weak |
| Sanctions & Adverse Screening | 0/9 | ❌ Critical |
| Due Diligence Process | 3/9 | ❌ Weak |
| Approval Workflow & Governance | 7/10 | ✅ Good |
| Audit Trail & Record Keeping | 8/11 | ✅ Good |
| User Access & Security Controls | 4/10 | ❌ Weak |
| Ongoing Monitoring | 0/7 | ❌ Critical |
| Suspicious Activity Reporting | 0/6 | ❌ Critical |
| **TOTAL** | **39/88** | **44% — Partially Compliant** |

---

## Priority Remediation Roadmap

### Priority 1 — Critical (Regulatory Risk)

| Gap | Recommended Fix |
|---|---|
| No sanctions/PEP screening integration | Integrate with a third-party screening API (e.g., Refinitiv World-Check, Dow Jones, ComplyAdvantage). Add `screening_date`, `screening_source`, `screening_status` (Pass/Flag/Fail) fields to SearchPattern and Ubo tables |
| Passwords stored in plain text | Implement BCrypt hashing on `userPass` field immediately |
| No ongoing monitoring / KYC expiry | Add `kyc_expiry_date`, `next_review_date` to Kyc table. Build a scheduled job to flag overdue reviews |
| No SAR/STR workflow | Add a minimal SAR flag + MLRO escalation path to the approval workflow |

### Priority 2 — High (Compliance Gaps)

| Gap | Recommended Fix |
|---|---|
| UBO ownership percentage missing | Add `ubo_ownership_pct` (DECIMAL) field to Ubo table |
| No PEP flag on entity/UBO | Add `is_pep` (Y/N) Boolean field to SearchPattern and Ubo tables |
| Source of funds/wealth missing | Add `source_of_funds` and `source_of_wealth` text fields to Kyc table |
| EDD not enforcing additional fields | When `qd_subject = 'Enhanced KYC'`, make source_of_funds and senior management approval mandatory |
| No structured address | Replace `qd_sp_head_quarters` free text with structured fields: street, city, country, postal code |
| Risk scoring not automated | Implement a weighted risk score calculator based on country risk, PEP status, industry, and business type |

### Priority 3 — Medium (Best Practice)

| Gap | Recommended Fix |
|---|---|
| No MFA | Add TOTP/OTP second factor for Approver and Admin roles |
| No login audit log | Log all login/logout events to a new `LoginAuditLog` table |
| No failed login lockout | Implement account lockout after 5 failed attempts |
| No data retention policy | Add `retention_expiry_date` to Kyc table; implement archival job |
| No regulatory data export | Add CSV/XML export on KYC list page for regulatory submissions |
| No SLA tracking | Add `submission_date` and `target_approval_date` to Kyc table; add aging indicator to approval queue |

---

## What the System Does Well

The following areas are implemented correctly and meet standard requirements:

- Multi-level approval workflow with maker-checker separation
- Immutable audit trail via ProcessLog (insert-only)
- UBO capture for legal entities (names, IDs, nationality, DOB)
- Entity versioning for change history
- Three-tier due diligence typing (SDD/AdHoc/EDD)
- Risk level classification (Low/Medium/High) at both record and entity level
- Document upload and attachment tracking
- Comment and RFI workflow with full history
- Role-based access with separate queues per role
- PDF export with watermark status indication

---

*Compliance validation performed against: FATF 40 Recommendations (2023 update), Basel Committee Sound Practices for the Management of Operational Risk, EU 6th Anti-Money Laundering Directive (6AMLD), and general international KYC/AML standards.*
