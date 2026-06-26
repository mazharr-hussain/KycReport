# KYC Management System — Oracle APEX Technical Design
## Qatari Diar — Enterprise Risk Management & Internal Compliance

**Platform:** Oracle APEX 23.2+  
**Database:** Oracle Database 19c / 21c  
**Integration:** Oracle Fusion HCM (Cloud)  
**Authentication:** Oracle IDCS / OCI IAM (SSO via Fusion)  
**Document Standard:** Technical Design + Process Blueprint  
**Methodology:** PERCEIVE → THINK → ACT → VERIFY → LOOP  

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Oracle Fusion HCM Integration](#2-oracle-fusion-hcm-integration)
3. [Database Schema Design](#3-database-schema-design)
4. [APEX Application Structure](#4-apex-application-structure)
5. [Workflow Engine Design](#5-workflow-engine-design)
6. [Page-by-Page Inventory](#6-page-by-page-inventory)
7. [Security Model](#7-security-model)
8. [Process Flow — APEX Implementation](#8-process-flow--apex-implementation)
9. [Notifications & Email Design](#9-notifications--email-design)
10. [KPI & Reporting Design](#10-kpi--reporting-design)
11. [Implementation Roadmap](#11-implementation-roadmap)

---

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                           │
│              Oracle APEX 23.2 — Universal Theme                     │
│    Pages │ Interactive Reports │ Forms │ Wizards │ Dashboards        │
├─────────────────────────────────────────────────────────────────────┤
│                        APEX ENGINE LAYER                            │
│   APEX Workflow (wwv_flow_workflow) │ APEX Approvals                │
│   Dynamic Actions │ Page Processes │ APEX_MAIL                      │
│   Authorization Schemes │ Authentication (IDCS SSO)                 │
├─────────────────────────────────────────────────────────────────────┤
│                        ORACLE DATABASE LAYER                        │
│   KYC Schema (QD_KYC) │ Packages │ Triggers │ Views                 │
│   Sequences │ Constraints │ Audit Columns                           │
├──────────────────────────┬──────────────────────────────────────────┤
│   ORACLE FUSION HCM      │   ORACLE CONTENT MGMT / OCI STORAGE      │
│   REST API / DB Link     │   Document Storage (BLOB / Object Store) │
│   Employees │ Orgs │ Jobs │   KYC Reports │ Supporting Docs          │
└──────────────────────────┴──────────────────────────────────────────┘
```

### 1.1 Key Platform Decisions

| Decision | Choice | Reason |
|---|---|---|
| Workflow Engine | APEX Built-in Workflow (23.1+) | Native, no custom tables needed for state machine |
| Authentication | IDCS SSO (via Fusion) | Single login — employees use Fusion credentials |
| User Source | Oracle Fusion HCM REST API | Employees, roles, orgs — no manual user creation |
| Document Storage | APEX BLOB columns + OCI Object Storage | Searchable metadata in DB, binary in OCI |
| Notifications | APEX_MAIL + APEX Push Notifications | Native, no external dependency |
| Reporting | APEX Interactive Reports + JET Charts | Zero-code, filterable, exportable |
| Risk Calculator | APEX Page with PL/SQL rules engine | Replaces Excel — consistent, auditable |

---

## 2. Oracle Fusion HCM Integration

### 2.1 What Comes From Fusion (No Manual Entry)

```
Oracle Fusion HCM Cloud
        │
        │  REST API calls (scheduled sync + on-demand)
        │  or DB Link (if on-premise Fusion)
        ▼
┌─────────────────────────────────────┐
│       KYC_FUSION_SYNC Package       │
│  Runs nightly + triggered on login  │
└──────────────┬──────────────────────┘
               │
       ┌───────┼───────────────┐
       ▼       ▼               ▼
  QD_KYC_USERS  QD_KYC_DEPTS  QD_KYC_ORG_UNITS
  (from HCM     (from HCM      (org hierarchy
   PER tables)   Departments)   for routing)
```

### 2.2 Fusion HCM Data Pulled

| Fusion Object | APEX Usage | Fusion REST Endpoint |
|---|---|---|
| **Person / Employee** | KYC requestors, contributors, approvers | `/hcmRestApi/resources/11.13.18.05/emps` |
| **Person Email** | Notification target | `/hcmRestApi/resources/11.13.18.05/emps/{id}/emails` |
| **Person Phone** | Contact data | `/hcmRestApi/resources/11.13.18.05/emps/{id}/phones` |
| **Job / Role** | Derive KYC role (Contributor/Approver) | `/hcmRestApi/resources/11.13.18.05/jobs` |
| **Department** | Route requests to correct compliance team | `/hcmRestApi/resources/11.13.18.05/departments` |
| **Organization Unit** | Org hierarchy for approvals | `/hcmRestApi/resources/11.13.18.05/organizationUnits` |
| **Assignment** | Active/inactive status, reporting line | `/hcmRestApi/resources/11.13.18.05/assignments` |

### 2.3 User Sync Package

```sql
-- Package: QD_KYC_FUSION_SYNC
-- Runs: Nightly via DBMS_SCHEDULER + triggered on first login

CREATE OR REPLACE PACKAGE QD_KYC_FUSION_SYNC AS

  -- Full sync of all active employees
  PROCEDURE sync_all_employees;

  -- Sync single employee (called on login if not found)
  PROCEDURE sync_employee(p_person_id IN VARCHAR2);

  -- Sync departments and org units
  PROCEDURE sync_org_structure;

  -- Map Fusion job roles to KYC roles
  FUNCTION get_kyc_role(p_job_code IN VARCHAR2,
                         p_dept_id  IN VARCHAR2)
    RETURN VARCHAR2; -- Returns: CONTRIBUTOR / APPROVER_L1 / APPROVER_L2 / ADMIN

END QD_KYC_FUSION_SYNC;
```

### 2.4 Role Mapping — Fusion Job to KYC Role

```
Fusion Job/Department                    →  KYC System Role
─────────────────────────────────────────────────────────────
Risk & Compliance Officer                →  CONTRIBUTOR
Risk & Compliance Senior Officer         →  CONTRIBUTOR + APPROVER_L1
Risk & Compliance Manager                →  APPROVER_L1 + APPROVER_L2
Head of Enterprise Risk & Compliance     →  APPROVER_L2 + ADMIN
IT / System Admin                        →  ADMIN
All other departments                    →  REQUESTOR (intake portal only)
```

> **Rule:** A REQUESTOR can only access the intake portal and view status of their own requests. They cannot see the full KYC system. This separation is enforced by APEX Authorization Schemes.

### 2.5 Local User Cache Table

```sql
-- Sync target: employees stored locally for performance
-- Source of truth remains Fusion — this is a read cache

CREATE TABLE QD_KYC_USERS (
  user_id            NUMBER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  fusion_person_id   VARCHAR2(50)   NOT NULL UNIQUE,
  fusion_emp_number  VARCHAR2(30)   NOT NULL,
  username           VARCHAR2(100)  NOT NULL UNIQUE, -- Fusion login / email
  first_name         VARCHAR2(100)  NOT NULL,
  last_name          VARCHAR2(100)  NOT NULL,
  full_name          VARCHAR2(200)  GENERATED ALWAYS AS (first_name || ' ' || last_name) VIRTUAL,
  email              VARCHAR2(200)  NOT NULL,
  phone              VARCHAR2(30),
  department_id      NUMBER,
  job_code           VARCHAR2(50),
  kyc_role           VARCHAR2(30)   NOT NULL, -- REQUESTOR/CONTRIBUTOR/APPROVER_L1/APPROVER_L2/ADMIN
  kyc_role_2         VARCHAR2(30),            -- Secondary role
  is_active          CHAR(1)        DEFAULT 'Y' NOT NULL CHECK (is_active IN ('Y','N')),
  is_on_leave        CHAR(1)        DEFAULT 'N' NOT NULL CHECK (is_on_leave IN ('Y','N')),
  deputy_user_id     NUMBER         REFERENCES QD_KYC_USERS(user_id), -- delegate when on leave
  last_sync_date     TIMESTAMP      DEFAULT SYSTIMESTAMP,
  created_date       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT chk_kyc_role CHECK (kyc_role IN
    ('REQUESTOR','CONTRIBUTOR','APPROVER_L1','APPROVER_L2','ADMIN'))
);

CREATE TABLE QD_KYC_DEPARTMENTS (
  department_id       NUMBER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  fusion_dept_id      VARCHAR2(50)   NOT NULL UNIQUE,
  department_name     VARCHAR2(200)  NOT NULL,
  department_code     VARCHAR2(30),
  parent_dept_id      NUMBER         REFERENCES QD_KYC_DEPARTMENTS(department_id),
  manager_user_id     NUMBER         REFERENCES QD_KYC_USERS(user_id),
  is_active           CHAR(1)        DEFAULT 'Y' NOT NULL,
  last_sync_date      TIMESTAMP      DEFAULT SYSTIMESTAMP
);
```

---

## 3. Database Schema Design

### 3.1 Schema: QD_KYC

All KYC objects reside in the `QD_KYC` schema. The schema is separate from Fusion schema — no direct writes to Fusion tables.

### 3.2 Standard Audit Columns (Applied to All Tables)

Every table includes these columns via a consistent pattern:

```sql
-- Standard audit footer — added to every table
created_by      VARCHAR2(100)  DEFAULT SYS_CONTEXT('APEX$SESSION','APP_USER') NOT NULL,
created_date    TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
updated_by      VARCHAR2(100),
updated_date    TIMESTAMP,
row_version     NUMBER         DEFAULT 1 NOT NULL -- optimistic locking
```

A single trigger template handles `updated_by`, `updated_date`, and `row_version` on every table.

### 3.3 Core Tables

```sql
-- ============================================================
-- INTAKE & CASE MANAGEMENT
-- ============================================================

CREATE TABLE QD_KYC_INTAKE (
  intake_id              NUMBER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  intake_ref             VARCHAR2(30)   NOT NULL UNIQUE,
  -- Auto-generated: INTAKE-YYYY-NNNNNN
  requestor_user_id      NUMBER         NOT NULL REFERENCES QD_KYC_USERS(user_id),
  department_id          NUMBER         NOT NULL REFERENCES QD_KYC_DEPARTMENTS(department_id),
  entity_name            VARCHAR2(500)  NOT NULL,
  entity_type            VARCHAR2(30)   NOT NULL,
  -- NATURAL_PERSON / LEGAL_ENTITY
  entity_country         VARCHAR2(100)  NOT NULL,
  ownership_category     VARCHAR2(50)   NOT NULL,
  -- FULLY_QATARI / QATAR_MAJORITY / QATAR_MINORITY / FOREIGN / QATARI_PERSON / NON_QATARI_PERSON
  relationship_type_id   NUMBER         REFERENCES QD_KYC_REF_RELATIONSHIP(rel_type_id),
  financial_involvement  VARCHAR2(10)   CHECK (financial_involvement IN ('CURRENT','PROPOSED','NONE')),
  related_party_flag     CHAR(1)        DEFAULT 'N' CHECK (related_party_flag IN ('Y','N')),
  related_party_details  VARCHAR2(2000),
  kyc_required           CHAR(1)        CHECK (kyc_required IN ('Y','N')),
  -- Computed by rules engine on submit
  kyc_waiver_reason      VARCHAR2(1000),
  -- Populated if kyc_required = N
  status                 VARCHAR2(30)   DEFAULT 'DRAFT' NOT NULL,
  -- DRAFT / SUBMITTED / DOCS_PENDING / DOCS_COMPLETE / IN_REVIEW / ASSIGNED / CLOSED
  submission_date        TIMESTAMP,
  -- KPI clock point 1: when requestor submitted
  docs_complete_date     TIMESTAMP,
  -- KPI clock point 2: when compliance confirmed docs sufficient
  assigned_date          TIMESTAMP,
  assigned_user_id       NUMBER         REFERENCES QD_KYC_USERS(user_id),
  -- compliance officer assigned
  notes                  VARCHAR2(4000),
  created_by             VARCHAR2(100)  DEFAULT SYS_CONTEXT('APEX$SESSION','APP_USER') NOT NULL,
  created_date           TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
  updated_by             VARCHAR2(100),
  updated_date           TIMESTAMP,
  row_version            NUMBER         DEFAULT 1 NOT NULL
);

-- ============================================================
-- ENTITY (COUNTERPARTY / SEARCH PATTERN)
-- ============================================================

CREATE TABLE QD_KYC_ENTITY (
  entity_id              NUMBER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  entity_ref             VARCHAR2(30)   NOT NULL UNIQUE,
  -- Auto-generated: ENT-YYYY-NNNNNN
  entity_nature          VARCHAR2(20)   NOT NULL CHECK (entity_nature IN ('NATURAL_PERSON','LEGAL_ENTITY')),
  entity_name            VARCHAR2(500)  NOT NULL,

  -- Legal Entity fields
  legal_reg_number       VARCHAR2(100),
  date_of_incorporation  DATE,
  country_of_incorp      VARCHAR2(100),
  country_of_operation   VARCHAR2(100),
  industry_sector        VARCHAR2(100),
  registered_address     VARCHAR2(1000),
  operating_address      VARCHAR2(1000),
  website                VARCHAR2(500),

  -- Natural Person fields
  first_name             VARCHAR2(200),
  middle_name            VARCHAR2(200),
  last_name              VARCHAR2(200),
  nationality_primary    VARCHAR2(100),
  nationality_secondary  VARCHAR2(100),
  country_of_residence   VARCHAR2(100),
  date_of_birth          DATE           CHECK (date_of_birth < SYSDATE),
  id_type                VARCHAR2(30)   CHECK (id_type IN ('QATAR_ID','PASSPORT','NATIONAL_ID','OTHER')),
  id_number              VARCHAR2(100),
  id_issuing_country     VARCHAR2(100),
  id_expiry_date         DATE,

  -- Screening evidence (structured — not free text)
  screening_date         DATE,
  screening_source       VARCHAR2(100),
  -- WORLD_CHECK / OFAC / UN / EU / MANUAL
  screening_ref          VARCHAR2(100),
  -- WorldCheck case reference
  match_status           VARCHAR2(30)   CHECK (match_status IN
    ('NO_MATCH','POTENTIAL_MATCH','CONFIRMED_MATCH','FALSE_POSITIVE')),
  is_pep                 CHAR(1)        DEFAULT 'N' CHECK (is_pep IN ('Y','N')),
  is_sanctioned          CHAR(1)        DEFAULT 'N' CHECK (is_sanctioned IN ('Y','N')),
  adverse_media_flag     CHAR(1)        DEFAULT 'N' CHECK (adverse_media_flag IN ('Y','N')),
  screening_findings     CLOB,
  -- Detailed narrative
  false_positive_reason  VARCHAR2(2000),
  -- If match_status = FALSE_POSITIVE

  -- Entity assessment
  risk_level             VARCHAR2(10)   CHECK (risk_level IN ('LOW','MEDIUM','HIGH')),
  conclusion             CLOB,

  -- Versioning
  version_number         NUMBER         DEFAULT 1 NOT NULL,
  version_status         VARCHAR2(20)   DEFAULT 'CURRENT' NOT NULL
    CHECK (version_status IN ('CURRENT','SUPERSEDED','DRAFT')),
  superseded_by_id       NUMBER         REFERENCES QD_KYC_ENTITY(entity_id),
  chronic_id             NUMBER,
  -- Groups all versions of same entity

  -- Flags
  is_active              CHAR(1)        DEFAULT 'Y' CHECK (is_active IN ('Y','N')),
  duplicate_check_done   CHAR(1)        DEFAULT 'N' CHECK (duplicate_check_done IN ('Y','N')),
  linked_intake_id       NUMBER         REFERENCES QD_KYC_INTAKE(intake_id),

  -- Audit
  created_by             VARCHAR2(100)  DEFAULT SYS_CONTEXT('APEX$SESSION','APP_USER') NOT NULL,
  created_date           TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
  updated_by             VARCHAR2(100),
  updated_date           TIMESTAMP,
  row_version            NUMBER         DEFAULT 1 NOT NULL
);

-- ============================================================
-- UBO / PARTICIPANTS (linked to Legal Entity)
-- ============================================================

CREATE TABLE QD_KYC_UBO (
  ubo_id                 NUMBER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  entity_id              NUMBER         NOT NULL REFERENCES QD_KYC_ENTITY(entity_id) ON DELETE CASCADE,
  participant_type       VARCHAR2(30)   NOT NULL CHECK (participant_type IN ('UBO','AUTH_SIGNATORY','DIRECTOR','SHAREHOLDER')),
  full_name              VARCHAR2(500)  NOT NULL,
  nationality            VARCHAR2(100),
  country_of_residence   VARCHAR2(100),
  date_of_birth          DATE           CHECK (date_of_birth < SYSDATE),
  id_type                VARCHAR2(30)   CHECK (id_type IN ('QATAR_ID','PASSPORT','NATIONAL_ID','OTHER')),
  id_number              VARCHAR2(100),
  id_issuing_country     VARCHAR2(100),
  id_expiry_date         DATE,
  ownership_percentage   NUMBER(5,2)    CHECK (ownership_percentage BETWEEN 0 AND 100),
  control_type           VARCHAR2(20)   CHECK (control_type IN ('DIRECT','INDIRECT','BOTH')),
  residential_address    VARCHAR2(1000),

  -- Screening
  screening_date         DATE,
  screening_source       VARCHAR2(100),
  screening_ref          VARCHAR2(100),
  match_status           VARCHAR2(30)   CHECK (match_status IN
    ('NO_MATCH','POTENTIAL_MATCH','CONFIRMED_MATCH','FALSE_POSITIVE')),
  is_pep                 CHAR(1)        DEFAULT 'N' CHECK (is_pep IN ('Y','N')),
  is_sanctioned          CHAR(1)        DEFAULT 'N' CHECK (is_sanctioned IN ('Y','N')),
  screening_findings     CLOB,
  false_positive_reason  VARCHAR2(2000),
  source_of_information  VARCHAR2(500),

  -- Audit
  created_by             VARCHAR2(100)  DEFAULT SYS_CONTEXT('APEX$SESSION','APP_USER') NOT NULL,
  created_date           TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
  updated_by             VARCHAR2(100),
  updated_date           TIMESTAMP,
  row_version            NUMBER         DEFAULT 1 NOT NULL
);

-- ============================================================
-- KYC REPORT (Core record)
-- ============================================================

CREATE TABLE QD_KYC_REPORT (
  report_id              NUMBER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  report_ref             VARCHAR2(30)   NOT NULL UNIQUE,
  -- Auto-generated: KYC-YYYY-NNNNNN

  -- Links
  intake_id              NUMBER         REFERENCES QD_KYC_INTAKE(intake_id),
  entity_id              NUMBER         NOT NULL REFERENCES QD_KYC_ENTITY(entity_id),
  contributor_user_id    NUMBER         NOT NULL REFERENCES QD_KYC_USERS(user_id),

  -- Classification
  bcp_category_id        NUMBER         REFERENCES QD_KYC_REF_BCP_CATEGORY(bcp_id),
  counterparty_type      VARCHAR2(20)   CHECK (counterparty_type IN ('NATURAL_PERSON','LEGAL_ENTITY')),
  kyc_type               VARCHAR2(20)   NOT NULL
    CHECK (kyc_type IN ('SIMPLIFIED','ADHOC','ENHANCED')),
  due_diligence_type     VARCHAR2(50),
  -- Auto-derived from kyc_type

  -- Request details
  request_made_by_id     NUMBER         REFERENCES QD_KYC_USERS(user_id),
  -- From Fusion user — requestor
  request_date           DATE           NOT NULL,
  -- Validated: not future, not >2 years ago
  relationship_type_id   NUMBER         REFERENCES QD_KYC_REF_RELATIONSHIP(rel_type_id),

  -- Due diligence
  source_of_funds        VARCHAR2(2000),
  -- Mandatory if kyc_type = ENHANCED
  source_of_wealth       VARCHAR2(2000),
  -- Mandatory if kyc_type = ENHANCED

  -- Conclusion
  conclusion_template_id NUMBER         REFERENCES QD_KYC_REF_CONCLUSION_TPL(template_id),
  final_conclusion       CLOB           NOT NULL,
  next_steps             VARCHAR2(4000),

  -- Risk
  risk_level             VARCHAR2(10)   NOT NULL CHECK (risk_level IN ('LOW','MEDIUM','HIGH')),
  risk_justification     VARCHAR2(2000),
  -- Mandatory if overriding system suggestion

  -- Workflow
  report_status          VARCHAR2(30)   DEFAULT 'DRAFT' NOT NULL,
  workflow_instance_id   NUMBER,
  -- APEX Workflow instance ID
  wf_level               NUMBER         DEFAULT 0,
  -- 0=draft, 1=L1, 2=L2

  -- SAR
  sar_flag               CHAR(1)        DEFAULT 'N' CHECK (sar_flag IN ('Y','N')),
  sar_notes              VARCHAR2(4000),

  -- KPI timestamps
  submitted_date         TIMESTAMP,
  l1_approval_date       TIMESTAMP,
  l2_approval_date       TIMESTAMP,
  final_approval_date    TIMESTAMP,
  total_days_to_complete NUMBER         GENERATED ALWAYS AS
    (CASE WHEN final_approval_date IS NOT NULL
          THEN EXTRACT(DAY FROM (final_approval_date - submitted_date))
     END) VIRTUAL,

  -- Review cycle
  next_review_date       DATE,
  review_cycle_months    NUMBER         DEFAULT 36,
  -- 36/24/12 based on risk

  -- Flags
  is_draft               CHAR(1)        DEFAULT 'Y' CHECK (is_draft IN ('Y','N')),

  -- Audit
  created_by             VARCHAR2(100)  DEFAULT SYS_CONTEXT('APEX$SESSION','APP_USER') NOT NULL,
  created_date           TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
  updated_by             VARCHAR2(100),
  updated_date           TIMESTAMP,
  row_version            NUMBER         DEFAULT 1 NOT NULL
);

-- ============================================================
-- PROCESS LOG (Immutable audit trail)
-- ============================================================

CREATE TABLE QD_KYC_PROCESS_LOG (
  log_id                 NUMBER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  report_id              NUMBER         REFERENCES QD_KYC_REPORT(report_id),
  intake_id              NUMBER         REFERENCES QD_KYC_INTAKE(intake_id),
  action_type            VARCHAR2(50)   NOT NULL,
  -- SUBMIT/APPROVE_L1/REJECT_L1/RFI_L1/APPROVE_L2/REJECT_L2/
  -- DOCS_REQUESTED/DOCS_RECEIVED/ASSIGNED/SAR_FLAGGED/REVIEW_DUE
  from_status            VARCHAR2(30),
  to_status              VARCHAR2(30)   NOT NULL,
  action_user_id         NUMBER         NOT NULL REFERENCES QD_KYC_USERS(user_id),
  action_date            TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
  comments               VARCHAR2(4000),
  system_generated       CHAR(1)        DEFAULT 'N' CHECK (system_generated IN ('Y','N'))
  -- Insert-only: no UPDATE or DELETE on this table (enforced by trigger)
);

-- Trigger to block updates/deletes on audit log
CREATE OR REPLACE TRIGGER QD_KYC_PROCESS_LOG_PROTECT
  BEFORE UPDATE OR DELETE ON QD_KYC_PROCESS_LOG
BEGIN
  RAISE_APPLICATION_ERROR(-20001, 'Process log is immutable. Updates and deletes are not permitted.');
END;

-- ============================================================
-- WORKFLOW COMMENTS
-- ============================================================

CREATE TABLE QD_KYC_WF_COMMENTS (
  comment_id             NUMBER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  report_id              NUMBER         REFERENCES QD_KYC_REPORT(report_id),
  intake_id              NUMBER         REFERENCES QD_KYC_INTAKE(intake_id),
  comment_text           CLOB           NOT NULL,
  comment_type           VARCHAR2(30)   CHECK (comment_type IN
    ('GENERAL','RFI_REQUEST','RFI_RESPONSE','APPROVAL_NOTE','REJECTION_REASON','SAR_NOTE')),
  posted_by_user_id      NUMBER         NOT NULL REFERENCES QD_KYC_USERS(user_id),
  posted_date            TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
  wf_status_at_time      VARCHAR2(30),
  is_visible_to_requestor CHAR(1)       DEFAULT 'N' CHECK (is_visible_to_requestor IN ('Y','N'))
);

-- ============================================================
-- DOCUMENTS
-- ============================================================

CREATE TABLE QD_KYC_DOCUMENTS (
  document_id            NUMBER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  document_ref           VARCHAR2(30)   NOT NULL UNIQUE,
  report_id              NUMBER         REFERENCES QD_KYC_REPORT(report_id),
  intake_id              NUMBER         REFERENCES QD_KYC_INTAKE(intake_id),
  entity_id              NUMBER         REFERENCES QD_KYC_ENTITY(entity_id),
  document_type          VARCHAR2(50),
  -- CR / PASSPORT / SHAREHOLDER_CERT / OWNERSHIP_CHART / OTHER
  document_name          VARCHAR2(500)  NOT NULL,
  file_content           BLOB,
  -- Stored in DB for small files (< 10MB)
  oci_object_url         VARCHAR2(1000),
  -- OCI Object Storage URL for large files
  mime_type              VARCHAR2(100),
  file_size_bytes        NUMBER,
  upload_date            TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
  uploaded_by_user_id    NUMBER         NOT NULL REFERENCES QD_KYC_USERS(user_id),
  is_active              CHAR(1)        DEFAULT 'Y' CHECK (is_active IN ('Y','N')),
  notes                  VARCHAR2(1000),
  -- Audit
  created_by             VARCHAR2(100)  DEFAULT SYS_CONTEXT('APEX$SESSION','APP_USER') NOT NULL,
  created_date           TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL
);

-- ============================================================
-- REFERENCE / LOOKUP TABLES
-- ============================================================

CREATE TABLE QD_KYC_REF_BCP_CATEGORY (
  bcp_id        NUMBER        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  bcp_code      VARCHAR2(30)  NOT NULL UNIQUE,
  bcp_name      VARCHAR2(200) NOT NULL,
  bcp_desc      VARCHAR2(500),
  is_active     CHAR(1)       DEFAULT 'Y',
  display_order NUMBER        DEFAULT 1
);

CREATE TABLE QD_KYC_REF_RELATIONSHIP (
  rel_type_id   NUMBER        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  rel_code      VARCHAR2(30)  NOT NULL UNIQUE,
  rel_name      VARCHAR2(200) NOT NULL,
  -- SUPPLIER / BUYER / TENANT / CONTRACTOR / INVESTOR / JV_PARTNER
  is_active     CHAR(1)       DEFAULT 'Y',
  display_order NUMBER        DEFAULT 1
);

CREATE TABLE QD_KYC_REF_CONCLUSION_TPL (
  template_id   NUMBER        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  template_code VARCHAR2(30)  NOT NULL UNIQUE,
  template_name VARCHAR2(200) NOT NULL,
  risk_level    VARCHAR2(10),
  -- Template applies to this risk level
  template_body CLOB          NOT NULL,
  is_active     CHAR(1)       DEFAULT 'Y',
  display_order NUMBER        DEFAULT 1
);

CREATE TABLE QD_KYC_REF_COUNTRY (
  country_code  VARCHAR2(3)   PRIMARY KEY,
  country_name  VARCHAR2(200) NOT NULL,
  country_region VARCHAR2(100),
  fatf_status   VARCHAR2(30),
  -- STANDARD / HIGH_RISK / GREY_LIST / BLACKLIST
  risk_tier     VARCHAR2(10)  DEFAULT 'LOW' CHECK (risk_tier IN ('LOW','MEDIUM','HIGH'))
);

-- ============================================================
-- DUPLICATE DETECTION SUPPORT
-- ============================================================

CREATE TABLE QD_KYC_ENTITY_ALIASES (
  alias_id      NUMBER        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  entity_id     NUMBER        NOT NULL REFERENCES QD_KYC_ENTITY(entity_id),
  alias_name    VARCHAR2(500) NOT NULL,
  alias_type    VARCHAR2(30)  CHECK (alias_type IN ('TRADING_NAME','FORMER_NAME','ABBREVIATION','ARABIC_NAME'))
);

-- ============================================================
-- SEQUENCES for Reference Numbers
-- ============================================================

CREATE SEQUENCE QD_KYC_INTAKE_SEQ  START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE QD_KYC_ENTITY_SEQ  START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE QD_KYC_REPORT_SEQ  START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE QD_KYC_DOC_SEQ     START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
```

### 3.4 Reference Number Generation

```sql
-- Trigger: auto-generate human-readable reference numbers

CREATE OR REPLACE TRIGGER QD_KYC_INTAKE_BIR
  BEFORE INSERT ON QD_KYC_INTAKE
  FOR EACH ROW
BEGIN
  :NEW.intake_ref := 'INTAKE-' || TO_CHAR(SYSDATE,'YYYY') || '-'
                     || LPAD(QD_KYC_INTAKE_SEQ.NEXTVAL, 6, '0');
END;

CREATE OR REPLACE TRIGGER QD_KYC_ENTITY_BIR
  BEFORE INSERT ON QD_KYC_ENTITY
  FOR EACH ROW
BEGIN
  :NEW.entity_ref := 'ENT-' || TO_CHAR(SYSDATE,'YYYY') || '-'
                     || LPAD(QD_KYC_ENTITY_SEQ.NEXTVAL, 6, '0');
  -- Set chronic_id for versioning (groups all versions of same entity)
  IF :NEW.chronic_id IS NULL THEN
    :NEW.chronic_id := QD_KYC_ENTITY_SEQ.CURRVAL;
  END IF;
END;

CREATE OR REPLACE TRIGGER QD_KYC_REPORT_BIR
  BEFORE INSERT ON QD_KYC_REPORT
  FOR EACH ROW
BEGIN
  :NEW.report_ref := 'KYC-' || TO_CHAR(SYSDATE,'YYYY') || '-'
                     || LPAD(QD_KYC_REPORT_SEQ.NEXTVAL, 6, '0');
  -- Auto-derive due diligence type from kyc_type
  :NEW.due_diligence_type :=
    CASE :NEW.kyc_type
      WHEN 'SIMPLIFIED' THEN 'Simplified Due Diligence (SDD)'
      WHEN 'ENHANCED'   THEN 'Enhanced Due Diligence (EDD)'
      ELSE 'Standard Due Diligence'
    END;
  -- Auto-set review cycle based on risk level
  :NEW.review_cycle_months :=
    CASE :NEW.risk_level
      WHEN 'HIGH'   THEN 12
      WHEN 'MEDIUM' THEN 24
      ELSE 36
    END;
  :NEW.next_review_date := ADD_MONTHS(SYSDATE, :NEW.review_cycle_months);
END;
```

### 3.5 KYC Necessity Rules Engine

```sql
CREATE OR REPLACE FUNCTION QD_KYC_RULES.IS_KYC_REQUIRED (
  p_ownership_cat       IN VARCHAR2,
  p_relationship_type   IN VARCHAR2,
  p_financial_flag      IN VARCHAR2,
  p_related_party_flag  IN CHAR
) RETURN CHAR AS
  -- Returns Y/N — replaces the Excel risk calculator
  -- Rules aligned with QD internal KYC Policy
BEGIN
  -- Always required
  IF p_financial_flag IN ('CURRENT','PROPOSED') THEN RETURN 'Y'; END IF;
  IF p_related_party_flag = 'Y' THEN RETURN 'Y'; END IF;
  IF p_ownership_cat IN ('FOREIGN','NON_QATARI_PERSON') THEN RETURN 'Y'; END IF;
  IF p_relationship_type IN ('INVESTOR','JV_PARTNER') THEN RETURN 'Y'; END IF;

  -- Conditional
  IF p_ownership_cat = 'QATAR_MINORITY' AND
     p_relationship_type IN ('SUPPLIER','CONTRACTOR') THEN RETURN 'Y'; END IF;

  -- Default: not required for low-risk domestic
  RETURN 'N';
END;
```

### 3.6 Duplicate Detection Function

```sql
CREATE OR REPLACE FUNCTION QD_KYC_UTILS.CHECK_DUPLICATE_ENTITY (
  p_entity_name    IN VARCHAR2,
  p_legal_reg_no   IN VARCHAR2 DEFAULT NULL,
  p_id_number      IN VARCHAR2 DEFAULT NULL
) RETURN SYS_REFCURSOR AS
  v_cursor SYS_REFCURSOR;
BEGIN
  OPEN v_cursor FOR
    SELECT e.entity_id,
           e.entity_ref,
           e.entity_name,
           e.entity_nature,
           e.version_number,
           e.version_status,
           e.risk_level,
           e.created_date,
           UTL_MATCH.JARO_WINKLER_SIMILARITY(
             UPPER(e.entity_name), UPPER(p_entity_name)
           ) AS name_similarity
    FROM   QD_KYC_ENTITY e
    WHERE  e.version_status = 'CURRENT'
    AND   (
      UTL_MATCH.JARO_WINKLER_SIMILARITY(UPPER(e.entity_name), UPPER(p_entity_name)) > 0.85
      OR (p_legal_reg_no IS NOT NULL AND e.legal_reg_number = p_legal_reg_no)
      OR (p_id_number IS NOT NULL AND e.id_number = p_id_number)
      OR EXISTS (
           SELECT 1 FROM QD_KYC_ENTITY_ALIASES a
           WHERE  a.entity_id = e.entity_id
           AND    UTL_MATCH.JARO_WINKLER_SIMILARITY(UPPER(a.alias_name), UPPER(p_entity_name)) > 0.85
         )
    )
    ORDER BY name_similarity DESC;
  RETURN v_cursor;
END;
```

---

## 4. APEX Application Structure

### 4.1 Application Architecture

```
Application ID: 100 (KYC Management)
Authentication: APEX with IDCS SSO Custom Authentication Scheme
Theme: Universal Theme 42
Navigation Type: Navigation Menu (role-filtered)

Sub-Application ID: 101 (Intake Portal — for Requesting Departments)
Authentication: IDCS SSO (same credentials)
Access: All Fusion employees
Theme: Universal Theme 42 (simplified, minimal navigation)
```

### 4.2 Application Navigation Structure

```
KYC MANAGEMENT APP (App 100)
│
├── DASHBOARD
│     Page 1:  Executive Dashboard (charts, KPIs, pipeline summary)
│     Page 2:  My Worklist (personal queue — role-aware)
│
├── KYC REPORTS
│     Page 10: KYC List (Interactive Report — all KYCs, role-filtered)
│     Page 11: Create KYC Report (Form Wizard — 4 steps)
│     Page 12: View/Edit KYC Report (Master-Detail)
│     Page 13: KYC Approval Queue (Approver role — L1)
│     Page 14: KYC L2 / MLRO Queue (Approver L2 role)
│     Page 15: KYC Search (advanced multi-criteria search)
│
├── ENTITIES
│     Page 20: Entity Search (Interactive Report)
│     Page 21: Create Entity (Form — nature-aware)
│     Page 22: View/Edit Entity (Master-Detail with UBO sub-report)
│     Page 23: Entity Version History (Interactive Report)
│     Page 24: UBO Management (inline editable grid)
│     Page 25: Duplicate Check Results (modal dialog)
│
├── INTAKE MANAGEMENT
│     Page 30: Intake Requests List (Interactive Report)
│     Page 31: Intake Detail / Document Validation (Action page)
│     Page 32: Document Checklist (jurisdiction-aware)
│     Page 33: Assign to Contributor (modal dialog)
│
├── APPROVALS & WORKFLOW
│     Page 40: Approval History (Interactive Report)
│     Page 41: RFI Thread (comment dialog, threaded view)
│     Page 42: SAR Escalation (L2/MLRO only)
│
├── REPORTING & ANALYTICS
│     Page 50: KPI Dashboard (JET Charts)
│     Page 51: Pipeline Report (Interactive Report)
│     Page 52: Overdue KYC Report (Interactive Report)
│     Page 53: Team Performance Report
│     Page 54: Print / PDF Report (Report Query + BI Publisher or APEX_DATA_EXPORT)
│
├── ADMINISTRATION
│     Page 60: User Management (synced from Fusion — view + role override)
│     Page 61: Delegation / Deputy Management
│     Page 62: Reference Data — BCP Categories
│     Page 63: Reference Data — Relationship Types
│     Page 64: Reference Data — Conclusion Templates
│     Page 65: Reference Data — Country Risk Tiers
│     Page 66: Fusion Sync Log (last sync status per entity type)
│
└── INTAKE PORTAL (Sub-App 101 or App 100 restricted pages)
      Page 70: New KYC Request (self-service intake form)
      Page 71: My Requests (requestor sees own submissions only)
      Page 72: Request Status Tracker (timeline view)

```

---

## 5. Workflow Engine Design

### 5.1 APEX Workflow vs Custom

Oracle APEX 23.1+ includes a built-in workflow engine (`APEX_WORKFLOW`). For this design, we use it directly rather than building a custom state machine.

```
APEX Workflow Definition: KYC_APPROVAL_WORKFLOW
  │
  ├── Activity: INTAKE_SUBMITTED
  │     Type: Human Task — Document Validation
  │     Assigned To: Compliance Team (auto-assigned via rules)
  │     Due: 2 business days
  │     Outcome: DOCS_COMPLETE | DOCS_INCOMPLETE
  │
  ├── Activity: CONTRIBUTOR_ASSIGNMENT
  │     Type: System Task — Auto-assignment engine
  │     Logic: Least-loaded available contributor (not on leave)
  │
  ├── Activity: DUE_DILIGENCE
  │     Type: Human Task — Research + Entity Creation + Report Draft
  │     Assigned To: Assigned Contributor
  │     Due: SLA days from docs_complete_date (5/10/20 by KYC type)
  │     Outcome: SUBMITTED_FOR_APPROVAL
  │
  ├── Gateway: RISK_LEVEL_ROUTER
  │     LOW   → Activity: L1_APPROVAL only
  │     MEDIUM → Activity: L1_APPROVAL → L2_APPROVAL
  │     HIGH   → Activity: L1_APPROVAL → L2_APPROVAL (MLRO)
  │
  ├── Activity: L1_APPROVAL
  │     Type: Human Task — Approval
  │     Assigned To: Active L1 Approver (delegate check applied)
  │     Due: 3 business days
  │     Outcome: APPROVED | REJECTED | RFI
  │     On RFI: → Loop back to DUE_DILIGENCE
  │
  ├── Activity: L2_APPROVAL
  │     Type: Human Task — Approval + SAR Gate
  │     Assigned To: Active L2 Approver / MLRO (delegate check applied)
  │     Due: 3 business days
  │     Outcome: APPROVED | REJECTED | RFI | SAR_ESCALATED
  │
  ├── Activity: FINAL_COMPLETE
  │     Type: System Task
  │     Actions:
  │       • Set report_status = 'APPROVED'
  │       • Set final_approval_date = SYSTIMESTAMP
  │       • Generate PDF report (APEX_DATA_EXPORT)
  │       • Send notification to requestor (APEX_MAIL)
  │       • Set next_review_date
  │       • Write ProcessLog entry
  │
  └── Activity: SAR_REVIEW (conditional branch)
        Type: Human Task — MLRO Decision
        Outcome: SAR_FILED | SAR_DISMISSED
        On SAR_DISMISSED: → return to L2_APPROVAL
```

### 5.2 Delegation Logic

```sql
-- Package: QD_KYC_WORKFLOW
-- Called by APEX Workflow to resolve assignee

CREATE OR REPLACE FUNCTION QD_KYC_WORKFLOW.GET_ACTIVE_APPROVER (
  p_role IN VARCHAR2  -- APPROVER_L1 or APPROVER_L2
) RETURN NUMBER AS   -- Returns user_id
  v_user_id NUMBER;
BEGIN
  -- Step 1: Find primary approver who is not on leave
  SELECT user_id INTO v_user_id
  FROM   QD_KYC_USERS
  WHERE  kyc_role = p_role
  AND    is_active = 'Y'
  AND    is_on_leave = 'N'
  AND    ROWNUM = 1
  ORDER BY created_date;

  RETURN v_user_id;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    -- Step 2: All primary approvers on leave — find deputy
    SELECT u.deputy_user_id INTO v_user_id
    FROM   QD_KYC_USERS u
    WHERE  u.kyc_role = p_role
    AND    u.is_active = 'Y'
    AND    u.deputy_user_id IS NOT NULL
    AND    EXISTS (
      SELECT 1 FROM QD_KYC_USERS d
      WHERE  d.user_id = u.deputy_user_id
      AND    d.is_active = 'Y'
      AND    d.is_on_leave = 'N'
    )
    AND ROWNUM = 1;

    RETURN v_user_id;

  WHEN OTHERS THEN
    -- Fallback: alert admin, hold workflow
    QD_KYC_NOTIFICATIONS.SEND_ADMIN_ALERT(
      p_message => 'No active ' || p_role || ' approver found. Workflow held.'
    );
    RETURN NULL;
END;
```

---

## 6. Page-by-Page Inventory

### 6.1 Page 70 — Intake Form (Requestor Portal)
**Access:** All Fusion employees (REQUESTOR role)  
**Purpose:** Replaces unstructured email submissions

```
APEX Page 70: New KYC Request
├── Region: Step 1 — Requestor Details (auto-populated from Fusion session)
│     • Full Name: :APP_USER mapped to QD_KYC_USERS.full_name (read-only)
│     • Department: from Fusion sync (read-only)
│     • Email: from Fusion sync (read-only)
│
├── Region: Step 2 — Entity Information
│     • Entity Name: Text field (triggers duplicate check on blur)
│     • Entity Type: Select List (NATURAL_PERSON / LEGAL_ENTITY)
│     • Entity Country: LOV from QD_KYC_REF_COUNTRY (searchable)
│     • Ownership Category: Select List (6 options)
│     • Relationship Type: Select List from QD_KYC_REF_RELATIONSHIP
│     • Financial Involvement: Radio group (Current / Proposed / None)
│     • Related Party Declaration: Yes/No + conditional text area
│
├── Region: Step 3 — KYC Necessity (Dynamic)
│     • [System calculates in real-time via Dynamic Action calling
│       QD_KYC_RULES.IS_KYC_REQUIRED as Ajax callback]
│     • Result banner: "KYC Required" (amber) or "KYC Not Required" (green)
│     • If Not Required: Waiver reason field shown
│
├── Region: Step 4 — Document Upload
│     • Jurisdiction-aware checklist shown based on entity type + country
│     • Multiple file upload (APEX built-in file upload item)
│     • Each upload: document type dropdown + optional notes
│     • Progress indicator: X of Y required documents uploaded
│
└── Page Process: On Submit
      • Call QD_KYC_RULES.IS_KYC_REQUIRED (final server-side check)
      • Insert QD_KYC_INTAKE
      • Insert QD_KYC_DOCUMENTS (loop uploaded files)
      • If KYC required: Launch APEX Workflow instance
      • Send confirmation email to requestor (APEX_MAIL)
      • Redirect to Page 72 (Request Status Tracker)
```

### 6.2 Page 11 — Create KYC Report (4-Step Wizard)
**Access:** CONTRIBUTOR role  
**Purpose:** Replaces current single-page form with guided wizard

```
APEX Page 11: KYC Report Wizard (Wizard Region, 4 steps)
│
├── Step 1: Entity Selection / Creation
│     • Search bar: "Find existing entity" (calls duplicate check)
│     • Results shown as cards with: entity name, type, risk, last screened date
│     • [Select Existing] → pre-populates Step 2 from entity record
│     • [Create New Entity] → opens entity creation inline
│     • Duplicate Alert: banner if similar entity found
│
├── Step 2: KYC Classification (auto-populated where possible)
│     • Counterparty Designation: pre-filled from entity name (editable)
│     • BCP Category: Select List from QD_KYC_REF_BCP_CATEGORY
│     • Counterparty Type: pre-filled from entity nature (read-only)
│     • KYC Type: Radio group
│       [Dynamic Action: if HIGH risk → ENHANCED forced, others grayed]
│     • Request Made By: Popup LOV from QD_KYC_USERS (filtered by REQUESTOR role)
│       OR pre-filled if linked to intake record
│     • Request Date:
│       - Default = docs_complete_date from intake (if exists)
│       - Validation: NOT NULL, not future, not > 2 years ago
│       - Override with justification field (shown if changed from default)
│     • Relationship Type: pre-filled from intake (editable)
│
├── Step 3: Due Diligence & Conclusion
│     • Source of Funds: [Mandatory if KYC Type = ENHANCED]
│       Dynamic Action: show/hide based on KYC type
│     • Source of Wealth: [Mandatory if KYC Type = ENHANCED]
│     • Final Conclusion:
│       - Conclusion Template: Select List from QD_KYC_REF_CONCLUSION_TPL
│         (filtered by risk level)
│       - [Use Template] button: Dynamic Action populates text area
│       - Conclusion Text Area (editable — full CLOB)
│     • Risk Level: Select List (system suggestion shown as badge)
│       If overriding: Risk Justification text area appears (mandatory)
│     • Next Steps: Text area
│     • SLA Indicator: computed item showing days elapsed vs target
│       [RED/AMBER/GREEN badge computed via PL/SQL function]
│
└── Step 4: Review & Submit
      • Read-only summary of all entered data
      • Document attachments: carried from intake OR upload new
      • Two buttons:
        [Save as Draft] → status = DRAFT, no workflow trigger
        [Submit for Approval] → status = SUBMITTED, triggers workflow
      • Confirmation dialog before submit: "Submit KYC for KYC-2025-000001?"
```

### 6.3 Page 13 — L1 Approval Queue
**Access:** APPROVER_L1 role  
**Purpose:** Replaces /apmaster.xhtml with enriched review panel

```
APEX Page 13: KYC Approval Queue — Level 1

├── Region: Pending Approvals (Interactive Report)
│     Columns: Report Ref | Counterparty | KYC Type | Risk | Contributor |
│              Submitted Date | Days Pending | SLA Status | Actions
│     Filtering: Risk Level | KYC Type | Contributor | Date Range
│     Highlight Row: RED if overdue, AMBER if approaching SLA
│     Action Column: [Review] button → opens modal Page 12 (read-only)
│
├── Region: Approval Action Panel (Modal Dialog)
│     Triggered by [Review] button
│
│     Tab 1: Report Summary
│       • All KYC fields (read-only)
│       • Risk level with colour badge
│       • Screening results (structured: date, source, match status, PEP flag)
│       • Conclusion text
│
│     Tab 2: Entity & UBOs
│       • Entity details
│       • UBO Interactive Grid (read-only)
│       • UBO screening results per row
│
│     Tab 3: Documents
│       • Document list with [View] inline (PDF rendered in browser)
│       • Document type, upload date, uploaded by
│
│     Tab 4: History
│       • ProcessLog for this report (timeline view)
│       • All prior comments and RFI threads
│
│     Action Section (bottom of modal):
│       • Comment text area (mandatory for Reject / RFI)
│       • [Approve] [Request For Info] [Reject] buttons
│
│     Page Processes:
│       • On Approve: Update workflow task → APPROVED_L1
│         Write ProcessLog | If LOW risk → complete | Else → route to L2
│       • On RFI: Write comment to QD_KYC_WF_COMMENTS
│         Send APEX_MAIL to contributor | Update workflow → RFI
│       • On Reject: Write reason | Complete workflow → REJECTED
│         Send notification to contributor + requestor
```

### 6.4 Page 61 — Delegation Management
**Access:** ADMIN role  
**Purpose:** Deputy configuration (new — not in V1)

```
APEX Page 61: Approver Delegation

├── Region: Current Approvers Status (Interactive Report)
│     Columns: Name | Role | Status (Active/On Leave) | Deputy | Deputy Status
│     Edit Deputy: Inline popup LOV to select deputy from active users
│
├── Region: Leave Management
│     Per approver: [Mark as On Leave] / [Return from Leave] toggle
│     When marked On Leave: deputy activation confirmed
│     System automatically routes to deputy until reversed
│
└── Region: Delegation Log
      All delegation activations/deactivations with timestamp and admin user
```

---

## 7. Security Model

### 7.1 Authentication — IDCS SSO

```
User opens APEX app
        │
        ▼
APEX redirects to Oracle IDCS (Fusion Identity Provider)
        │
        ▼
User logs in with Fusion credentials (SSO — no separate KYC password)
        │
        ▼
IDCS returns assertion with:
  - Username (Fusion email)
  - Fusion Person ID
        │
        ▼
APEX Custom Auth Post-Login:
  1. Look up QD_KYC_USERS by username
  2. If not found: call QD_KYC_FUSION_SYNC.sync_employee() — auto-provision
  3. Set APP_USER session
  4. Set custom session state: APP_KYC_ROLE, APP_USER_ID, APP_DEPT_ID
  5. Route to role-appropriate landing page:
     REQUESTOR → Page 70 (Intake Portal)
     CONTRIBUTOR → Page 2 (My Worklist)
     APPROVER_L1 → Page 13 (Approval Queue)
     APPROVER_L2 → Page 14 (L2 Queue)
     ADMIN → Page 1 (Dashboard)
```

### 7.2 Authorization Schemes

```sql
-- Scheme: IS_CONTRIBUTOR
-- Applied to: KYC creation pages, entity management
RETURN APEX_ACL.HAS_USER_ROLE(
  p_application_id => :APP_ID,
  p_user_name      => :APP_USER,
  p_role_static_id => 'CONTRIBUTOR'
);

-- Scheme: IS_APPROVER_L1
-- Applied to: Approval queue pages
RETURN :APP_KYC_ROLE IN ('APPROVER_L1','APPROVER_L2','ADMIN');

-- Scheme: IS_APPROVER_L2
-- Applied to: L2 queue, SAR escalation
RETURN :APP_KYC_ROLE IN ('APPROVER_L2','ADMIN');

-- Scheme: IS_OWN_RECORD
-- Applied to: Edit/delete operations — contributor can only edit own drafts
RETURN :APP_KYC_REPORT_CONTRIBUTOR_ID = :APP_USER_ID
   AND :APP_KYC_REPORT_STATUS = 'DRAFT';

-- Scheme: IS_REQUESTOR_OWN_INTAKE
-- Applied to: Intake status tracker — requestor sees only their submissions
RETURN :APP_KYC_INTAKE_REQUESTOR_ID = :APP_USER_ID;
```

### 7.3 Row-Level Security (VPD)

```sql
-- Oracle Virtual Private Database policy
-- Ensures data filtering happens at DB level — not just APEX

CREATE OR REPLACE FUNCTION QD_KYC_SECURITY.KYC_REPORT_POLICY (
  schema_name IN VARCHAR2,
  table_name  IN VARCHAR2
) RETURN VARCHAR2 AS
  v_role VARCHAR2(30) := SYS_CONTEXT('APEX$SESSION','APP_KYC_ROLE');
  v_user_id VARCHAR2(100) := SYS_CONTEXT('APEX$SESSION','APP_USER_ID');
BEGIN
  RETURN CASE v_role
    WHEN 'ADMIN'       THEN '1=1' -- sees all
    WHEN 'APPROVER_L2' THEN '1=1' -- sees all
    WHEN 'APPROVER_L1' THEN 'wf_level >= 1' -- only submitted+
    WHEN 'CONTRIBUTOR' THEN
      'contributor_user_id = ' || v_user_id ||
      ' OR report_id IN (SELECT report_id FROM QD_KYC_WF_COMMENTS' ||
      ' WHERE comment_type = ''RFI_REQUEST'')' -- own + RFI'd back to them
    ELSE '1=0' -- no access
  END;
END;

-- Apply policy
DBMS_RLS.ADD_POLICY(
  object_schema => 'QD_KYC',
  object_name   => 'QD_KYC_REPORT',
  policy_name   => 'KYC_REPORT_ACCESS',
  function_schema => 'QD_KYC',
  policy_function => 'KYC_SECURITY.KYC_REPORT_POLICY',
  statement_types => 'SELECT,INSERT,UPDATE,DELETE'
);
```

### 7.4 Security Hardening Points

| Control | Implementation |
|---|---|
| No shared passwords | SSO via IDCS — no APEX-local passwords |
| Session fixation | APEX built-in session management |
| CSRF protection | APEX built-in (hidden checksum on all forms) |
| SQL injection | Bind variables enforced by APEX — no dynamic SQL with user input |
| Sensitive data masking | ID numbers masked in IR: `REGEXP_REPLACE(id_number,'(.{4})$','****')` |
| Document access control | Documents served via APEX procedure — not direct URL |
| Audit logging | All DML captured by audit triggers + APEX built-in audit |
| Password policy | N/A — managed by Oracle IDCS (Fusion policy applies) |

---

## 8. Process Flow — APEX Implementation

### 8.1 Happy Path: End-to-End

```
REQUESTING DEPT (Fusion Employee)
    │
    │  Logs in via IDCS (Fusion credentials)
    │  Opens App 100, routed to Page 70
    ▼
PAGE 70: Intake Form
    │  Fusion user details auto-populated (name, dept, email)
    │  Fills entity info, relationship, financial involvement
    │  Dynamic Action calls KYC rules engine → "KYC Required"
    │  Uploads supporting documents
    │  Submits → QD_KYC_INTAKE record created
    │  APEX Workflow instance launched
    │  Email sent: "Your request INTAKE-2025-000001 has been received"
    ▼
COMPLIANCE TEAM NOTIFICATION
    │  APEX_MAIL: "New intake request pending document review"
    │  My Worklist (Page 2) shows new task
    ▼
PAGE 31: Intake Detail (Compliance Officer)
    │  Reviews uploaded documents against jurisdiction checklist
    │  If missing: [Request Documents] → structured RFI email to requestor
    │              Requestor uploads via Page 70 amendment
    │  If complete: [Mark Documents Complete]
    │  docs_complete_date stamped (KPI clock starts)
    ▼
PAGE 33: Assign Contributor (Compliance Manager)
    │  Workload summary shown per officer (active cases count)
    │  Leave indicator shown (from Fusion sync)
    │  [Assign] → intake.assigned_user_id set
    │  Email to assigned officer
    ▼
PAGE 25: Duplicate Check (Auto on entity creation)
    │  QD_KYC_UTILS.CHECK_DUPLICATE_ENTITY() called
    │  Similar entities shown as modal — officer selects or proceeds
    ▼
PAGE 21: Create Entity
    │  Entity details entered (nature-aware form)
    │  Structured screening evidence recorded
    │  UBOs added via interactive grid (Page 24)
    ▼
PAGE 11: Create KYC Report (Wizard)
    │  Step 1: Entity selected — data auto-populated
    │  Step 2: Classification — request details from intake pre-filled
    │  Step 3: Conclusion from template — customized
    │  Step 4: Review — [Submit for Approval]
    │  Workflow task created for L1 Approver
    ▼
PAGE 13: L1 Approval Queue (L1 Approver)
    │  Delegation check: if on leave → deputy receives task
    │  Reviews report, entities, UBOs, documents, history
    │  [Approve] → if LOW risk: final; if MEDIUM/HIGH: routes to L2
    ▼
PAGE 14: L2 Approval Queue (L2/MLRO)
    │  Delegation check applied
    │  SAR Gate question answered (Y/N)
    │  [Approve] → Final complete
    ▼
SYSTEM: Final Completion
    │  PDF report generated (APEX_DATA_EXPORT / BI Publisher)
    │  Email with PDF sent to Requesting Department + Contributor
    │  ProcessLog entry: FINAL_APPROVED
    │  next_review_date set
    │  KPI timestamps available for dashboard
    ▼
PAGE 72: Request Status Tracker (Requestor sees)
    │  "KYC for [Entity Name] — APPROVED"
    │  Download PDF report button
    ▼
END
```

---

## 9. Notifications & Email Design

### 9.1 Notification Matrix

| Event | Recipient | Template | Channel |
|---|---|---|---|
| Intake submitted | Compliance Manager | `INTAKE_RECEIVED` | APEX_MAIL |
| Docs incomplete | Requesting Department | `DOCS_INCOMPLETE` | APEX_MAIL |
| Docs complete, assigned | Contributor | `CASE_ASSIGNED` | APEX_MAIL + APEX Push |
| Report submitted | Active L1 Approver | `APPROVAL_REQUIRED_L1` | APEX_MAIL + APEX Push |
| RFI issued (L1) | Contributor | `RFI_ISSUED` | APEX_MAIL |
| RFI responded | L1 Approver | `RFI_RESPONDED` | APEX_MAIL |
| L1 Approved → L2 | L2 Approver | `APPROVAL_REQUIRED_L2` | APEX_MAIL + APEX Push |
| Report approved (final) | Requestor + Contributor | `KYC_COMPLETE` | APEX_MAIL + PDF attached |
| Report rejected | Requestor + Contributor | `KYC_REJECTED` | APEX_MAIL |
| SAR flagged | Compliance Head + Admin | `SAR_FLAGGED` | APEX_MAIL (high priority) |
| KYC review due (60 days) | Contributor + Manager | `REVIEW_DUE_SOON` | APEX_MAIL |
| KYC overdue for review | Manager + Head | `REVIEW_OVERDUE` | APEX_MAIL |
| Approver set to on-leave | Deputy + Admin | `DELEGATION_ACTIVE` | APEX_MAIL |
| SLA breached | Manager | `SLA_BREACH` | APEX_MAIL |

### 9.2 Email Template Table

```sql
CREATE TABLE QD_KYC_EMAIL_TEMPLATES (
  template_id    NUMBER        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  template_code  VARCHAR2(50)  NOT NULL UNIQUE,
  subject_line   VARCHAR2(500) NOT NULL,
  body_html      CLOB          NOT NULL,
  -- Supports substitution strings: #REPORT_REF#, #ENTITY_NAME#,
  --   #CONTRIBUTOR_NAME#, #APPROVER_NAME#, #APP_URL#, #RISK_LEVEL#
  is_active      CHAR(1)       DEFAULT 'Y'
);

-- Central notification dispatcher
CREATE OR REPLACE PROCEDURE QD_KYC_NOTIFICATIONS.SEND (
  p_template_code IN VARCHAR2,
  p_to_user_id    IN NUMBER,
  p_report_id     IN NUMBER DEFAULT NULL,
  p_intake_id     IN NUMBER DEFAULT NULL,
  p_extra_params  IN VARCHAR2 DEFAULT NULL
) AS
  v_email    VARCHAR2(200);
  v_subject  VARCHAR2(500);
  v_body     CLOB;
BEGIN
  -- Resolve recipient email from QD_KYC_USERS
  SELECT email INTO v_email FROM QD_KYC_USERS WHERE user_id = p_to_user_id;

  -- Load and substitute template
  SELECT subject_line, body_html INTO v_subject, v_body
  FROM   QD_KYC_EMAIL_TEMPLATES WHERE template_code = p_template_code;

  -- Substitution (report ref, entity name, app URL etc.)
  v_body := QD_KYC_UTILS.SUBSTITUTE_TEMPLATE(v_body, p_report_id, p_intake_id);

  -- Send via APEX_MAIL
  APEX_MAIL.SEND(
    p_to      => v_email,
    p_from    => 'kycreport@qataridiar.com',
    p_subj    => v_subject,
    p_html    => v_body
  );
  APEX_MAIL.PUSH_QUEUE;
END;
```

---

## 10. KPI & Reporting Design

### 10.1 KPI View (Source for Dashboard Page 50)

```sql
CREATE OR REPLACE VIEW QD_KYC_V_KPI_DASHBOARD AS
WITH base AS (
  SELECT
    r.report_id,
    r.report_ref,
    r.kyc_type,
    r.risk_level,
    r.report_status,
    r.contributor_user_id,
    u.full_name                                         AS contributor_name,
    r.submitted_date,
    r.final_approval_date,
    r.total_days_to_complete,
    r.next_review_date,
    i.docs_complete_date,
    i.submission_date                                   AS intake_date,
    EXTRACT(YEAR FROM r.submitted_date)                 AS report_year,
    TO_CHAR(r.submitted_date,'YYYY-MM')                 AS report_month,
    CASE r.kyc_type
      WHEN 'SIMPLIFIED' THEN 5
      WHEN 'ENHANCED'   THEN 20
      ELSE 10
    END                                                 AS sla_days,
    CASE
      WHEN r.final_approval_date IS NOT NULL
       AND r.total_days_to_complete <=
           CASE r.kyc_type WHEN 'SIMPLIFIED' THEN 5
                           WHEN 'ENHANCED'   THEN 20 ELSE 10 END
      THEN 'WITHIN_SLA'
      WHEN r.final_approval_date IS NOT NULL
      THEN 'BREACHED_SLA'
      WHEN r.submitted_date IS NOT NULL
       AND SYSDATE - r.submitted_date >
           CASE r.kyc_type WHEN 'SIMPLIFIED' THEN 5
                           WHEN 'ENHANCED'   THEN 20 ELSE 10 END
      THEN 'OVERDUE'
      ELSE 'IN_PROGRESS'
    END                                                 AS sla_status
  FROM   QD_KYC_REPORT r
  JOIN   QD_KYC_USERS u ON u.user_id = r.contributor_user_id
  LEFT JOIN QD_KYC_INTAKE i ON i.intake_id = r.intake_id
)
SELECT
  -- Totals
  COUNT(*)                                              AS total_kycs,
  SUM(CASE WHEN report_status = 'APPROVED'   THEN 1 ELSE 0 END) AS completed,
  SUM(CASE WHEN report_status = 'DRAFT'      THEN 1 ELSE 0 END) AS in_draft,
  SUM(CASE WHEN report_status LIKE '%PENDING%' THEN 1 ELSE 0 END) AS pending_approval,
  SUM(CASE WHEN report_status = 'REJECTED'   THEN 1 ELSE 0 END) AS rejected,
  SUM(CASE WHEN sla_status = 'OVERDUE'       THEN 1 ELSE 0 END) AS overdue,

  -- Averages
  ROUND(AVG(CASE WHEN report_status = 'APPROVED' THEN total_days_to_complete END), 1) AS avg_days_to_complete,

  -- SLA
  ROUND(
    SUM(CASE WHEN sla_status = 'WITHIN_SLA' THEN 1 ELSE 0 END) * 100.0 /
    NULLIF(SUM(CASE WHEN report_status = 'APPROVED' THEN 1 ELSE 0 END), 0), 1
  )                                                     AS sla_compliance_pct,

  -- By risk
  SUM(CASE WHEN risk_level = 'HIGH'   THEN 1 ELSE 0 END) AS high_risk_count,
  SUM(CASE WHEN risk_level = 'MEDIUM' THEN 1 ELSE 0 END) AS medium_risk_count,
  SUM(CASE WHEN risk_level = 'LOW'    THEN 1 ELSE 0 END) AS low_risk_count,

  -- Period
  report_year,
  report_month
FROM base
GROUP BY report_year, report_month;
```

### 10.2 Ongoing Monitoring Scheduler

```sql
-- DBMS_SCHEDULER job: runs nightly at 06:00

BEGIN
  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'QD_KYC_MONITORING_JOB',
    job_type        => 'PLSQL_BLOCK',
    job_action      => '
      BEGIN
        -- 1. Flag KYCs approaching review date (60 days)
        FOR r IN (SELECT * FROM QD_KYC_REPORT
                  WHERE next_review_date BETWEEN SYSDATE AND SYSDATE + 60
                  AND report_status = ''APPROVED'') LOOP
          QD_KYC_NOTIFICATIONS.SEND(
            p_template_code => ''REVIEW_DUE_SOON'',
            p_to_user_id    => r.contributor_user_id,
            p_report_id     => r.report_id
          );
        END LOOP;

        -- 2. Flag overdue reviews (past review date)
        FOR r IN (SELECT * FROM QD_KYC_REPORT
                  WHERE next_review_date < SYSDATE
                  AND report_status = ''APPROVED'') LOOP
          QD_KYC_NOTIFICATIONS.SEND(
            p_template_code => ''REVIEW_OVERDUE'',
            p_to_user_id    => r.contributor_user_id,
            p_report_id     => r.report_id
          );
        END LOOP;

        -- 3. Flag SLA breaches on open reports
        FOR r IN (SELECT * FROM QD_KYC_REPORT
                  WHERE report_status NOT IN (''APPROVED'',''REJECTED'',''DRAFT'')
                  AND submitted_date IS NOT NULL
                  AND SYSDATE - submitted_date >
                      CASE kyc_type WHEN ''SIMPLIFIED'' THEN 5
                                    WHEN ''ENHANCED'' THEN 20 ELSE 10 END) LOOP
          QD_KYC_NOTIFICATIONS.SEND_MANAGER_ALERT(
            p_template_code => ''SLA_BREACH'',
            p_report_id     => r.report_id
          );
        END LOOP;

        -- 4. Sync Fusion employee data
        QD_KYC_FUSION_SYNC.SYNC_ALL_EMPLOYEES;
      END;',
    start_date      => TRUNC(SYSDATE+1) + 6/24,
    repeat_interval => 'FREQ=DAILY;BYHOUR=6;BYMINUTE=0',
    enabled         => TRUE
  );
END;
```

---

## 11. Implementation Roadmap

### Phase A — Foundation (Sprint 1–2, ~4 weeks)

- [ ] Oracle schema creation (QD_KYC): all tables, sequences, triggers, constraints
- [ ] Fusion HCM integration: REST API connection, sync package, user cache
- [ ] APEX application shell: auth (IDCS SSO), navigation, authorization schemes
- [ ] Reference data pages (Pages 62–65): BCP, relationships, conclusion templates, countries
- [ ] User management page (Page 60): view synced users, role override, deputy assignment

### Phase B — Intake & Entity (Sprint 3–4, ~4 weeks)

- [ ] Intake portal (Pages 70–72): form, document upload, KYC rules engine, status tracker
- [ ] Entity management (Pages 20–25): create, search, duplicate detection, version history
- [ ] UBO management (Page 24): interactive grid with structured screening fields
- [ ] Document management: BLOB upload, inline PDF viewer

### Phase C — KYC Report & Workflow (Sprint 5–6, ~4 weeks)

- [ ] KYC report wizard (Page 11): 4-step, auto-population from entity/intake, templates, date validation
- [ ] APEX Workflow definition: all activities, gateways, delegation logic
- [ ] L1 Approval queue (Page 13): enriched review panel, structured action modal
- [ ] L2/MLRO queue (Page 14): SAR gate, final approval
- [ ] Notification system: all email templates, APEX_MAIL dispatcher

### Phase D — Reporting & Monitoring (Sprint 7–8, ~4 weeks)

- [ ] KPI dashboard (Page 50): JET Charts, real-time metrics
- [ ] Pipeline report (Page 51): full interactive report with all filters
- [ ] Overdue/SLA report (Page 52): red/amber indicators
- [ ] Nightly monitoring job (DBMS_SCHEDULER)
- [ ] PDF report generation (APEX_DATA_EXPORT or BI Publisher template)
- [ ] Process log / audit trail viewer

### Phase E — Hardening & Go-Live (Sprint 9–10, ~4 weeks)

- [ ] VPD policies applied and tested
- [ ] Performance tuning: indexes on all FK columns, materialized view for KPI dashboard
- [ ] UAT with compliance team
- [ ] Data migration from current system (if needed)
- [ ] User training (role-based: Requestor / Contributor / Approver)
- [ ] Go-live cutover

---

## Appendix: Key Oracle APEX Features Used

| Feature | Used For |
|---|---|
| `APEX_WORKFLOW` | KYC approval state machine |
| `APEX_MAIL` | All email notifications |
| `APEX_DATA_EXPORT` | PDF report generation |
| `APEX_ACL` | Role-based authorization |
| `APEX_AUTHENTICATION` | IDCS SSO integration |
| Interactive Report | KYC list, entity search, approval queue |
| Interactive Grid | UBO management (inline edit) |
| Dynamic Actions | Real-time form behavior (risk calculator, duplicate check, conditional fields) |
| Wizard Region | 4-step KYC creation wizard |
| Universal Theme | Responsive UI, accessibility compliant |
| JET Charts | KPI dashboard visualizations |
| `UTL_MATCH.JARO_WINKLER_SIMILARITY` | Fuzzy name matching for duplicate detection |
| `DBMS_SCHEDULER` | Nightly monitoring job, Fusion sync |
| `DBMS_RLS` (VPD) | Row-level security on all KYC tables |
| Oracle Sequences | Reference number generation |
| `GENERATED ALWAYS AS IDENTITY` | Surrogate PKs |
| `GENERATED ALWAYS AS ... VIRTUAL` | Computed columns (full_name, total_days, review_cycle) |

---

*Technical design authored for Oracle APEX 23.2+ on Oracle Database 19c/21c with Oracle Fusion HCM Cloud integration.*  
*Standards: FATF 40 Recommendations | Basel KYC | EU 6AMLD | Oracle APEX Best Practices*
