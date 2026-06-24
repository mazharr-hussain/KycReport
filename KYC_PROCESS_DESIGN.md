# KYC Process Design Document
## Qatari Diar — Enterprise Risk Management & Internal Compliance

**Document Classification:** Internal — Confidential  
**Process Owner:** Head of Enterprise Risk & Compliance  
**Business Analyst:** Risk & Compliance Process Design  
**Version History:** V1 (As-Is) | V2 (To-Be Best Practice)  
**Reference Standards:** FATF 40 Recommendations | Basel KYC Guidelines | EU 6AMLD | ISO 31000  

---

## Dynamic Workflow Methodology

This document follows the **PERCEIVE → THINK → ACT → VERIFY → LOOP** dynamic workflow:

| Phase | Applied To |
|---|---|
| **PERCEIVE** | Requirements gathered from compliance team transcript + codebase analysis |
| **THINK** | Process gaps reasoned through compliance & BA lens |
| **ACT** | Process flows, swimlanes, controls, and data specs designed |
| **VERIFY** | Each process step validated against FATF/Basel standards |
| **LOOP** | V1 verified → gaps identified → V2 designed as improvement cycle |

---

# VERSION 1 — AS-IS PROCESS
## "How We Work Today"

> *Faithful representation of the current process as described by the Head of Enterprise Risk & Compliance. Every manual step, every workaround, and every gap is documented as-is. No assumptions, no additions.*

---

## V1.1 — Process Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    KYC PROCESS — AS-IS (VERSION 1)                         │
│                                                                             │
│  REQUESTING     COMPLIANCE      COMPLIANCE      LEVEL 1       LEVEL 2      │
│  DEPARTMENT     MANAGER         OFFICER         APPROVER      APPROVER     │
│  (Business)     (Carlos)        (Hessa/Latifa)  (Latifa)      (Carlos)     │
│                                                                             │
│  [PHASE 0]      [PHASE 2]       [PHASES 1,3,4,5] [PHASE 6]   [PHASE 7]    │
│  Intake         Assign          Validate+Research  Review      Final        │
│                                 +Report            +Decide     Approve      │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## V1.2 — Actors & Responsibilities

| Actor | Role | System Access | Current Tools |
|---|---|---|---|
| **Requesting Department** | Initiates KYC need, submits documents | None (external to KYC system) | Excel Risk Calculator, Email |
| **Compliance Officer (Contributor)** | Validates documents, conducts research, creates entity & report | KYC System (Contributor role) | WorldCheck, Email, Local folders |
| **Compliance Manager** | Manages pipeline, assigns work | KYC System (All roles) | Email, KYC System, Excel |
| **Level 1 Approver** | Reviews and approves low-risk; first review of medium/high | KYC System (Approver role) | KYC System |
| **Level 2 Approver / Head** | Final approval for medium and high-risk KYCs | KYC System (RFI/L2 role) | KYC System |

---

## V1.3 — Process Flow: Phase by Phase

---

### PHASE 0: KYC Necessity Determination
**Actor:** Requesting Department  
**Tools:** Excel Risk Calculator, Email  
**Trigger:** Department plans to engage a new counterparty

```
START
  │
  ▼
Department completes Excel Risk Calculator
  │
  Input fields:
  ├── Date of request
  ├── Name of requesting employee
  ├── Name of entity/person being onboarded
  ├── Ownership structure:
  │     • Fully owned Qatar legal entity
  │     • Qatar majority legal entity (>50% Qatari)
  │     • Minority Qatar legal entity (<50% Qatari)
  │     • Non-Qatari / Foreign entity
  │     • Qatar national person
  │     • Non-Qatar person
  ├── Type of relationship with QD
  │     (fixed list — supplier / buyer / tenant / contractor / etc.)
  ├── Financial involvement — current or proposed
  └── Related parties declaration (known connections to other QD parties)
  │
  ▼
Excel outputs decision
  │
  ├── [KYC NOT REQUIRED]
  │         │
  │         ▼
  │   Department saves documents to local folder
  │   Manually moves to QDocs at end of day
  │   No further action required
  │   ⚠ No tracking, no evidence log in any system
  │
  └── [KYC REQUIRED]
            │
            ▼
  Department gathers supporting documents
            │
            Document requirements (generic checklist):
            ├── For Natural Person:
            │     • Government-issued ID (Qatar ID or Passport)
            │
            └── For Legal Entity:
                  • Commercial Registration (CR) or equivalent
                  • Ownership/shareholders documentation
                  • Identification of shareholders (natural + legal)
                  • Upstream ownership for significant shareholders
                  • Authorized signatories documentation
                  ⚠ No jurisdiction-specific checklist — officer's judgement
            │
            ▼
  Department sends email to compliance mailbox
  with: Risk Calculator + Documents attached
  ⚠ Format varies by department — no standard
```

**Phase 0 Data Outputs:**
- Excel Risk Calculator (completed)
- Supporting documents package
- Email to compliance mailbox

**Phase 0 Control Points:**
- ⚠ No system validation — Excel is manual, result can be overridden
- ⚠ No standard intake format — each department sends differently
- ⚠ "KYC not required" cases have no formal evidence trail

---

### PHASE 1: Request Receipt & Document Validation
**Actor:** Compliance Officer (initial) → Compliance Manager  
**Tools:** Email, Local file system  
**Trigger:** Email received in compliance mailbox

```
Compliance Officer receives email
  │
  ▼
Opens all attached documents
  │
  ▼
Validates documentation completeness
  │
  Decision: Are documents sufficient for due diligence?
  │
  ├── [INSUFFICIENT]
  │         │
  │         ▼
  │   Officer replies by email requesting missing documents
  │   ⚠ No tracking of how many rounds of back-and-forth
  │   ⚠ No deadline enforced
  │         │
  │         ▼
  │   Department responds with additional documents
  │         │
  │         └── Loop back to validation ↑
  │
  └── [SUFFICIENT]
            │
            ▼
  Officer saves documents to LOCAL FOLDER on workstation
  ⚠ No direct link to QDocs / OneDrive possible
  ⚠ No automatic naming convention enforced
  ⚠ Officer must manually move to QDocs at end of day
  ⚠ No check if entity/folder already exists in QDocs
            │
            ▼
  Validation complete → signal to Manager: "ready for assignment"
  ⚠ This signal is verbal or email — not in any system
```

**Phase 1 Data Outputs:**
- Validated document package (local folder on workstation)
- Mental note / informal signal to manager
- KPI start point: date of LAST document receipt (not first email)

**Phase 1 Pain Points Identified:**
- Complete reliance on email — no case tracking
- No standardized document checklist by jurisdiction
- New staff have no visibility into prior cases for same entity
- Document storage is purely local — no immediate system integration

---

### PHASE 2: Work Assignment
**Actor:** Compliance Manager  
**Tools:** Email, verbal  
**Trigger:** Validated document set ready

```
Manager reviews incoming pipeline
  │
  ▼
Assesses team availability
  (Latifa on leave? Hessa available? Carlos overloaded?)
  │
  ▼
Assigns case to available Compliance Officer
  │
  ▼
Informs officer by email or verbally
  │
  ⚠ No formal assignment record in system
  ⚠ No workload balancing tool
  ⚠ If L2 approver absent — manual ad-hoc activation of substitute
     (No delegation mechanism in system)
```

**Phase 2 Data Outputs:**
- Informal assignment (email or verbal)

---

### PHASE 3: Due Diligence Research — WorldCheck Screening
**Actor:** Compliance Officer  
**Tools:** WorldCheck (external, web-based), manual notes  
**Trigger:** Case assigned

```
Officer opens WorldCheck in web browser
  │
  ▼
Searches for ENTITY (organization or individual)
  │
  ├── [ORGANIZATION]
  │         │
  │         ▼
  │   Search entity name
  │   Review returned matches
  │   Determine: direct match or false positive?
  │   Review entity profile:
  │     • Current status / description
  │     • PEP connections (e.g., state-owned = government = PEP-linked)
  │     • Direct ownership (who owns this entity)
  │     • Connections to other flagged entities
  │   Go to SHAREHOLDERS section
  │     • Check each shareholder for adverse findings
  │   Risk-based depth decision:
  │     • Well-known entity (e.g., Microsoft Qatar) → stop at Qatar entity level
  │     • Complex structure → go as deep as risk justifies
  │     • If 100% chain is unreachable → document the reasonable stopping point
  │
  └── [INDIVIDUAL / NATURAL PERSON]
            │
            ▼
    Search person name
    Review returned matches
    Determine: direct match or false positive?
    Review PEP status, sanctions, adverse media
  │
  ▼
Officer manually notes findings
  ⚠ No structured recording format
  ⚠ No standard evidence form
  ⚠ Findings kept in memory / personal notes until system entry
```

**Phase 3 Data Outputs:**
- Mental notes / personal document with WorldCheck findings
- Decision on match/no-match for each entity and UBO

**Phase 3 Control Points:**
- Risk-based scoping applied for complex ownership structures
- Officer judgement determines depth of investigation

---

### PHASE 4: Entity Creation in KYC System
**Actor:** Compliance Officer  
**Tools:** KYC System  
**Trigger:** Research complete, ready to record

```
Officer logs into KYC System
  │
  ▼
Navigates to: Create New Entity
  │
  ▼
Enters entity details:
  ├── Entity Nature: Natural Person / Legal Person
  ├── Name
  ├── Country Location
  ├── Headquarters Address (free text)
  ├── Screening Results (free text — WorldCheck findings manually typed)
  ├── Conclusion (free text)
  └── Risk Level: Low / Medium / High
  │
  IF Legal Person:
  ├── Company Registration Number
  │
  IF Natural Person:
  ├── Nationality
  ├── ID / Passport Number
  └── Date of Birth
  │
  ▼
Adds UBO / Participant Records (for Legal Entities)
  For each UBO or Authorized Signatory:
  ├── Type: UBO / Authorized Signatory
  ├── Name
  ├── Nationality
  ├── Date of Birth
  ├── ID / Passport Number
  ├── ID Expiry Date
  ├── Screening Results (free text)
  ├── Conclusion
  └── Source of Information
  │
  ▼
Saves entity
  │
  ⚠ System does NOT check for duplicates
  ⚠ Officer does not know if entity was screened before
  ⚠ No link to QDocs / OneDrive
  ⚠ No validation on date fields — accepts invalid dates
  ⚠ Entity and upcoming report are not connected yet
```

**Phase 4 Data Outputs:**
- Entity record in KYC system (`SearchPattern` table)
- UBO records linked to entity (`Ubo` table)

---

### PHASE 5: KYC Report Creation
**Actor:** Compliance Officer  
**Tools:** KYC System, Word (for conclusion template)  
**Trigger:** Entity created

```
Officer navigates to: Create New KYC
  │
  ▼
Selects linked entity from dropdown
  │
  ▼
Fills in report fields:
  ├── Business Counterparty Category (from master list)
  ├── Business Counterparty Type: Legal Person / Natural Person
  ├── KYC Type: Simplified / AdHoc / Enhanced
  ├── Request Made By (from master list)
  ├── Request Date (manual entry — ⚠ no validation)
  ├── Due Diligence Type (auto-populated from KYC type)
  ├── Due Diligence Made By (auto-populated)
  ├── Final Conclusion
  │     ⚠ 95% copy-pasted from Word template — no template in system
  │     Officer opens Word, copies standard text, pastes manually
  ├── KYC Report Status (from master list)
  ├── Risk Level: Low / Medium / High
  └── Next Steps (free text)
  │
  ▼
Uploads supporting documents
  ├── Navigates to local folder on workstation
  ├── Selects files to upload
  └── ⚠ Not integrated with QDocs — separate upload required
  │
  ▼
Chooses action:
  ├── [SAVE AS DRAFT]
  │         Report stays in contributor's pipeline
  │         Officer can return and complete later
  │
  └── [SAVE AND SUBMIT]
            Report moves to Level 1 Approval queue
            System notifies Level 1 Approver
```

**Phase 5 Data Outputs:**
- KYC Report record in system (`Kyc` table)
- Document attachments (`KycDocuments` table)
- Process Log entry (Submit action)

**Phase 5 Pain Points:**
- Re-entering data already captured at entity level (duplication)
- No date validation — historical/future dates accepted silently
- Conclusion requires external Word template — not in-system
- Documents must be uploaded from local folder (not from QDocs)

---

### PHASE 6: Level 1 Approval
**Actor:** Level 1 Approver (Latifa)  
**Tools:** KYC System  
**Trigger:** Report submitted by contributor

```
Level 1 Approver opens approval queue (/apmaster.xhtml)
  │
  ▼
Sees list of pending KYCs awaiting review
  │
  ▼
Opens KYC record:
  ├── Reviews process reference number
  ├── Reviews counterparty designation
  ├── Reviews due diligence type and officer
  ├── Reviews request details (who requested, when)
  ├── Reviews final conclusion
  ├── Checks supporting documents/attachments
  └── Reviews linked entity and UBO details
  │
  ▼
Makes decision:
  │
  ├── [APPROVE]
  │     ├── [LOW RISK] → KYC COMPLETE
  │     │       System should notify requester (⚠ currently does not)
  │     └── [MEDIUM / HIGH RISK] → moves to Level 2 queue
  │
  ├── [REQUEST FOR INFORMATION (RFI)]
  │         Approver enters comment explaining what is needed
  │         Report sent back to contributor
  │         ⚠ Contributor notified — checks comments
  │         Contributor addresses, resubmits
  │         Loop back to Level 1 review ↑
  │
  └── [REJECT]
            Approver enters rejection reason
            Report closed
            ⚠ No automated notification to requester
            ⚠ Requester must be informed manually
```

**Phase 6 Data Outputs:**
- Approval/Rejection/RFI action in ProcessLog
- Comment in KycWfComments
- Workflow status updated on Kyc record

---

### PHASE 7: Level 2 Approval (Medium / High Risk Only)
**Actor:** Level 2 Approver / Compliance Head (Carlos)  
**Tools:** KYC System  
**Trigger:** Level 1 approved, risk level = Medium or High

```
Level 2 Approver opens RFI/L2 queue (/rfimaster.xhtml)
  │
  ▼
Same review process as Level 1 (full report review)
  │
  ▼
Makes decision:
  │
  ├── [APPROVE] → KYC COMPLETE
  │       ⚠ Should auto-notify requester — currently does not
  │       ⚠ No automatic PDF delivery to requesting department
  │
  ├── [REQUEST FOR INFORMATION (RFI)]
  │         Same RFI loop as Level 1
  │
  └── [REJECT]
            KYC closed with documented reason
```

---

### PHASE 8: Completion & Reporting (Current Reality)
**Actor:** Compliance Manager  
**Tools:** KYC System, Excel  
**Trigger:** Approval complete

```
WHAT SHOULD HAPPEN:
  Automatic notification → Requesting Department
  Completed KYC Report PDF → Delivered to requester
  KPI automatically updated
  Dashboard reflects completion

WHAT ACTUALLY HAPPENS:
  ├── Manual notification by email to requesting department
  ├── Manager requests monthly Excel export from system
  ├── Manager manually computes KPIs from export
  └── Any question about status → "Madi, send me an export"
```

---

## V1.4 — Current Workflow Status Definitions

| Status | Meaning | Set By |
|---|---|---|
| **In Progress** | Compliance officer actively working on it | Contributor (mental category / email folder) |
| **Waiting for More Information** | Documents requested from department | Contributor (email flag) |
| **Waiting for Approval** | Report submitted, pending approver | System status after submit |
| **Draft** | Saved but not submitted | System |
| **Submitted** | Sent to Level 1 queue | System |
| **Approved (L1)** | Passed Level 1 | System |
| **Approved (L2 / Final)** | Final approval complete | System |
| **Rejected** | Closed — not approved | System |
| **RFI** | Information requested by approver | System |

---

## V1.5 — Current Pain Point Register

| ID | Pain Point | Phase | Severity | Root Cause |
|---|---|---|---|---|
| PP-01 | No standardized intake form from departments | 0 | High | No digital intake portal |
| PP-02 | KYC necessity runs on standalone Excel | 0 | Medium | No system integration |
| PP-03 | "KYC not required" cases have no evidence trail | 0 | High | No storage for declined cases |
| PP-04 | Request arrives by email in different formats | 1 | High | No intake standard |
| PP-05 | No tracking of document request back-and-forth | 1 | High | Purely email-based |
| PP-06 | Documents saved locally, manually moved to QDocs | 1 | Medium | No DMS integration |
| PP-07 | No duplicate entity detection | 4 | High | No uniqueness check in system |
| PP-08 | New staff have no institutional memory visibility | 1,4 | High | No searchable history UI |
| PP-09 | Entity creation not linked to report creation | 4,5 | Medium | Two separate unconnected steps |
| PP-10 | Date fields accept invalid values | 5 | Medium | No input validation |
| PP-11 | Final conclusion requires copy-paste from Word | 5 | Low | No in-system conclusion templates |
| PP-12 | No approver delegation / deputy mechanism | 2,6,7 | High | Not built in system |
| PP-13 | No automated completion notification to requester | 8 | High | Not implemented |
| PP-14 | No live KPI dashboard — all manual Excel exports | 8 | High | Reporting not built |
| PP-15 | System has no source code — stability risk | All | Critical | Technical debt |
| PP-16 | Passwords known to all — shared accounts possible | All | Critical | Security gap |

---
---

# VERSION 2 — TO-BE PROCESS
## "How It Should Work — Industry Best Practice"

> *Built on V1 foundation. Each improvement is mapped to a specific pain point (PP-XX) and an industry standard. Every addition is justified — no gold-plating.*

---

## V2.1 — Design Principles Applied

| Principle | Application |
|---|---|
| **Risk-Based Approach (RBA)** | Process depth and controls scale with risk level |
| **Straight-Through Processing (STP)** | Automate every step that doesn't require human judgement |
| **Single Source of Truth** | One record per entity — no duplicates, no parallel Excel |
| **Maker-Checker** | No self-approval at any risk level |
| **Immutable Audit Trail** | Every action logged, timestamped, attributed |
| **Exception Management** | Standard path is automated; exceptions route to human review |
| **KPI by Design** | Every timestamp captured so KPIs compute automatically |

---

## V2.2 — Actors (Expanded)

| Actor | Role | New in V2 |
|---|---|---|
| **Requesting Department** | Initiates KYC, submits via digital form | Digital intake replaces email |
| **System (Automated)** | Validates intake, checks duplicates, routes by risk | New automation layer |
| **Compliance Officer (Contributor)** | Research, entity/report creation, document review | Streamlined — no re-entry |
| **Compliance Manager** | Pipeline oversight, assignment, delegation | Delegation mechanism added |
| **Level 1 Approver** | Review and approve/reject low-risk | Unchanged |
| **Level 2 Approver / MLRO** | Final approval medium/high risk; SAR escalation | MLRO role added |
| **Deputy Approver** | Activated when primary approver is absent | New delegation role |
| **Requesting Department** | Receives completed report via system notification | Automated notification |

---

## V2.3 — Improved Process Flow

---

### PHASE 0 (V2): Digital Intake & Automated KYC Necessity
**Improvement:** Replaces: Excel calculator + unstructured email  
**Addresses:** PP-01, PP-02, PP-03, PP-04

```
Requesting Department accesses DIGITAL INTAKE PORTAL
  │
  ▼
Completes structured INTAKE FORM (web form):
  ├── Requestor details (auto-filled from SSO login)
  ├── Entity/Person name
  ├── Relationship type (controlled dropdown — managed by admin)
  ├── Entity ownership category:
  │     • Fully Qatari legal entity
  │     • Qatar majority (>50%)
  │     • Qatar minority (<50%)
  │     • Foreign / Non-Qatari entity
  │     • Qatari natural person
  │     • Non-Qatari natural person
  ├── Financial involvement (current / proposed / none)
  ├── Related parties declaration (yes/no + details)
  └── Document upload section (jurisdiction-aware checklist shown)
       │
       Checklist auto-selects based on entity type + country:
       ├── Qatar entity: CR required, shareholder declaration
       ├── UK entity: Companies House extract, PSC register
       ├── Egypt entity: Commercial registry, ownership declaration
       └── [Other]: Generic ownership + ID document set
  │
  ▼
System runs AUTOMATED KYC NECESSITY DETERMINATION
  (Rules engine replaces Excel — same logic, always consistent)
  │
  ├── [KYC NOT REQUIRED]
  │         │
  │         ▼
  │   System creates a "KYC Waiver" record:
  │   ├── Intake form saved
  │   ├── Documents stored in DMS (not local folder)
  │   ├── Status: "KYC Not Required — Evidence Stored"
  │   ├── Timestamp + requestor logged
  │   └── Notification sent to requestor: "KYC waiver recorded"
  │   ✓ Solves PP-03: Evidence trail exists even for "not required" cases
  │
  └── [KYC REQUIRED]
            │
            ▼
  System creates CASE RECORD automatically:
  ├── Case ID generated
  ├── Intake timestamp recorded (KPI clock starts)
  ├── All submitted documents attached to case
  ├── Status: "Pending Document Review"
  └── Notification to Compliance Team: "New KYC request received"
  ✓ Solves PP-01, PP-04: Standardized, system-generated
```

**V2 Phase 0 Outputs:**
- Case Record (in system)
- Document package attached to case (not local folder)
- KPI timestamp: `intake_submission_date`

---

### PHASE 1 (V2): Automated Document Validation + Assignment
**Improvement:** Replaces: Manual email review + verbal assignment  
**Addresses:** PP-04, PP-05, PP-06, PP-08

```
System checks submitted documents against JURISDICTION CHECKLIST
  │
  ├── [DOCUMENTS INCOMPLETE]
  │         │
  │         ▼
  │   System sends structured RFI to Requesting Department:
  │   ├── Lists exactly which documents are missing
  │   ├── Provides checklist with download link
  │   ├── Sets a response deadline (configurable: e.g., 5 business days)
  │   ├── Status: "Pending Additional Documents"
  │   └── Reminder sent automatically at deadline - 1 day
  │         │
  │         ▼
  │   Department responds via portal (not email)
  │   ├── All interactions logged with timestamps
  │   └── Round-trip count tracked → KPI: "Document Acquisition Time"
  │         └── Loop back to document validation ↑
  │
  └── [DOCUMENTS COMPLETE]
            │
            ▼
  System checks for DUPLICATE ENTITY
  ├── Searches existing entities by name + registration number + nationality
  ├── Fuzzy match on names (catches spelling variants)
  │
  ├── [DUPLICATE FOUND]
  │         │
  │         ▼
  │   Alert to Compliance Officer:
  │   "Entity X was previously screened on [date]. View existing record?"
  │   Officer can:
  │   ├── Link to existing entity (no re-creation needed)
  │   └── Create new version (triggers version increment)
  │   ✓ Solves PP-07, PP-08
  │
  └── [NO DUPLICATE]
            │
            ▼
  KPI timestamp recorded: `documents_complete_date`
  (This is the KPI start point per compliance head's requirement)
            │
            ▼
  AUTOMATED ASSIGNMENT ENGINE:
  ├── Checks compliance officer workload (active cases per officer)
  ├── Checks officer availability (not on leave)
  ├── Assigns to least-loaded available officer
  ├── Creates formal assignment record
  ├── Notifies assigned officer: "Case [ID] assigned to you"
  └── Status: "In Progress"
  ✓ Solves PP-06: No more verbal/email assignments
```

---

### PHASE 2 (V2): Risk Pre-Assessment
**Improvement:** New step — not in V1  
**Addresses:** Compliance gap — no automated risk indicators

```
Assigned officer opens case with pre-populated RISK INDICATOR PANEL:
  │
  Automated flags already computed by system:
  ├── Geographic Risk: Country risk tier (FATF High Risk / Grey List / Standard)
  ├── Entity Type Risk: State-owned = PEP-linked (elevated)
  ├── Relationship Risk: Transaction volume bracket (if known)
  ├── Ownership Complexity: Multiple layers = elevated
  └── Historical Flags: Any prior RFI / adverse findings in system
  │
  ▼
System suggests initial risk level: Low / Medium / High
  (Officer can override — override requires documented justification)
  │
  ▼
Based on initial risk:
  ├── [LOW RISK] → Simplified Due Diligence (SDD) path
  ├── [MEDIUM RISK] → Standard KYC path
  └── [HIGH RISK] → Enhanced Due Diligence (EDD) path
              Additional mandatory fields activated:
              ├── Source of funds (required)
              ├── Source of wealth (required)
              ├── Senior management approval required
              └── Annual review cycle set (vs. 3-year for low risk)
```

---

### PHASE 3 (V2): Due Diligence Research — Structured WorldCheck Recording
**Improvement:** Adds structured evidence capture; API-ready design  
**Addresses:** PP-07, compliance gap — no screening date/source

```
Officer performs WorldCheck screening (manual, external tool — V1 unchanged)
  │
  ▼
Returns to KYC System to record STRUCTURED SCREENING RESULTS:
  │
  For EACH entity and UBO screened:
  ├── Screening Date (date picker — not free text)
  ├── Screening Source (dropdown: WorldCheck / OFAC / UN / EU / Other)
  ├── Match Status: No Match / Potential Match / Confirmed Match / False Positive
  ├── PEP Flag: Yes / No (Y/N field — not buried in free text)
  ├── Adverse Media Flag: Yes / No
  ├── Findings Narrative (free text — WorldCheck result details)
  ├── Resolution Note (if false positive: explain why dismissed)
  └── Evidence Reference (WorldCheck case reference number if available)
  │
  ▼
If CONFIRMED MATCH or PEP = Yes:
  ├── Mandatory escalation flag set
  ├── EDD path activated (if not already)
  └── Senior management approval required (system enforces)
  │
  ▼
  [API READINESS NOTE]
  The above data structure is designed for future API integration
  with WorldCheck or ComplyAdvantage. When integrated:
  ├── System submits search automatically
  ├── Matches returned and pre-populated in above fields
  ├── Officer reviews and confirms — no manual lookup needed
  └── Zero data transcription errors
```

---

### PHASE 4 (V2): Entity Creation — Enriched & Duplicate-Safe
**Improvement:** Structured fields, duplicate prevention, DMS link  
**Addresses:** PP-07, PP-08, PP-09, PP-10

```
If new entity (no duplicate found in Phase 1):
  Officer opens pre-populated entity form
  ├── Many fields auto-populated from intake form data
  ├── Officer validates / enriches — does not re-type
  │
  Structured fields (additions from V1):
  ├── Entity Nature: Natural Person / Legal Person
  ├── Name
  ├── Date of Incorporation (for legal entities)
  ├── Country of Incorporation (distinct from operating country)
  ├── Country of Operation / Location
  ├── Registered Address (structured: Street, City, Country, Postal Code)
  ├── Operating Address (if different)
  ├── Legal Registration Number
  ├── Industry / Sector (dropdown — standard NACE/NAICS code)
  ├── Website / Official source URL
  ├── Risk Level: Low / Medium / High
  ├── Screening Results (structured — from Phase 3)
  └── Conclusion
  │
  For Natural Person (additional):
  ├── Title / Salutation
  ├── Full legal name (First, Middle, Last)
  ├── Nationality (primary)
  ├── Second nationality (if applicable)
  ├── Country of Residence
  ├── Date of Birth (validated: cannot be future, age plausibility check)
  ├── Government ID Type (Qatar ID / Passport / National ID)
  ├── ID Number
  ├── ID Issuing Country
  └── ID Expiry Date (validated: must not be expired — warning if <6 months)
  │
  For Legal Person UBOs — enriched fields:
  ├── (All V1 fields retained)
  ├── Ownership Percentage (numeric — mandatory if UBO type)
  ├── Type of Control: Direct / Indirect / Both
  ├── Country of Residence (separate from nationality)
  └── Residential Address
  │
  ▼
Documents linked from CASE RECORD (not uploaded from local folder)
  ├── All documents submitted at intake are already attached to case
  ├── Entity record links to case documents automatically
  └── Officer can add additional documents found during research
  ✓ Solves PP-06, PP-09
```

---

### PHASE 5 (V2): KYC Report Creation — Auto-Population & Validation
**Improvement:** Eliminates re-entry, adds date validation, in-system templates  
**Addresses:** PP-09, PP-10, PP-11

```
Officer clicks "Create KYC Report from Entity"
  │
  ▼
System auto-populates from entity record:
  ├── Entity name → Counterparty Designation (pre-filled)
  ├── Entity nature → Business Counterparty Type (pre-filled)
  ├── Risk level → Report Risk Level (pre-filled, editable)
  ├── Linked entity screening results → carried forward
  └── Request details from intake form → pre-filled
  │
  Officer completes:
  ├── Business Counterparty Category (still manual — contextual)
  ├── KYC Type: Simplified / AdHoc / Enhanced
  │     [If HIGH RISK → Enhanced KYC enforced — cannot select Simplified]
  ├── Due Diligence Type (auto from KYC type)
  ├── Request Date:
  │     ├── Auto-set to `documents_complete_date` (KPI start point)
  │     ├── Editable with reason field if changed
  │     └── Validation: cannot be future date, cannot be >2 years ago
  ├── Final Conclusion:
  │     ├── TEMPLATE SELECTOR dropdown:
  │     │     "Low Risk — No Adverse Findings"
  │     │     "Medium Risk — Minor PEP Connection — Managed"
  │     │     "High Risk — Approved with Conditions"
  │     │     "Negative — Sanctions Match"
  │     │     [Custom — free text]
  │     ├── Template text auto-populated into conclusion field
  │     └── Officer personalizes template (not copy-paste from Word)
  │     ✓ Solves PP-11
  ├── Next Steps (free text)
  └── KYC Report Status
  │
  ▼
Date validation engine:
  ├── Request date: must be valid calendar date, not future, not >2 years ago
  ├── ID expiry dates: warn if expired, block if expired >6 months
  └── All dates: format enforced — no invalid month/day accepted
  ✓ Solves PP-10
  │
  ▼
SLA INDICATOR shown on form:
  ├── Days since documents received
  ├── Target completion date (by KYC type: SDD=5 days, Standard=10, EDD=20)
  └── Red/Amber/Green traffic light
  │
  ▼
Officer chooses:
  ├── [SAVE AS DRAFT] → Stays in pipeline
  └── [SAVE AND SUBMIT] → Routes by risk level:
            │
            ├── LOW RISK → Level 1 queue
            └── MEDIUM / HIGH RISK → Level 1 queue
                (Level 2 activated automatically AFTER L1 approval)
```

---

### PHASE 6 (V2): Level 1 Approval — With Delegation
**Improvement:** Delegation mechanism, automated routing, SLA tracking  
**Addresses:** PP-12, PP-13

```
Level 1 Approver receives IN-SYSTEM notification + email alert:
  "KYC [ID] submitted by [Officer] — awaiting your review"
  │
  ▼
DELEGATION CHECK:
  If primary L1 Approver marked as "On Leave":
  ├── System routes to designated Deputy L1 Approver
  └── Deputy is pre-configured in user management (not ad-hoc)
  ✓ Solves PP-12
  │
  ▼
Approver opens KYC record — ENRICHED REVIEW PANEL:
  ├── All report fields (as V1)
  ├── Entity details and UBO list
  ├── STRUCTURED SCREENING RESULTS (from Phase 3 — not free text)
  ├── PEP flags and adverse media flags visible clearly
  ├── Document attachments (directly viewable in browser — not download required)
  ├── Full comment history from prior interactions
  └── SLA indicator: "This report is X days old — target was Y days"
  │
  ▼
Decision:
  │
  ├── [APPROVE]
  │     ├── Approval note entered (optional for low risk, mandatory for medium/high)
  │     ├── ProcessLog entry created
  │     │
  │     ├── [LOW RISK] → STATUS: FINAL APPROVED
  │     │       ├── Automated PDF report generated
  │     │       ├── Automated email to Requesting Department:
  │     │       │     "KYC for [Entity] is complete. Report attached."
  │     │       └── KPI recorded: total_days = complete_date - documents_complete_date
  │     │       ✓ Solves PP-13
  │     │
  │     └── [MEDIUM / HIGH RISK] → Routed to Level 2 queue
  │               Level 2 Approver notified automatically
  │
  ├── [REQUEST FOR INFORMATION (RFI)]
  │         Structured RFI form:
  │         ├── Category: Missing Document / Unclear Conclusion / Insufficient Screening / Other
  │         ├── Free text detail
  │         └── Response deadline set
  │         Contributor notified by system
  │         RFI round count tracked
  │         ✓ Structured RFI (not just a comment field)
  │
  └── [REJECT]
            Rejection reason (mandatory free text)
            ProcessLog entry
            Automated notification to Contributor and Requesting Department
```

---

### PHASE 7 (V2): Level 2 / MLRO Approval — With SAR Gate
**Improvement:** MLRO role defined, SAR escalation path added  
**Addresses:** Compliance gap — no SAR workflow; PP-12

```
MLRO / Level 2 Approver opens L2 queue
  │
  ▼
Same delegation check as Phase 6
  │
  ▼
Reviews full record (same enriched panel as L1)
  │
  ▼
SAR GATE (new in V2):
  Before making approval decision, approver must confirm:
  "Is there any information in this record that warrants
   a Suspicious Activity Report (SAR)?"
  ├── [NO] → Proceed to approval decision
  └── [YES] → SAR Escalation Path:
            ├── SAR flag set on record
            ├── Status: "Pending SAR Review"
            ├── Compliance Head notified
            ├── External SAR filing process triggered (manual — outside system)
            └── KYC approval paused pending SAR decision
  │
  ▼
Decision (same as L1: Approve / RFI / Reject)
  │
  └── [APPROVE] → STATUS: FINAL APPROVED
            ├── Automated PDF report generated with APPROVED watermark
            ├── Automated notification to Requesting Department + Contributor
            ├── KPI: total_days computed and stored
            └── Case archived — read-only
```

---

### PHASE 8 (V2): Post-Approval — Ongoing Monitoring & KPI Dashboard
**Improvement:** Eliminates manual Excel reporting; adds review scheduling  
**Addresses:** PP-13, PP-14, compliance gaps — ongoing monitoring

```
ON APPROVAL:
  ├── Case sealed (no further edits without formal re-open process)
  ├── Next Review Date set automatically:
  │     ├── LOW RISK → 3 years from approval
  │     ├── MEDIUM RISK → 2 years from approval
  │     └── HIGH RISK → 1 year from approval
  ├── KYC expiry date visible on entity record
  └── Archived to read-only with full document package
  │
  ▼
LIVE KPI DASHBOARD (real-time, no Excel needed):
  ├── Total KYCs: This month / This quarter / This year
  ├── Average turnaround time by KYC type
  ├── KYCs by risk level (Low/Medium/High) — breakdown
  ├── KYCs by contributor (team productivity)
  ├── SLA compliance rate (% completed within target days)
  ├── Pending pipeline: In Progress / Awaiting Info / Awaiting Approval
  ├── Overdue KYCs (past SLA)
  └── Rejection / RFI rate by officer
  ✓ Solves PP-14: "Madi, send me an export" eliminated
  │
  ▼
ONGOING MONITORING ENGINE:
  Runs nightly scheduled job:
  ├── Check for KYCs approaching review date (60-day pre-alert)
  ├── Check for expired KYCs (past review date)
  ├── Check for entities with expiring ID documents (<90 days)
  └── Generate daily alert list → Dashboard + email digest to Manager
```

---

## V2.4 — Approval Routing Matrix (Formalized)

| Risk Level | KYC Type | L1 Required | L2 Required | SLA Target | Review Cycle |
|---|---|---|---|---|---|
| **Low** | Simplified KYC | ✅ | ❌ | 5 business days | 3 years |
| **Low** | AdHoc KYC | ✅ | ❌ | 5 business days | 3 years |
| **Medium** | Standard KYC | ✅ | ✅ | 10 business days | 2 years |
| **High** | Enhanced KYC (EDD) | ✅ | ✅ (MLRO) | 20 business days | 1 year |
| **High + PEP** | Enhanced KYC (EDD) | ✅ | ✅ (MLRO) | 20 business days | 1 year |
| **Any + SAR Flag** | Any | ✅ | ✅ (MLRO) | Paused | N/A |

---

## V2.5 — KPI Framework (Built Into Process)

| KPI | Formula | Target |
|---|---|---|
| **Intake-to-Complete Time** | `approval_date − documents_complete_date` | By type (see matrix above) |
| **Document Acquisition Time** | `documents_complete_date − intake_submission_date` | ≤ 5 business days |
| **First-Time Approval Rate** | `KYCs approved without RFI ÷ total KYCs` | > 80% |
| **RFI Rate** | `KYCs with ≥1 RFI ÷ total KYCs` | < 20% |
| **SLA Compliance** | `KYCs completed within target ÷ total KYCs` | > 90% |
| **Pending > 30 Days** | `Count of open cases older than 30 days` | 0 |
| **High Risk Completion** | `High risk KYCs completed within 20 days ÷ total high risk` | > 85% |
| **Overdue Reviews** | `Count of KYCs past review date without renewal` | 0 |

---

## V2.6 — Pain Point Resolution Matrix

| Pain Point | V1 Reality | V2 Solution |
|---|---|---|
| PP-01 No standardized intake | Email, any format | Digital intake portal with structured form |
| PP-02 Excel risk calculator | Standalone Excel | Rules engine in system |
| PP-03 No evidence for "not required" | Lost | KYC Waiver record created automatically |
| PP-04 Unstructured requests | Any email format | Structured portal submission only |
| PP-05 No document request tracking | Email threads | In-system RFI with deadline and audit trail |
| PP-06 Documents on local folder | Manual copy to QDocs | Documents attached to case at intake, DMS-linked |
| PP-07 No duplicate detection | No check | Automated fuzzy name + registration number match |
| PP-08 No institutional memory | Memory-dependent | Searchable entity history with full version trail |
| PP-09 Re-entry between entity and report | Manual double-entry | Report auto-populated from entity data |
| PP-10 No date validation | Invalid dates accepted | Validation engine with format + logic checks |
| PP-11 Conclusion copy-paste from Word | External document | In-system conclusion templates by risk type |
| PP-12 No delegation mechanism | Ad-hoc phone call | Pre-configured deputy per approver role |
| PP-13 No completion notification | Manual email | Automated notification + PDF on final approval |
| PP-14 No live KPI dashboard | Monthly Excel export | Real-time dashboard with all KPIs computed |
| PP-15 No source code | Technical debt | New system addresses this by design |
| PP-16 Shared passwords | Security risk | Individual accounts, password policy, MFA for approvers |

---

## V2.7 — Process Comparison Summary

| Dimension | V1 (As-Is) | V2 (To-Be) |
|---|---|---|
| **Intake channel** | Email (unstructured) | Digital portal (structured form) |
| **KYC necessity check** | Excel calculator | Rules engine (system) |
| **Document storage** | Local folder → manual QDocs | Attached to case at intake |
| **Assignment** | Verbal / email | Automated workload-balanced assignment |
| **Duplicate check** | None — memory only | Automated fuzzy match |
| **Screening evidence** | Free text in spResults | Structured: date, source, match status, PEP flag |
| **Report creation** | Full manual re-entry | Auto-populated from entity data |
| **Date validation** | None | Multi-layer validation engine |
| **Conclusion writing** | Copy-paste from Word | In-system risk-based templates |
| **Approval routing** | Fixed (L1 always, L2 manually for medium/high) | Automated by risk level + delegation rules |
| **Approver absence** | Ad-hoc phone call | Pre-configured deputy system |
| **Completion notification** | Manual email | Automated + PDF generated |
| **KPI reporting** | Monthly manual Excel export | Real-time live dashboard |
| **Ongoing monitoring** | None | Scheduled review cycle with automated alerts |
| **SAR pathway** | None | SAR gate in L2 approval |
| **Security** | Shared passwords known to all | Individual accounts + MFA for approvers |

---

## V2.8 — Implementation Roadmap (Phased)

### Phase A — Quick Wins (1–3 months)
- [ ] Add date validation to all date fields
- [ ] Add structured screening fields (screening_date, screening_source, match_status, is_pep)
- [ ] Add in-system conclusion templates
- [ ] Add UBO ownership percentage field
- [ ] Fix duplicate detection (name + registration number check on entity creation)
- [ ] Hash all passwords (BCrypt)

### Phase B — Process Integration (3–6 months)
- [ ] Build digital intake portal (replaces email)
- [ ] Auto-populate report from entity data
- [ ] Automated completion notification + PDF delivery
- [ ] Delegation/deputy mechanism in user management
- [ ] KPI timestamps added to all process steps

### Phase C — Intelligence Layer (6–12 months)
- [ ] Live KPI dashboard with all metrics
- [ ] Automated risk pre-assessment panel
- [ ] Scheduled review cycle + overdue alerts
- [ ] SAR escalation workflow
- [ ] WorldCheck API integration (when approved)

---

*Process designed by: Risk & Compliance Business Analysis — KYC Process Design*  
*Standards applied: FATF 40 Recommendations | Basel KYC | EU 6AMLD | ISO 31000 Risk Management*
