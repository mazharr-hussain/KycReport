# Version 3 — System Requirements Specification
# Improved KYC System — Best Practice

**Document Type:** System Requirements Specification (SRS)  
**Audience:** Developers, Solution Architects, QA Engineers  
**Standards Applied:** FATF 40 | Basel KYC | EU 6AMLD | ISO 31000  
**Purpose:** Complete functional and non-functional requirements for the improved system  

---

## 1. System Context

The improved KYC system replaces the current JSF application and the surrounding manual processes (Excel, email, local folders). It is a web-based application serving three distinct user groups:

- **Requestors** — any Qatari Diar employee who needs a KYC performed
- **Compliance Team** — the team that conducts research, creates entities and reports
- **Management** — senior officers who approve and have oversight visibility

---

## 2. Functional Requirements

### Module 1: KYC Necessity Engine

| ID | Requirement | Priority |
|---|---|---|
| M1-FR-01 | System exposes a rules engine that evaluates: entity type, ownership category, relationship type, financial involvement flag, related party flag | Must |
| M1-FR-02 | Engine returns: KYC_REQUIRED (Y/N) and the reason code | Must |
| M1-FR-03 | Rules must be configurable by Admin without code change | Should |
| M1-FR-04 | All evaluations logged: inputs, output, timestamp, user | Must |
| M1-FR-05 | If KYC not required: a Waiver record is created with document attachments | Must |
| M1-FR-06 | Waiver records are searchable and reportable | Should |

**Decision Logic (initial rules set):**

```
KYC Required = YES if ANY of:
  financial_involvement IN (CURRENT, PROPOSED)
  related_party_flag = Y
  ownership_category IN (FOREIGN, NON_QATARI_PERSON)
  relationship_type IN (INVESTOR, JV_PARTNER)
  ownership_category = QATAR_MINORITY AND relationship_type IN (SUPPLIER, CONTRACTOR)

KYC Required = NO otherwise
```

---

### Module 2: Digital Intake Portal

| ID | Requirement | Priority |
|---|---|---|
| M2-FR-01 | Separate intake interface accessible to all company employees (not just compliance team) | Must |
| M2-FR-02 | Intake form captures: requestor (auto-populated from logged-in user), department (auto-populated), entity name, entity type, entity country, ownership category, relationship type, financial involvement, related party declaration | Must |
| M2-FR-03 | Intake form shows a jurisdiction-aware document checklist based on entity type + country | Should |
| M2-FR-04 | Multiple file upload supported on intake form with document type classification per file | Must |
| M2-FR-05 | On submission: unique Intake Reference generated, case record created, compliance team notified | Must |
| M2-FR-06 | Requestor can view status of their own submissions (status tracker) | Must |
| M2-FR-07 | Compliance officer can issue structured document requests with deadline; requestor responds via portal | Must |
| M2-FR-08 | All document request rounds tracked with timestamps | Must |
| M2-FR-09 | Compliance officer marks "Documents Complete" — this timestamp is the KPI start point | Must |

---

### Module 3: Duplicate Entity Detection

| ID | Requirement | Priority |
|---|---|---|
| M3-FR-01 | Before creating a new entity, system performs fuzzy name match against existing entities | Must |
| M3-FR-02 | Fuzzy match uses Jaro-Winkler similarity — threshold configurable (default 85%) | Should |
| M3-FR-03 | Exact match on legal registration number triggers mandatory duplicate warning | Must |
| M3-FR-04 | Exact match on ID number (natural person) triggers mandatory duplicate warning | Must |
| M3-FR-05 | Results shown as a list: entity name, type, risk level, last screened date, version | Must |
| M3-FR-06 | Officer can: select existing entity, create new version of existing, or proceed with new record with justification | Must |
| M3-FR-07 | Alias names (trading names, former names, Arabic names) included in search | Should |

---

### Module 4: Entity Management

| ID | Requirement | Priority |
|---|---|---|
| M4-FR-01 | Natural person fields: title, first/middle/last name, nationality (primary + secondary), country of residence, date of birth (validated), ID type, ID number, ID issuing country, ID expiry | Must |
| M4-FR-02 | Legal entity fields: entity name, date of incorporation, country of incorporation (distinct from operating country), country of operation, industry/sector, registered address (structured), operating address, legal registration number, website | Must |
| M4-FR-03 | Screening evidence fields (per entity): screening date, screening source (dropdown), screening reference, match status (enum: NO_MATCH/POTENTIAL_MATCH/CONFIRMED_MATCH/FALSE_POSITIVE), is_pep (Y/N), is_sanctioned (Y/N), adverse_media flag (Y/N), findings narrative (long text), false positive resolution note | Must |
| M4-FR-04 | UBO fields (per participant): participant type (UBO/AUTH_SIGNATORY/DIRECTOR/SHAREHOLDER), full name, nationality, country of residence, DOB, ID type, ID number, ID issuing country, ID expiry, ownership percentage (numeric 0-100), control type (DIRECT/INDIRECT/BOTH), residential address, screening evidence (same structure as entity) | Must |
| M4-FR-05 | Entity versioning: any edit creates a new version; previous version preserved in SUPERSEDED status | Must |
| M4-FR-06 | Version history viewable per entity | Must |
| M4-FR-07 | When confirmed match or PEP=Y recorded: system enforces EDD path on linked report | Must |

---

### Module 5: Risk Pre-Assessment Engine

| ID | Requirement | Priority |
|---|---|---|
| M5-FR-01 | On opening a new KYC report, system pre-computes risk indicators: geographic risk (from country FATF tier), entity type risk (state-owned → elevated), structural complexity risk, historical flags | Should |
| M5-FR-02 | System suggests risk level (LOW/MEDIUM/HIGH) based on indicators | Should |
| M5-FR-03 | Officer can override — override requires documented justification (text field, mandatory) | Must |
| M5-FR-04 | Country risk tiers configurable by admin (FATF list updated periodically) | Must |

---

### Module 6: KYC Report

| ID | Requirement | Priority |
|---|---|---|
| M6-FR-01 | Report creation auto-populates from linked intake and entity records — officer verifies, does not re-type | Must |
| M6-FR-02 | KYC type selection: SIMPLIFIED / ADHOC / ENHANCED | Must |
| M6-FR-03 | When ENHANCED selected: source_of_funds and source_of_wealth fields become mandatory | Must |
| M6-FR-04 | When HIGH risk selected: system forces ENHANCED KYC type (cannot select SIMPLIFIED) | Must |
| M6-FR-05 | Conclusion template selector: admin-configurable templates per risk level; selected template pre-populates conclusion field | Must |
| M6-FR-06 | Request date validation: must be a valid calendar date, not in future, not > 2 years in past | Must |
| M6-FR-07 | ID expiry validation: warn if expired, block if expired > 6 months | Must |
| M6-FR-08 | SLA indicator computed and displayed: days elapsed vs target by KYC type | Should |
| M6-FR-09 | Save as Draft: no workflow trigger | Must |
| M6-FR-10 | Submit: triggers approval workflow | Must |
| M6-FR-11 | KPI timestamp captured: submitted_date on submit action | Must |

---

### Module 7: Approval Workflow

| ID | Requirement | Priority |
|---|---|---|
| M7-FR-01 | LOW risk: L1 approval only required | Must |
| M7-FR-02 | MEDIUM/HIGH risk: L1 then L2 required | Must |
| M7-FR-03 | Contributor cannot approve their own submission | Must |
| M7-FR-04 | Delegation: each approver has a pre-configured deputy; if primary is marked on-leave, deputy receives tasks automatically | Must |
| M7-FR-05 | Approver can: Approve / RFI / Reject at each level | Must |
| M7-FR-06 | RFI: approver selects RFI category + enters comment; report returns to contributor; contributor responds and resubmits | Must |
| M7-FR-07 | All actions logged to Process Log (immutable) | Must |
| M7-FR-08 | Comments stored with workflow status at time of posting | Must |
| M7-FR-09 | SAR Gate at L2: approver must answer Y/N before approving; if Y → SAR escalation path activated | Must |
| M7-FR-10 | SAR escalation: approval paused, Head of Compliance and Admin notified | Must |
| M7-FR-11 | Final approval: PDF generated, requestor notified with PDF attached, record sealed | Must |
| M7-FR-12 | Next review date set automatically: 12/24/36 months by HIGH/MEDIUM/LOW risk | Must |
| M7-FR-13 | Approver notification sent when report enters their queue | Must |

---

### Module 8: Document Management

| ID | Requirement | Priority |
|---|---|---|
| M8-FR-01 | Documents stored at case level from intake — attached to report automatically | Must |
| M8-FR-02 | Additional documents can be uploaded at any workflow stage | Must |
| M8-FR-03 | Document metadata: name, type, upload date, uploaded by, associated workflow stage | Must |
| M8-FR-04 | Documents viewable inline (PDF rendered in browser) | Must |
| M8-FR-05 | Documents served via controlled access — not direct file URLs | Must |
| M8-FR-06 | Retention policy: records must be held for minimum 5 years post-approval | Must |

---

### Module 9: Notifications

| ID | Requirement | Priority |
|---|---|---|
| M9-FR-01 | Email notification: intake received (to compliance team) | Must |
| M9-FR-02 | Email notification: documents incomplete (to requestor with checklist) | Must |
| M9-FR-03 | Email notification: case assigned (to contributor) | Must |
| M9-FR-04 | Email notification: report submitted for approval (to active approver) | Must |
| M9-FR-05 | Email notification: RFI issued (to contributor) | Must |
| M9-FR-06 | Email notification: RFI responded (to approver) | Must |
| M9-FR-07 | Email notification: final approval complete with PDF attached (to requestor + contributor) | Must |
| M9-FR-08 | Email notification: rejection with reason (to requestor + contributor) | Must |
| M9-FR-09 | Email notification: SAR flagged (to Compliance Head + Admin) | Must |
| M9-FR-10 | Email notification: KYC review due in 60 days (to contributor) | Should |
| M9-FR-11 | Email notification: KYC review overdue (to contributor + manager) | Must |
| M9-FR-12 | Email notification: SLA breach on open report (to manager) | Should |
| M9-FR-13 | Email templates must be configurable without code change | Must |

---

### Module 10: KPI and Reporting

| ID | KPI | Computed From |
|---|---|---|
| M10-KPI-01 | Total KYCs by period (month/quarter/year) | Count of reports with submitted_date in period |
| M10-KPI-02 | Average turnaround time | AVG(final_approval_date - docs_complete_date) |
| M10-KPI-03 | SLA compliance rate | % completed within target days by KYC type |
| M10-KPI-04 | KYCs by risk level | Count by risk_level |
| M10-KPI-05 | KYCs by contributor | Count grouped by contributor |
| M10-KPI-06 | First-time approval rate | % with zero RFI rounds |
| M10-KPI-07 | RFI rate | % with ≥ 1 RFI |
| M10-KPI-08 | Overdue open cases | Count of submitted reports past SLA target |
| M10-KPI-09 | Pending reviews (overdue renewal) | Count of approved reports past next_review_date |

| ID | Requirement | Priority |
|---|---|---|
| M10-FR-01 | Live KPI dashboard visible to Manager and Admin roles without data export | Must |
| M10-FR-02 | KPIs computed in real-time from database timestamps | Must |
| M10-FR-03 | Interactive report with multi-criteria filtering: risk, type, contributor, date range, status | Must |
| M10-FR-04 | PDF report generation for any KYC record | Must |
| M10-FR-05 | Draft reports watermarked; approved reports have no draft watermark | Must |
| M10-FR-06 | Overdue report list (past SLA, past review date) | Must |

---

### Module 11: User & Access Management

| ID | Requirement | Priority |
|---|---|---|
| M11-FR-01 | Roles: REQUESTOR, CONTRIBUTOR, APPROVER_L1, APPROVER_L2, ADMIN | Must |
| M11-FR-02 | Role determines: accessible pages, accessible actions, visible records | Must |
| M11-FR-03 | Contributor sees only their own drafts and RFI'd reports | Must |
| M11-FR-04 | Approver sees reports at their workflow level | Must |
| M11-FR-05 | Requestor sees only their own intake submissions and status | Must |
| M11-FR-06 | Admin can create, edit, deactivate users | Must |
| M11-FR-07 | Admin can configure deputy per approver | Must |
| M11-FR-08 | Admin can mark approver as on leave (triggers deputy activation) | Must |
| M11-FR-09 | Delegation log: all activation/deactivation events with timestamp and admin user | Must |

---

## 3. Non-Functional Requirements

| ID | Category | Requirement |
|---|---|---|
| NFR-01 | Security | Passwords must be hashed using BCrypt or Argon2 — plain text storage prohibited |
| NFR-02 | Security | Documents served via controlled access procedure — no direct file path URLs |
| NFR-03 | Security | All form inputs sanitised; parameterised queries only — no string concatenation in SQL |
| NFR-04 | Security | Session expires after 30 minutes of inactivity |
| NFR-05 | Security | MFA required for APPROVER_L2 and ADMIN roles |
| NFR-06 | Security | Row-level access control: users see only authorised records |
| NFR-07 | Data Integrity | All date fields validated: must be valid calendar date, cannot be future, within plausible range |
| NFR-08 | Data Integrity | ID expiry dates: warning if < 90 days to expiry; block if already expired > 6 months |
| NFR-09 | Data Integrity | Ownership percentages: numeric 0–100, validated |
| NFR-10 | Audit | Process Log is insert-only — no update or delete operations permitted |
| NFR-11 | Audit | Every DML operation on KYC tables captures created_by / updated_by / timestamp |
| NFR-12 | Availability | Nightly monitoring job must not interfere with daytime operations |
| NFR-13 | Performance | KYC list pages must load within 3 seconds for up to 10,000 records |
| NFR-14 | Retention | KYC records, documents, and audit logs retained for minimum 5 years |
| NFR-15 | Scalability | Architecture must support up to 50 concurrent compliance users |

---

## 4. Data Requirements — Additional Fields Over V1

| Table | New Field | Type | Reason |
|---|---|---|---|
| Entity | `screening_date` | DATE | Evidence of when screening occurred |
| Entity | `screening_source` | VARCHAR | Which database was consulted |
| Entity | `screening_ref` | VARCHAR | Database case reference |
| Entity | `match_status` | ENUM | Structured result (not free text) |
| Entity | `is_pep` | BOOLEAN | PEP flag — explicit field |
| Entity | `is_sanctioned` | BOOLEAN | Sanctions match flag |
| Entity | `adverse_media_flag` | BOOLEAN | Adverse media flag |
| Entity | `false_positive_reason` | TEXT | Justification when dismissing a match |
| Entity | `industry_sector` | VARCHAR | Risk factor for RBA |
| Entity | `country_of_incorp` | VARCHAR | Distinct from operating country |
| UBO | `ownership_percentage` | NUMERIC | Mandatory for UBO type |
| UBO | `control_type` | ENUM | DIRECT/INDIRECT/BOTH |
| UBO | `country_of_residence` | VARCHAR | Separate from nationality |
| UBO | (all screening fields) | — | Same as entity |
| Report | `source_of_funds` | TEXT | Mandatory for EDD |
| Report | `source_of_wealth` | TEXT | Mandatory for EDD |
| Report | `risk_justification` | TEXT | Required when overriding system suggestion |
| Report | `sar_flag` | BOOLEAN | SAR gate outcome |
| Report | `next_review_date` | DATE | Auto-set on approval |
| Report | `docs_complete_date` | DATE | KPI start point |
| Report | `submitted_date` | TIMESTAMP | KPI: submission clock |
| Report | `final_approval_date` | TIMESTAMP | KPI: completion clock |
| Intake | (new table) | — | Structured intake replacing email |
| User | `is_on_leave` | BOOLEAN | Delegation trigger |
| User | `deputy_user_id` | FK | Pre-configured delegate |

---

## 5. Acceptance Criteria (V3 additions over V2)

```
AC-V3-01: KYC necessity engine correctly classifies all 6 ownership categories
          and all configured relationship types. Rules produce consistent output.

AC-V3-02: Intake portal accessible to non-compliance staff.
          Requestor cannot access the full KYC management system.
          Requestor can only see their own submissions.

AC-V3-03: Duplicate detection fires on entity name entry.
          When registration number matches, a warning is mandatory (cannot bypass).

AC-V3-04: Structured screening fields mandatory — "match_status" cannot be NULL
          before report submission.

AC-V3-05: PEP = Y on any entity or UBO automatically triggers ENHANCED KYC.
          SIMPLIFIED type is unavailable in this scenario.

AC-V3-06: ENHANCED KYC: source_of_funds and source_of_wealth are mandatory.
          System blocks submission without these.

AC-V3-07: Delegation active: if approver marked on-leave, their tasks
          automatically route to the configured deputy.

AC-V3-08: SAR gate: L2 approver cannot complete final approval without
          answering the SAR question (Y/N).

AC-V3-09: Final approval: PDF auto-generated and email sent to requestor
          within 60 seconds of approval action.

AC-V3-10: Review schedule: next_review_date = approval_date + N months
          (12 for HIGH, 24 for MEDIUM, 36 for LOW).

AC-V3-11: KPI dashboard shows real-time counts without requiring data export.
          Counts must match direct table query results.

AC-V3-12: Process Log trigger blocks UPDATE and DELETE operations.
          Attempting either returns an error.

AC-V3-13: Date validation blocks future dates in all date fields.
          Invalid dates (e.g., Feb 31) return a validation error.
```
