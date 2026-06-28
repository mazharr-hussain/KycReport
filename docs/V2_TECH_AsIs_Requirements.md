# Version 2 — Technical / Functional Requirements
# As-Is Process: Functional Specification

**Document Type:** Functional Requirements Specification  
**Audience:** Business Analysts, Developers  
**Source:** Requirements Gathering Transcript + Current System Analysis  
**Purpose:** Formal capture of what the current process requires — baseline for gap analysis  

---

## 1. Functional Requirements — As-Is

### FR-01: KYC Necessity Determination

| ID | Requirement | Priority | Source |
|---|---|---|---|
| FR-01.1 | System must evaluate a set of inputs and return Y/N for KYC requirement | Must Have | Transcript |
| FR-01.2 | Inputs: entity type, ownership category (6 values), relationship type, financial involvement flag, related parties flag | Must Have | Transcript |
| FR-01.3 | Ownership categories: Fully Qatari legal entity, Qatar majority, Qatar minority, Foreign/Non-Qatari entity, Qatari national person, Non-Qatari person | Must Have | Transcript |
| FR-01.4 | Relationship types must be configurable (can be added/managed) | Should Have | Transcript |
| FR-01.5 | Where KYC is not required, documents submitted must still be stored as evidence | Must Have | Transcript |
| FR-01.6 | All determination inputs and output must be logged with timestamp | Must Have | Compliance |

---

### FR-02: Intake and Request Management

| ID | Requirement | Priority | Source |
|---|---|---|---|
| FR-02.1 | System must accept a KYC request from a business department | Must Have | Transcript |
| FR-02.2 | Request must capture: requestor identity, department, entity name, relationship type, financial involvement, related party declaration | Must Have | Transcript |
| FR-02.3 | Request must support file upload of supporting documents | Must Have | Transcript |
| FR-02.4 | System must generate a unique case reference number on submission | Must Have | Transcript |
| FR-02.5 | System must track the date when complete documentation was received | Must Have | Transcript (KPI point) |
| FR-02.6 | System must support back-and-forth document requests with audit trail | Must Have | Transcript |
| FR-02.7 | System must allow compliance manager to assign a case to a specific officer | Must Have | Transcript |

---

### FR-03: Entity Management

| ID | Requirement | Priority | Source |
|---|---|---|---|
| FR-03.1 | System must support two entity types: Natural Person and Legal Entity | Must Have | Transcript + Current system |
| FR-03.2 | Natural person fields: full name, nationality, date of birth, ID type, ID number, ID expiry | Must Have | Current system |
| FR-03.3 | Legal entity fields: entity name, registration number, country, headquarters address | Must Have | Current system |
| FR-03.4 | System must support adding multiple UBO/participant records to a legal entity | Must Have | Transcript |
| FR-03.5 | UBO fields: name, type (UBO/Authorised Signatory), nationality, DOB, ID number, ID expiry, screening results, source | Must Have | Current system |
| FR-03.6 | System must search existing entities before creating a new one | Must Have | Transcript (duplicate issue) |
| FR-03.7 | Entity must support versioning — old versions retained when information changes | Must Have | Current system |
| FR-03.8 | Screening results must be recorded per entity and per UBO | Must Have | Compliance requirement |

---

### FR-04: KYC Report Management

| ID | Requirement | Priority | Source |
|---|---|---|---|
| FR-04.1 | Each KYC report must be linked to at least one entity | Must Have | Current system |
| FR-04.2 | Report must capture: BCP category, counterparty type, KYC type (Simplified/AdHoc/Enhanced), request made by, request date, DD type, DD made by, conclusion, risk level, next steps | Must Have | Transcript + Current system |
| FR-04.3 | KYC types: Simplified KYC, AdHoc KYC, Enhanced KYC | Must Have | Transcript |
| FR-04.4 | Risk levels: Low, Medium, High | Must Have | Current system |
| FR-04.5 | Report must support Save as Draft and Submit for Approval actions | Must Have | Current system |
| FR-04.6 | System must support multiple file attachments per report | Must Have | Current system |
| FR-04.7 | Report must generate a unique process reference number | Must Have | Current system |
| FR-04.8 | Report must display the history of all workflow actions | Must Have | Current system |

---

### FR-05: Approval Workflow

| ID | Requirement | Priority | Source |
|---|---|---|---|
| FR-05.1 | Low-risk reports require 1 approval (Level 1 only) | Must Have | Transcript |
| FR-05.2 | Medium and high-risk reports require 2 approvals (Level 1 + Level 2) | Must Have | Transcript |
| FR-05.3 | Contributor cannot approve their own submission | Must Have | Transcript (4-eyes) |
| FR-05.4 | At each level, approver can: Approve, Request For Information (RFI), Reject | Must Have | Transcript |
| FR-05.5 | RFI must return report to contributor with comments; contributor must be able to respond and resubmit | Must Have | Transcript |
| FR-05.6 | All approval decisions must be logged with timestamp, user, and comments | Must Have | Compliance |
| FR-05.7 | Comments must be persistent and visible in report history | Must Have | Transcript |
| FR-05.8 | System must notify approver when a report is submitted for their review | Must Have | Transcript |

---

### FR-06: Document Management

| ID | Requirement | Priority | Source |
|---|---|---|---|
| FR-06.1 | Documents must be uploaded and stored at the report level | Must Have | Current system |
| FR-06.2 | Document metadata must be recorded: name, type, upload date, uploaded by | Must Have | Current system |
| FR-06.3 | Uploaded documents must be viewable by approvers during review | Must Have | Transcript |
| FR-06.4 | System must support multiple documents per report | Must Have | Current system |

---

### FR-07: User and Role Management

| ID | Requirement | Priority | Source |
|---|---|---|---|
| FR-07.1 | System must support three operational roles: Contributor, Approver L1, Approver L2/RFI | Must Have | Transcript |
| FR-07.2 | User must have at minimum: user ID, name, email, mobile, role | Must Have | Current system |
| FR-07.3 | A user can hold multiple roles simultaneously | Should Have | Current system |
| FR-07.4 | Admin must be able to create, edit, and deactivate users | Must Have | Current system |
| FR-07.5 | Each role must see only the pages and actions relevant to their role | Must Have | Current system |

---

### FR-08: Search and Reporting

| ID | Requirement | Priority | Source |
|---|---|---|---|
| FR-08.1 | Compliance officer must be able to search KYC records by: reference number, counterparty name, risk level, report status, workflow status, DD officer | Must Have | Current system |
| FR-08.2 | System must produce a PDF version of any KYC report | Must Have | Current system |
| FR-08.3 | Draft reports must be watermarked in PDF output | Must Have | Current system |
| FR-08.4 | System must maintain an audit log accessible per report | Must Have | Compliance |

---

### FR-09: Reference Data

| ID | Requirement | Priority | Source |
|---|---|---|---|
| FR-09.1 | Business Counterparty Categories must be configurable by admin | Must Have | Transcript |
| FR-09.2 | Report statuses must be configurable with colour coding | Must Have | Current system |
| FR-09.3 | Screening result categories must be configurable | Must Have | Current system |
| FR-09.4 | Request originator list must be configurable | Must Have | Current system |
| FR-09.5 | Country list must be maintained in the system | Must Have | Current system |

---

## 2. Non-Functional Requirements — As-Is

| ID | Requirement | Current State |
|---|---|---|
| NFR-01 | Session timeout: 30 minutes | Met |
| NFR-02 | All audit log entries must be insert-only (no update/delete) | Met |
| NFR-03 | Role-based page access enforced | Met |
| NFR-04 | Password storage must be secure (hashed) | **Not Met** — plain text |
| NFR-05 | Date fields must accept only valid calendar dates | **Not Met** — no validation |
| NFR-06 | Duplicate entity detection before creation | **Not Met** |
| NFR-07 | Notification to requestor on final approval | **Not Met** |
| NFR-08 | Live KPI reporting | **Not Met** |

---

## 3. Data Flow Diagrams

### 3.1 KYC Creation Flow

```
[Business Dept]
  │ Email with documents
  ▼
[Compliance Mailbox]
  │ Officer opens, validates
  ▼
[Local Workstation]
  │ Saves documents to folder
  ▼
[WorldCheck - External]
  │ Manual screening
  │ Results noted in memory
  ▼
[KYC System]
  ├── Create Entity (manual entry)
  ├── Add UBOs (manual entry)
  ├── Create Report (manual entry — re-entering known data)
  └── Upload Documents (from local folder)
  │
  ▼
[Approval Queue]
  └── Approver reviews and acts
```

### 3.2 Workflow State Machine

```
States: DRAFT → SUBMITTED → PENDING_L1 → [APPROVED_L1 | REJECTED | RFI]
        APPROVED_L1 → (if medium/high) → PENDING_L2 → [FINAL_APPROVED | REJECTED | RFI]

Transitions:
  Contributor:   DRAFT → SUBMITTED (submit action)
  System:        SUBMITTED → PENDING_L1 (auto-route to active L1 approver on submit)
  L1 Approver:   PENDING_L1 → APPROVED_L1 (approve)
                 PENDING_L1 → REJECTED (reject)
                 PENDING_L1 → RFI (request info)
  Contributor:   RFI → SUBMITTED (respond and resubmit)
  L2 Approver:   APPROVED_L1 → FINAL_APPROVED (approve)
                 APPROVED_L1 → REJECTED (reject)
                 APPROVED_L1 → RFI (request info)
```

---

## 4. Gaps Between As-Is Requirements and Current System

| Gap ID | Requirement Not Met | Impact |
|---|---|---|
| GAP-01 | No standardised intake form — requests arrive by email | Inconsistency, no tracking |
| GAP-02 | No KYC necessity rules engine in system — relies on Excel | Inconsistency, no audit |
| GAP-03 | No evidence record when KYC not required | Compliance gap |
| GAP-04 | Duplicate entity detection not implemented | Duplicate records |
| GAP-05 | Screening results unstructured (free text) | Cannot audit what was checked |
| GAP-06 | No date validation on any date field | Data quality failures |
| GAP-07 | Report creation does not auto-populate from entity | Duplicate data entry |
| GAP-08 | Conclusion templates not in system | Manual copy-paste from Word |
| GAP-09 | No approver delegation mechanism | Workflow bottlenecks |
| GAP-10 | No completion notification to requestor | Manual follow-up required |
| GAP-10b | No rejection notification to requestor | Requestor unaware KYC was rejected; may resubmit without understanding reason |
| GAP-11 | No live KPI dashboard | Manual Excel exports only |
| GAP-12 | No periodic review scheduling | Overdue KYCs not flagged |
| GAP-13 | Password storage insecure | Security risk |
| GAP-14 | Document storage is file-system path, not DMS-integrated | Document retrieval issues |

---

## 5. Acceptance Criteria (for As-Is Functionality)

Each of the following must pass before a replacement system is considered functionally equivalent to the current one:

```
AC-01: A compliance officer can create an entity (natural person or legal entity)
       with all required fields and at least one UBO record.

AC-02: A compliance officer can create a KYC report, link it to an entity,
       upload at least one document, and submit it for approval.

AC-03: A Level 1 approver can view the submitted report (including documents),
       add a comment, and take one of three actions: Approve, RFI, Reject.

AC-04: When an RFI is issued, the contributor receives notification,
       can view the comment, and can resubmit the updated report.

AC-05: For a medium or high-risk report, Level 1 approval routes it
       to the Level 2 queue — not directly to final approval.

AC-06: All approval actions are recorded in ProcessLog with:
       timestamp, user, action type, and comment.

AC-07: A PDF can be generated for any KYC report.
       Draft reports are watermarked "Draft".
       Approved reports have no draft watermark.

AC-08: A user with Contributor role cannot access the approval queue pages.
       A user with Approver role cannot create or edit KYC reports.

AC-09: Reference data (BCP categories, statuses, results, request-by list)
       can be added, edited, and deactivated by an Admin user.

AC-10: Session expires after 30 minutes of inactivity.
       User is redirected to the login page.
```
