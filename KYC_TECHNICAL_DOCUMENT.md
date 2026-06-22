# KYC Report Management System — Technical Reference Document

**Organization:** Qatari Diar Real Estate Investment Company  
**Department:** Risk Management & Internal Compliance  
**System:** Know Your Customer (KYC) Due Diligence Platform  
**Document Version:** 1.0  
**Date:** June 2026  

---

## Table of Contents

1. [Executive Overview](#1-executive-overview)
2. [Technology Stack & Architecture](#2-technology-stack--architecture)
3. [AVA Framework — Architecture, Value, Application](#3-ava-framework)
4. [Dynamic Workflow Engine](#4-dynamic-workflow-engine)
5. [7 Principles of the KYC System](#5-7-principles-of-the-kyc-system)
6. [Module-by-Module Breakdown](#6-module-by-module-breakdown)
7. [Database Schema & Entity Relationships](#7-database-schema--entity-relationships)
8. [Security & Access Control](#8-security--access-control)
9. [Integration Points](#9-integration-points)
10. [Configuration Reference](#10-configuration-reference)

---

## 1. Executive Overview

The **KYC Report Management System** is an enterprise-grade JavaEE web application purpose-built for Qatari Diar's Risk Management and Internal Compliance department. It provides a structured, auditable digital process for conducting, reviewing, and approving **Know Your Customer (KYC)** and **due diligence** reports on counterparties — natural persons or legal entities — before entering into business relationships.

The system enforces a **multi-level approval workflow** where reports move through clearly defined stages: from initial creation by a compliance contributor, through one or more layers of approval, to final archive. At every stage, actions are logged, comments are recorded, and documents can be attached — creating a full audit trail compliant with international AML/KYC standards.

### Business Problem Solved

| Without System | With System |
|---|---|
| Manual paper-based KYC processes | Fully digital, trackable KYC lifecycle |
| No visibility into approval status | Real-time workflow status dashboard |
| Ad-hoc document handling | Structured document upload & versioning |
| No audit trail | Complete ProcessLog of every action |
| Isolated approver decisions | Collaborative multi-level review with comments |
| Static reports | Dynamic PDF generation with watermarks |

---

## 2. Technology Stack & Architecture

### 2.1 Technology Layers

```
┌─────────────────────────────────────────────────────────────┐
│                     PRESENTATION LAYER                      │
│   XHTML/Facelets + PrimeFaces + Bootstrap + jQuery          │
│   66 XHTML templates across 7 functional modules            │
├─────────────────────────────────────────────────────────────┤
│                   CONTROLLER / BEAN LAYER                   │
│   JSF 2.2 Managed Beans (Kyc, Login, SearchPattern,         │
│   MenuView, PrintController, kyclist, ChartView)            │
├─────────────────────────────────────────────────────────────┤
│                   BUSINESS LOGIC / SERVICES                 │
│   EmailUtil, HtmlEmailSender, SendEmail,                    │
│   ReportsUtils, EntityConverter, EntityExtract,             │
│   DocumentUtils (watermark, PDF header/footer)              │
├─────────────────────────────────────────────────────────────┤
│                   DATA ACCESS LAYER                         │
│   DatabaseOperations (com.qd.dao)                           │
│   Hibernate ORM 3.0 + .hbm.xml mapping files               │
├─────────────────────────────────────────────────────────────┤
│                   PERSISTENCE LAYER                         │
│   Microsoft SQL Server (QDHQSQL25\DB01:53120)               │
│   Database: QDKYC — 14 core tables                          │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Component Inventory

| Layer | Technology | Version |
|---|---|---|
| Web Framework | JavaServer Faces (JSF) | 2.2 |
| UI Components | PrimeFaces | — |
| ORM | Hibernate | 3.0 |
| Database | Microsoft SQL Server | — |
| Styling | Bootstrap (QDbootstrap.css) | Custom |
| Icons | Font Awesome | — |
| JavaScript | jQuery | — |
| Email | SMTP (relay.qataridiar.com:25) | — |
| PDF | iText / PDFRenderer | — |
| Server | JBoss / Tomcat (Java EE 3.0 compatible) | — |

### 2.3 Project Directory Structure

```
/KycReport/
├── WEB-INF/
│   ├── web.xml                    ← Servlet config, session timeout (30 min)
│   ├── faces-config.xml           ← JSF navigation rules, managed bean declarations
│   ├── jboss-web.xml              ← JBoss container config
│   └── classes/
│       ├── hibernate.cfg.xml      ← DB connection string, entity mappings registry
│       ├── KycConfig.properties   ← File paths, SMTP server, app URLs
│       └── com/qd/
│           ├── pojo/              ← 14 Hibernate entity classes + .hbm.xml files
│           ├── dao/               ← DatabaseOperations: all CRUD
│           ├── utlils/            ← Services: email, PDF, charts, converters
│           ├── reports/           ← Report generation classes
│           └── entity/            ← Entity-specific logic classes
├── META-INF/context.xml           ← Tomcat datasource context
├── resources/css/                 ← QDbootstrap.css, QDstyle.css, app styles
├── entity/                        ← 16 XHTML: entity create/edit/search/UBO
├── BackOfficeMaster/              ← 8 XHTML: master data admin pages
├── um/                            ← 6 XHTML: user management pages
├── charts/                        ← 2 XHTML: dashboard visualizations
├── reports/                       ← 2 XHTML: report output pages
├── img/, fonts/                   ← Static assets
└── *.xhtml                        ← 66 root-level KYC workflow pages
```

---

## 3. AVA Framework

The system's design can be understood through the **AVA Framework** — **Architecture**, **Value**, and **Application** — three lenses that reveal how every design decision serves both technical and business goals.

### A — Architecture

The application follows a **classic multi-tier Java EE MVC architecture** with clear separation of concerns:

**Model (POJO + DAO):**  
Hibernate-mapped entity classes (`Kyc`, `Login`, `SearchPattern`, `Ubo`, `KycDocuments`, etc.) represent the domain. All persistence is centralized in `DatabaseOperations`, the single DAO class responsible for all CRUD operations. Hibernate mapping files (`.hbm.xml`) decouple the Java objects from SQL schema, enabling clean migration paths.

**View (XHTML/Facelets):**  
All UI is composed through Facelets templating. A master `commonLayout.xhtml` wraps all standard pages. Specialized layouts (`rfiCommonLayout.xhtml`, `appCommonLayout.xhtml`) serve role-specific views. PrimeFaces components provide rich interactivity without custom JavaScript.

**Controller (JSF Managed Beans):**  
Managed beans act as the glue between view and model. Each functional domain (KYC creation, search, approval, entity management) has its own bean. Navigation outcomes are declared in `faces-config.xml`, not hardcoded in beans — keeping routing logic externalizable.

**Why This Matters Architecturally:**  
The layered design means the PDF generation service (`PrintController`), email service (`EmailUtil`), and database service (`DatabaseOperations`) can each evolve independently. Adding a new notification channel (e.g., SMS) requires only a new service class — the workflow beans call it via the same pattern.

---

### V — Value

The system delivers value across three stakeholder groups:

**Compliance Officers (Contributors):**  
- Eliminates paper forms and manual tracking
- Structured entity screening with UBO capture for legal persons
- Instant PDF report generation with appropriate watermarks (Draft vs. Final)
- Document attachment at every stage of the process

**Approvers & Management:**  
- Real-time approval queue — no email threads or spreadsheets
- In-system comments linked to specific workflow stages
- Color-coded risk levels and statuses for rapid triage
- Full history visible per record (ProcessLog)

**Compliance Department (Organization):**  
- Complete, immutable audit trail from creation to final approval
- Standardized risk classification (Low / Medium / High)
- Multi-level sign-off enforced by system — cannot be bypassed
- Central document repository with date-stamped records

---

### A — Application

The system applies these architectural and value principles through seven distinct functional modules that together cover the complete KYC lifecycle:

1. **Authentication & Role Routing** — Login gateway with role-based page access
2. **KYC Record Management** — Core creation and editing of KYC reports
3. **Entity & UBO Management** — Underlying counterparty data management
4. **Approval Workflow Engine** — Multi-level review and sign-off
5. **Master Data Administration** — Reference data maintenance
6. **User Administration** — Account and role management
7. **Reporting & Analytics** — PDF export and dashboard charts

Each module is detailed in [Section 6](#6-module-by-module-breakdown).

---

## 4. Dynamic Workflow Engine

The KYC system's most critical capability is its **dynamic, multi-level approval workflow**. This is not a static linear process — it can branch (approve, reject, or request further information) at every level, and each branch triggers a different system response.

### 4.1 Workflow States

```
                          ┌────────────┐
                          │   DRAFT    │  ← Created by Contributor
                          └─────┬──────┘
                                │ Submit
                          ┌─────▼──────┐
                          │  SUBMITTED │  ← Awaiting Level 1 Approval
                          └─────┬──────┘
                   ┌────────────┼────────────┐
                Approve      Reject          RFI
           ┌────────▼──┐  ┌────▼────┐  ┌────▼────────┐
           │ L1 APPRVD │  │REJECTED │  │ RFI PENDING │
           └────────┬──┘  └─────────┘  └────┬────────┘
                    │ Submit to L2      Respond to RFI
            ┌───────▼───────┐                │
            │ L2 REVIEW     │◄───────────────┘
            └───────┬───────┘
          ┌─────────┼─────────┐
       Approve    Reject      RFI
    ┌──────▼──┐  ┌───▼──┐  ┌──▼──────┐
    │ APPROVED│  │REJTD │  │ RFI L2  │
    └─────────┘  └──────┘  └─────────┘
```

### 4.2 Workflow Level Field: `wf_level`

The `Kyc` entity carries a `wf_level` field in the database that tracks the current position in the workflow. Combined with `qd_kyc_wf_status`, the system determines:
- Which users can see the record in their queue
- Which action buttons are enabled
- What email notifications fire
- What entry gets written to `ProcessLog`

### 4.3 Workflow Transitions & Actions

| Action | Triggered By | Status Change | Side Effects |
|---|---|---|---|
| **Save Draft** | Contributor | → DRAFT | Record created in DB |
| **Submit** | Contributor | DRAFT → SUBMITTED | ProcessLog entry, email to L1 |
| **Approve (L1)** | Level 1 Approver | SUBMITTED → L1_APPROVED | ProcessLog, email to L2 |
| **Reject (L1)** | Level 1 Approver | SUBMITTED → REJECTED | ProcessLog, email to Contributor |
| **Request Info (RFI)** | Level 1 Approver | SUBMITTED → RFI_PENDING | ProcessLog, email to Contributor |
| **Respond to RFI** | Contributor | RFI_PENDING → SUBMITTED | ProcessLog, email to Approver |
| **Approve (L2)** | Level 2 / RFI Role | L1_APPROVED → APPROVED | ProcessLog, email to Contributor |
| **Reject (L2)** | Level 2 / RFI Role | L1_APPROVED → REJECTED | ProcessLog, rejection email |
| **Archive** | Admin | APPROVED → ARCHIVED | Final status, read-only |

### 4.4 Audit Trail — ProcessLog Table

Every state transition writes a record to the `ProcessLog` table:

```
ProcessLog {
  qd_kyc_log_id    : PK, auto-increment
  qd_proc_ref_no   : FK → Kyc.qd_proc_ref_no
  kyc_wf_status    : The new status after this action
  log_user         : The userId who triggered the action
  kyc_comments     : Free-text notes entered during the action
  log_date         : Server timestamp of the action
}
```

This ensures that every approval, rejection, or comment is permanently attributed, timestamped, and linked to the specific KYC record — forming an immutable compliance audit trail.

### 4.5 Role-to-Page Mapping

```
Role: CONTRIBUTOR
  → /landing.xhtml         (Create new KYC)
  → /master.xhtml          (View own KYC list)
  → /editKycMaster.xhtml   (Edit DRAFT records)
  → /entity/...            (Manage entities)

Role: APPROVER (Level 1)
  → /apmaster.xhtml        (Approval queue)
  → /appsearch.xhtml       (Search approvals)
  → /kyclist.xhtml         (View assigned records)

Role: RFI / Level 2
  → /rfimaster.xhtml       (RFI & L2 approval queue)
  → /rfisearch.xhtml       (Search RFI records)

Role: ADMIN
  → /um/...                (User management)
  → /BackOfficeMaster/...  (Master data tables)
```

Each role sees a completely different navigation menu, rendered by the `MenuView` managed bean based on the session user's role attributes (`role`, `role1`, `role2`).

### 4.6 Workflow Comments — KycWfComments Table

In addition to ProcessLog, the system maintains a `KycWfComments` table that stores all comments exchanged during approval. Unlike ProcessLog (which records system events), KycWfComments captures the human-readable conversation thread — who said what, at which workflow stage — enabling future reviewers to understand the reasoning behind decisions.

### 4.7 Email Notification Flow

```
Action Taken
     │
     ▼
Bean calls EmailUtil / HtmlEmailSender
     │
     ▼
SMTP relay.qataridiar.com:25
     │
     ▼
Recipient determined by wf_level + role:
  - Contributor email (from Login.email_id)
  - Approver email
  - RFI officer email
```

---

## 5. Seven Principles of the KYC System

The system is built around seven foundational principles that guide both its technical implementation and its compliance obligations.

### Principle 1: Identity Verification

**Every counterparty must be fully identified before engagement.**

The system captures comprehensive identity data for both natural and legal persons through the `SearchPattern` entity:
- **Natural Persons:** Full name, Date of Birth, Nationality, ID/Passport Number, Expiry Date
- **Legal Entities:** Legal Registration Number, Country of Registration, Headquarters

For legal entities, the system goes further by mandating **Ultimate Beneficial Owner (UBO)** capture — identifying the natural persons who ultimately own or control the entity, with their own identity data recorded in the `Ubo` table.

*Technical implementation:* `SearchPattern` POJO with `qd_sp_nature` discriminator field; `Ubo` table linked via `qd_sp_id` FK. Entity creation form at `/entity/entityMaster.xhtml` enforces required fields based on person type.

---

### Principle 2: Risk Classification

**Every KYC record carries an explicit, documented risk level.**

The system supports three risk tiers: **Low**, **Medium**, and **High**. Risk is captured at two levels:
1. **Record level** — `Kyc.qd_risk_level`: the overall KYC report risk
2. **Entity level** — `SearchPattern.qd_risk_level`: the individual entity's inherent risk

Color-coded indicators in the UI make risk immediately visible in search results and approval queues, enabling risk-based prioritization of reviews.

*Technical implementation:* `qd_risk_level` field in both `Kyc` and `SearchPattern` tables. `KycReportStatusMaster` table carries `report_color` for visual display.

---

### Principle 3: Due Diligence Tiering

**The depth of investigation must match the risk level.**

The system enforces three due diligence types, corresponding to FATF standards:
- **Simplified KYC (SDD):** Low-risk counterparties; reduced documentation requirements
- **Ad Hoc KYC:** Situational/one-time engagements
- **Enhanced KYC (EDD):** High-risk counterparties requiring deeper scrutiny

`Kyc.qd_due_dig_type` records which tier was applied, and `qd_due_dig_made_by` records the officer responsible — creating accountability for the depth of investigation conducted.

*Technical implementation:* `qd_due_dig_type` field in `Kyc` table. Dropdown populated from configuration; displayed on all report views including PDF exports.

---

### Principle 4: Multi-Level Authorization

**No single person can unilaterally approve a KYC report.**

The workflow engine enforces at minimum two independent approval levels before a KYC record can reach APPROVED status. This separation of duties prevents conflicts of interest and ensures independent scrutiny. The three-way branch (Approve / Reject / RFI) at each level means approvers are not pressured into binary decisions — they can formally request more information while maintaining a clear record that information was requested.

*Technical implementation:* `wf_level` and `qd_kyc_wf_status` fields in `Kyc` table. JSF navigation outcomes in `faces-config.xml` enforce role-appropriate page access. `apmaster.xhtml` for L1; `rfimaster.xhtml` for L2.

---

### Principle 5: Immutable Audit Trail

**Every action taken on a KYC record must be permanently recorded.**

The `ProcessLog` and `KycWfComments` tables together form a complete, tamper-evident history of every KYC record. No record can be approved, rejected, or modified without a corresponding log entry being written. The log captures who acted, what action was taken, what status resulted, and when — to the second.

This principle directly supports regulatory examination requirements, where compliance teams must demonstrate that processes were followed correctly for any given counterparty.

*Technical implementation:* Every bean action method (`KycApprove()`, `KycReject()`, `KycRfi()`) writes to `ProcessLog` before returning a navigation outcome. Log entries are insert-only — no update or delete operations are exposed on this table.

---

### Principle 6: Document Integrity

**Supporting evidence must be attached and preserved with the KYC record.**

The system supports file uploads at KYC creation and editing stages. Each uploaded document is recorded in the `KycDocuments` table with a name, upload date, and file system path. Documents are stored on the application server at `/u01/documents/support/` and `/u01/documents/reports/`.

PDF reports generated by the system carry watermarks: **"DRAFT"** while the record is in progress, and no watermark (or a "Final" stamp) once approved. This prevents draft documents from being treated as authoritative.

*Technical implementation:* `KycDocuments` table with FK to `Kyc`. `PrintController` managed bean handles PDF generation. Document utility classes apply watermark page events. Config in `KycConfig.properties` specifies storage paths.

---

### Principle 7: Continuous Monitoring & Versioning

**KYC records and entities are not static — they must be updated as information changes.**

The entity management module supports **versioning** of SearchPattern records. When an entity's information changes, a new version is created rather than overwriting existing data, preserving the historical record. The `qd_version_no` field in `SearchPattern` tracks this.

The system also records `qd_last_actioned_date` on KYC records and `qd_kyc_report_status` enables tracking through the entire lifecycle including post-approval reviews. `KycConfig.properties` configures the system for ongoing operations (SMTP, file paths, server addresses) — reflecting that this is a living compliance system, not a one-time project.

*Technical implementation:* `qd_version_no` in `SearchPattern`. `EntityReference` and `SPReference` tables handle relational links across versions. Entity version history viewable at `/entity/entityVersionMaster.xhtml`.

---

## 6. Module-by-Module Breakdown

### 6.1 Authentication Module

**Entry point:** `/login.xhtml`  
**Managed Bean:** `Login`  
**Database table:** `Login`

```
User enters credentials
        │
        ▼
Login._loginVerification()
        │
   ┌────▼────┐
   │ DB check│  → userId + userPass match
   └────┬────┘
        │ Match found
        ▼
Session attributes set:
  - userId
  - role / role1 / role2
  - first_name / last_name
  - email_id
        │
        ▼
Navigation outcome → role-appropriate landing page
```

Session timeout is 30 minutes (configured in `web.xml`). On timeout, users are redirected to `/invalid.xhtml` or `/invalidPage.xhtml`. The Login table supports up to three roles per user (`role`, `role1`, `role2`) to accommodate users who fulfil multiple compliance functions.

---

### 6.2 KYC Record Management Module

**Pages:** `/landing.xhtml`, `/editKycMaster.xhtml`, `/editKyc.xhtml`, `/kycoutput.xhtml`  
**Managed Bean:** `Kyc`  
**Database tables:** `Kyc`, `KycDocuments`, `ProcessLog`

**KYC Creation (`/landing.xhtml`):**

The creation form captures:

| Field | Description |
|---|---|
| `qd_proc_ref_no` | Auto-generated process reference number (PK) |
| `qd_subject` | Counterparty name / subject of report |
| `qd_business_counter_catg` | Business Counterparty Category (FK → BCP table) |
| `qd_business_counter_type` | Type classification within category |
| `qd_risk_level` | Low / Medium / High |
| `qd_kyc_report_status` | Current status (from KycReportStatusMaster) |
| `qd_final_conclusion` | Compliance officer's written conclusion |
| `qd_req_date` | Date KYC was requested |
| `qd_due_dig_type` | Simplified / AdHoc / Enhanced |
| `qd_due_dig_made_by` | Officer conducting the due diligence |

Document upload is available during creation — files are stored to the server path in `KycConfig.properties` and metadata saved to `KycDocuments`.

**KYC Search (`/master.xhtml`, `/search.xhtml`):**  
Backed by `kyclist` bean. Supports multi-criteria filtering:
- Process Reference Number (exact)
- Counterparty Designation (partial match)
- Risk Level (dropdown)
- Report Status (dropdown)
- Approval (workflow) Status (dropdown)
- Due Diligence Officer (text)

Results display in a paginated PrimeFaces DataTable (5/10/15 rows per page toggle). Column visibility is togglable.

---

### 6.3 Entity & UBO Management Module

**Pages:** `/entity/` folder (16 XHTML files)  
**Managed Bean:** `SearchPattern`  
**Database tables:** `SearchPattern`, `Ubo`, `EntityReference`, `SPReference`

**Entity Types:**

```
SearchPattern.qd_sp_nature
  ├── "Natural Person"
  │     ├── Full name, DOB, Nationality
  │     ├── ID Number + Expiry
  │     └── Screening results + source
  └── "Legal Person"
        ├── Legal registration number
        ├── Country, headquarters
        ├── Screening results
        └── UBO Records (1..N)
              ├── ubo_name, ubo_type
              ├── ubo_nationality, ubo_dob
              ├── ubo_idno, ubo_id_exp_date
              ├── ubo_results (screening)
              └── ubo_source
```

**Entity-to-KYC Linkage:**  
The `EntityReference` table links KYC records (`qd_proc_ref_no`) to screened entities (`qd_sp_id`). One KYC report can reference multiple entities; each entity can appear in multiple KYC reports. `SPReference` handles related-entity cross-links within entity records.

**Versioning Flow:**  
When entity data changes:
1. Existing record marked with previous version status
2. New record created with incremented `qd_version_no`
3. Entity reference updated to point to new version
4. Previous version remains accessible via `/entity/entityVersionMaster.xhtml`

---

### 6.4 Approval Workflow Module

**Pages:** `/apmaster.xhtml`, `/appsearch.xhtml`, `/rfimaster.xhtml`, `/rfisearch.xhtml`  
**Managed Beans:** `kyclist`, `Kyc`  
**Database tables:** `Kyc`, `ProcessLog`, `KycWfComments`

**Level 1 Approval Interface (`/apmaster.xhtml`):**

The `apmaster.xhtml` page shows only records where `wf_level = 1` and `qd_kyc_wf_status = 'SUBMITTED'`. For each record, the approver can:
- Open a dialog showing full KYC details including linked entities, UBOs, and documents
- Add a comment (written to `KycWfComments`)
- Select **Approve** → updates status, writes ProcessLog, triggers email to L2
- Select **Reject** → updates status, writes ProcessLog, triggers rejection email to Contributor
- Select **Request for Information (RFI)** → updates status, writes ProcessLog, triggers email to Contributor requesting clarification

**Level 2 / RFI Interface (`/rfimaster.xhtml`):**

Mirrors the L1 interface but operates on records that have passed L1 or are in RFI status. This role can issue a final Approve or Reject, giving it the highest authority in the standard flow. The `rfiCommonLayout.xhtml` provides a visually distinct layout to reinforce the role separation.

---

### 6.5 Master Data Administration Module

**Pages:** `/BackOfficeMaster/` (8 XHTML files)  
**Database tables:** `KycReportStatusMaster`, `KycResults`, `KycRequestBy`, `Business_Counterparty_Category`

| Page | Table Managed | Purpose |
|---|---|---|
| `kycReportStatusMaster.xhtml` | `KycReportStatusMaster` | Define statuses and colors |
| `kycResultsMaster.xhtml` | `KycResults` | Define screening result categories |
| `kycRequestByMaster.xhtml` | `KycRequestBy` | Define request originators |
| `bcpCategoryMaster.xhtml` | `Business_Counterparty_Category` | Define BCP categories |

These master tables feed all dropdown lists in the KYC creation and entity forms. Changes here cascade to all new records immediately.

---

### 6.6 User Administration Module

**Pages:** `/um/` (6 XHTML files)  
**Managed Bean:** `Login`  
**Database table:** `Login`

User accounts are managed centrally through this module. Each user record holds:
- `userId` (login credential)
- `userPass` (password — note: stored directly; no evidence of hashing in config)
- `first_name`, `last_name`
- `mobile`, `email_id` (used for workflow notifications)
- `role`, `role1`, `role2` (up to three simultaneous roles)

The multi-role support means a senior officer can act as both Contributor and Approver for different KYC reports without needing separate accounts, while the workflow logic still enforces that the same user cannot approve their own submission.

---

### 6.7 Reporting & Analytics Module

**Pages:** `/charts/`, `/reports/`, `/Print.xhtml`, `/output.xhtml`, `/outputPage.xhtml`  
**Managed Beans:** `PrintController`, `ChartView`, `ReportsUtils`

**PDF Report Generation:**  
`PrintController.getPdf()` generates full KYC reports as PDFs. The output includes:
- Report header with Qatari Diar branding
- KYC record metadata
- Entity and UBO details
- Screening results and conclusions
- Document attachment list
- Workflow comment history
- Watermark applied based on `qd_kyc_wf_status`:
  - **DRAFT watermark** — records not yet approved
  - **No watermark** — finalized/approved records

**Dashboard Charts:**  
The `ChartView` bean populates PrimeFaces chart components in `/charts/`. These provide visual breakdowns of KYC records by status, risk level, and date — giving management instant visibility into compliance pipeline health.

---

## 7. Database Schema & Entity Relationships

### 7.1 Core Entity Relationship Overview

```
Login ──────────────────────────────────────── (1 user → N KYC records as creator)
   │
   └── userId (FK in Kyc.qd_due_dig_made_by, ProcessLog.log_user)

Kyc ─────────────────────────────────────────── (1 KYC → N Documents)
   │  qd_proc_ref_no (PK)                         └── KycDocuments.qd_proc_ref_id
   │
   ├── → ProcessLog (1 KYC → N log entries)
   ├── → KycWfComments (1 KYC → N comments)
   ├── → EntityReference (1 KYC → N entity links)
   │         └── SearchPattern.qd_sp_id (FK)
   │                   └── Ubo (1 Entity → N UBO records)
   │
   ├── → Business_Counterparty_Category (FK)
   ├── → KycReportStatusMaster (FK → report_status)
   └── → KycRequestBy (FK → request originator)

SearchPattern ───────────────────────────────── (1 SP → N UBO records)
   │  qd_sp_id (PK)                               └── Ubo.qd_sp_id
   │
   └── → SPReference (entity cross-links)
              └── → Countries (FK → country_name)
```

### 7.2 Full Table Definitions

**Table: Kyc**
| Column | Type | Description |
|---|---|---|
| `qd_proc_ref_no` | PK | Auto-generated process reference |
| `qd_subject` | VARCHAR | Counterparty name |
| `qd_business_counter_catg` | VARCHAR | Business category |
| `qd_business_counter_type` | VARCHAR | Business type |
| `qd_risk_level` | VARCHAR | Low / Medium / High |
| `qd_kyc_report_status` | VARCHAR | FK → KycReportStatusMaster |
| `qd_kyc_wf_status` | VARCHAR | Current workflow state |
| `qd_final_conclusion` | TEXT | Officer's conclusion text |
| `qd_req_date` | DATE | Request origination date |
| `qd_due_dig_type` | VARCHAR | SDD / AdHoc / EDD |
| `qd_due_dig_made_by` | VARCHAR | FK → Login.userId |
| `wf_level` | INT | Current workflow level (1 or 2) |
| `qd_last_actioned_date` | DATETIME | Timestamp of last status change |

**Table: SearchPattern (KycSP)**
| Column | Type | Description |
|---|---|---|
| `qd_sp_id` | PK | Entity identifier |
| `qd_sp_name` | VARCHAR | Entity name |
| `qd_sp_nature` | VARCHAR | Natural Person / Legal Person |
| `spResults` | TEXT | Screening results narrative |
| `spConclusion` | TEXT | Analyst conclusion |
| `qd_risk_level` | VARCHAR | Entity-level risk |
| `qd_sp_status` | VARCHAR | Entity status |
| `qd_version_no` | INT | Version counter for entity |
| `qd_legal_reg_no` | VARCHAR | Legal entity registration number |
| `qd_natural_person_dob` | DATE | Natural person date of birth |
| `qd_natural_person_nationality` | VARCHAR | Nationality |

**Table: Ubo**
| Column | Type | Description |
|---|---|---|
| `qd_ubo_id` | PK | UBO record identifier |
| `ubo_name` | VARCHAR | Beneficial owner name |
| `ubo_type` | VARCHAR | Ownership type |
| `ubo_nationality` | VARCHAR | Nationality |
| `ubo_dob` | DATE | Date of birth |
| `ubo_idno` | VARCHAR | ID / passport number |
| `ubo_results` | TEXT | Screening results |
| `ubo_source` | VARCHAR | Source of information |
| `ubo_id_exp_date` | DATE | ID document expiry |

---

## 8. Security & Access Control

### 8.1 Authentication

- Session-based authentication via `Login` managed bean
- Session attributes (`userId`, `role`) checked on every page via JSF navigation guards
- Session timeout: 30 minutes (configured in `web.xml`)
- Invalid/expired sessions redirect to `/invalid.xhtml`

### 8.2 Role-Based Access Control

| Role | Create KYC | Edit KYC | L1 Approve | L2 Approve | Admin Master Data | User Admin |
|---|---|---|---|---|---|---|
| Contributor | ✓ | ✓ (own drafts) | — | — | — | — |
| Approver | — | — | ✓ | — | — | — |
| RFI/L2 | — | — | — | ✓ | — | — |
| Admin | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

### 8.3 Security Considerations & Recommendations

> **⚠ Password Storage:** The `Login` table stores credentials directly. Passwords should be hashed using BCrypt or Argon2 before storage. This is the highest-priority security remediation.

> **⚠ SQL Injection:** Hibernate parameterized queries provide protection for ORM-managed queries. Any native SQL in `DatabaseOperations` should be reviewed to ensure PreparedStatement usage throughout.

> **⚠ CSRF Protection:** JSF 2.2 includes built-in CSRF token management via ViewState. Ensure `javax.faces.STATE_SAVING_METHOD` is configured appropriately.

---

## 9. Integration Points

### 9.1 Email Notification System

```
KycConfig.properties:
  smtp.host = relay.qataridiar.com
  smtp.port = 25

Classes:
  EmailUtil         — basic text email
  HtmlEmailSender   — HTML-formatted email
  SendEmail         — email dispatch wrapper

Trigger points:
  - KYC submitted for approval → email to L1 Approver
  - KYC approved at L1 → email to L2 / Contributor
  - KYC rejected → email to Contributor
  - RFI issued → email to Contributor
  - RFI responded → email to issuing Approver
  - Final approval → email to Contributor
```

### 9.2 File System Integration

```
KycConfig.properties:
  support.doc.path = /u01/documents/support/
  report.doc.path  = /u01/documents/reports/

Operations:
  - Upload: MultipartRequest → server file system → path stored in KycDocuments
  - Download: Server path retrieved from DB → FileInputStream → HTTP response
  - PDF: Generated in memory by PrintController → written to reports path
```

### 9.3 Database Connection

```
hibernate.cfg.xml:
  connection.url      = jdbc:sqlserver://QDHQSQL25\DB01:53120;databaseName=QDKYC
  connection.driver   = com.microsoft.sqlserver.jdbc.SQLServerDriver
  dialect             = org.hibernate.dialect.SQLServerDialect
  hbm2ddl.auto       = [not create — production schema managed separately]
```

---

## 10. Configuration Reference

### 10.1 KycConfig.properties

| Property | Purpose |
|---|---|
| `smtp.host` | SMTP relay hostname |
| `smtp.port` | SMTP port (default 25) |
| `support.doc.path` | File system path for support documents |
| `report.doc.path` | File system path for generated PDF reports |
| `server.base.url` | Application base URL for email links |

### 10.2 web.xml Key Settings

| Setting | Value | Purpose |
|---|---|---|
| `session-timeout` | 30 | Session expiry in minutes |
| JSF servlet mapping | `*.xhtml` | All XHTML served via FacesServlet |
| Welcome file | `login.xhtml` | Default entry page |

### 10.3 faces-config.xml Navigation Rules

Navigation outcomes are declared centrally in `faces-config.xml`. Key outcomes:

| From-View | Outcome | To-View |
|---|---|---|
| `login.xhtml` | `loginSuccess_contributor` | `landing.xhtml` |
| `login.xhtml` | `loginSuccess_approver` | `apmaster.xhtml` |
| `login.xhtml` | `loginSuccess_rfi` | `rfimaster.xhtml` |
| `landing.xhtml` | `kycSaved` | `kycoutput.xhtml` |
| `apmaster.xhtml` | `kycApproved` | `apmaster.xhtml` |
| `apmaster.xhtml` | `kycRejected` | `apmaster.xhtml` |
| `apmaster.xhtml` | `kycRFI` | `apmaster.xhtml` |

---

## Appendix: Key File Reference

| File | Location | Purpose |
|---|---|---|
| `web.xml` | `/WEB-INF/` | Servlet config, session timeout |
| `faces-config.xml` | `/WEB-INF/` | JSF navigation, managed beans |
| `hibernate.cfg.xml` | `/WEB-INF/classes/` | DB connection, entity mappings |
| `KycConfig.properties` | `/WEB-INF/classes/` | SMTP, file paths, server URL |
| `commonLayout.xhtml` | `/` | Master page template |
| `login.xhtml` | `/` | Authentication entry point |
| `landing.xhtml` | `/` | KYC creation form |
| `master.xhtml` | `/` | KYC search/list page |
| `apmaster.xhtml` | `/` | Level 1 approval queue |
| `rfimaster.xhtml` | `/` | Level 2 / RFI queue |
| `entityMaster.xhtml` | `/entity/` | Entity creation |
| `entitySearchMaster.xhtml` | `/entity/` | Entity search |
| `userManagementMaster.xhtml` | `/um/` | User admin |
| `Print.xhtml` | `/` | PDF print view |

---

*Document generated from source code analysis of the KYC Report Management System — Qatari Diar Real Estate Investment Company.*
