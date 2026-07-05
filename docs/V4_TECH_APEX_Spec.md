# Version 4 — Technical Specification
# Oracle APEX Developer Guide

**Document Type:** Technical Specification — Developer Reference  
**Audience:** Oracle APEX Developers, DBAs, Integration Architects  
**Platform:** Oracle APEX 23.2 | Oracle Database 19c/21c | Oracle Fusion HCM Cloud  
**Schema:** QD_KYC  
**Authentication:** Oracle IDCS SSO (Fusion credentials)  

---

## 1. Development Environment Setup

### 1.1 Prerequisites

| Component | Version | Notes |
|---|---|---|
| Oracle APEX | 23.2 minimum | Universal Theme required |
| Oracle Database | 19c or 21c | Enterprise Edition recommended (for VPD/Advanced Security) |
| Oracle REST Data Services (ORDS) | 23.x | Required to serve APEX |
| Oracle Fusion HCM | Cloud (any current release) | REST APIs must be accessible from DB server |
| OCI Object Storage | — | Optional: for large document files > 10MB |
| Oracle IDCS | — | Required for SSO; must be configured as Identity Provider |

### 1.2 Schema Creation

```sql
-- Create dedicated schema
CREATE USER qd_kyc IDENTIFIED BY "<strong-password>"
  DEFAULT TABLESPACE kyc_data
  TEMPORARY TABLESPACE temp
  QUOTA UNLIMITED ON kyc_data;

GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE,
      CREATE TRIGGER, CREATE PROCEDURE, CREATE TYPE,
      CREATE SYNONYM TO qd_kyc;

-- Grant APEX workspace access
BEGIN
  APEX_INSTANCE_ADMIN.ADD_WORKSPACE(
    p_workspace_id   => NULL,
    p_workspace      => 'QD_KYC',
    p_primary_schema => 'QD_KYC'
  );
END;
```

---

## 2. Database Objects

### 2.1 Core Tables (DDL Summary)

All tables follow these standards:
- Primary key: `NUMBER GENERATED ALWAYS AS IDENTITY`
- Audit columns on every table: `created_by`, `created_date`, `updated_by`, `updated_date`, `row_version`
- `created_by` defaults to `SYS_CONTEXT('APEX$SESSION','APP_USER')`
- `created_date` defaults to `SYSTIMESTAMP`
- Enum-style columns enforced via `CHECK` constraints (no lookup join needed for validation)

**Key tables:**

| Table | Purpose | Key FK Relationships |
|---|---|---|
| `QD_KYC_USERS` | Fusion employee cache + KYC roles | `deputy_user_id → QD_KYC_USERS` |
| `QD_KYC_DEPARTMENTS` | Fusion org cache | `manager_user_id → QD_KYC_USERS` |
| `QD_KYC_INTAKE` | Digital intake submissions | `requestor_user_id`, `department_id`, `assigned_user_id` |
| `QD_KYC_ENTITY` | Counterparty records with versioning | `superseded_by_id → QD_KYC_ENTITY` |
| `QD_KYC_UBO` | UBO/participant records | `entity_id → QD_KYC_ENTITY` |
| `QD_KYC_REPORT` | KYC reports | `intake_id`, `entity_id`, `contributor_user_id` |
| `QD_KYC_PROCESS_LOG` | Immutable audit trail | `report_id`, `intake_id`, `action_user_id` |
| `QD_KYC_WF_COMMENTS` | Workflow comments/RFI thread | `report_id`, `intake_id`, `posted_by_user_id` |
| `QD_KYC_DOCUMENTS` | File attachments (BLOB or OCI) | `report_id`, `intake_id`, `entity_id` |
| `QD_KYC_REF_*` | Reference/lookup tables | None — standalone |

Full DDL is in `../KYC_APEX_DESIGN.md` Section 3.

### 2.2 Audit Trigger Template

Apply to every table in the schema:

```sql
CREATE OR REPLACE TRIGGER QD_KYC_<TABLE>_AUR
  BEFORE INSERT OR UPDATE ON QD_KYC_<TABLE>
  FOR EACH ROW
BEGIN
  IF INSERTING THEN
    :NEW.created_by   := NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), USER);
    :NEW.created_date := SYSTIMESTAMP;
    :NEW.row_version  := 1;
  ELSIF UPDATING THEN
    :NEW.updated_by   := NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), USER);
    :NEW.updated_date := SYSTIMESTAMP;
    :NEW.row_version  := NVL(:OLD.row_version, 0) + 1;
  END IF;
END;
```

### 2.3 Immutable Process Log

```sql
-- CRITICAL: This trigger must never be removed or disabled
CREATE OR REPLACE TRIGGER QD_KYC_PROCESS_LOG_PROTECT
  BEFORE UPDATE OR DELETE ON QD_KYC_PROCESS_LOG
BEGIN
  RAISE_APPLICATION_ERROR(-20001,
    'QD_KYC_PROCESS_LOG is an immutable audit table. '
    || 'UPDATE and DELETE operations are not permitted.');
END;
```

### 2.4 Reference Number Triggers

```sql
-- Intake reference: INTAKE-YYYY-000001
CREATE OR REPLACE TRIGGER QD_KYC_INTAKE_BIR
  BEFORE INSERT ON QD_KYC_INTAKE FOR EACH ROW
BEGIN
  :NEW.intake_ref := 'INTAKE-' || TO_CHAR(SYSDATE,'YYYY')
                     || '-' || LPAD(QD_KYC_INTAKE_SEQ.NEXTVAL,6,'0');
END;

-- Entity reference: ENT-YYYY-000001 + chronic_id seeding
CREATE OR REPLACE TRIGGER QD_KYC_ENTITY_BIR
  BEFORE INSERT ON QD_KYC_ENTITY FOR EACH ROW
BEGIN
  :NEW.entity_ref := 'ENT-' || TO_CHAR(SYSDATE,'YYYY')
                     || '-' || LPAD(QD_KYC_ENTITY_SEQ.NEXTVAL,6,'0');
  IF :NEW.chronic_id IS NULL THEN
    :NEW.chronic_id := QD_KYC_ENTITY_SEQ.CURRVAL;
  END IF;
END;

-- KYC reference: KYC-YYYY-000001 + derived fields
CREATE OR REPLACE TRIGGER QD_KYC_REPORT_BIR
  BEFORE INSERT ON QD_KYC_REPORT FOR EACH ROW
BEGIN
  :NEW.report_ref := 'KYC-' || TO_CHAR(SYSDATE,'YYYY')
                     || '-' || LPAD(QD_KYC_REPORT_SEQ.NEXTVAL,6,'0');
  :NEW.due_diligence_type := CASE :NEW.kyc_type
    WHEN 'SIMPLIFIED' THEN 'Simplified Due Diligence (SDD)'
    WHEN 'ENHANCED'   THEN 'Enhanced Due Diligence (EDD)'
    ELSE 'Standard Due Diligence' END;
  :NEW.review_cycle_months := CASE :NEW.risk_level
    WHEN 'HIGH' THEN 12 WHEN 'MEDIUM' THEN 24 ELSE 36 END;
  :NEW.next_review_date := ADD_MONTHS(SYSDATE, :NEW.review_cycle_months);
END;
```

---

## 3. Oracle Fusion HCM Integration

### 3.1 REST API Connectivity

```sql
-- Set up Web Credential in APEX (Admin → Manage Instance → Web Credentials)
-- Credential Name: FUSION_HCM_CRED
-- Type: HTTP Basic Authentication
-- Username: <Fusion integration user>
-- Password: <stored securely in APEX credential store>

-- Define REST Data Source in APEX workspace or use UTL_HTTP in PL/SQL

-- Test connection:
DECLARE
  v_response CLOB;
BEGIN
  v_response := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
    p_url         => :FUSION_BASE_URL || '/hcmRestApi/resources/11.13.18.05/emps?limit=1',
    p_http_method => 'GET',
    p_credential_static_id => 'FUSION_HCM_CRED'
  );
  DBMS_OUTPUT.PUT_LINE(SUBSTR(v_response,1,500));
END;
```

### 3.2 Sync Package Interface

```sql
-- Package specification: QD_KYC_FUSION_SYNC

CREATE OR REPLACE PACKAGE QD_KYC_FUSION_SYNC AS
  c_fusion_base_url  CONSTANT VARCHAR2(200) := 'https://<fusion-host>';
  c_credential_name  CONSTANT VARCHAR2(100) := 'FUSION_HCM_CRED';

  PROCEDURE sync_all_employees;
  PROCEDURE sync_employee(p_person_id IN VARCHAR2);
  PROCEDURE sync_org_structure;
  FUNCTION  get_kyc_role(p_job_code IN VARCHAR2, p_dept_id IN VARCHAR2) RETURN VARCHAR2;
END;
```

### 3.3 Role Mapping Logic

```sql
FUNCTION get_kyc_role(p_job_code IN VARCHAR2, p_dept_id IN VARCHAR2) RETURN VARCHAR2 AS
BEGIN
  -- Map Fusion job codes to KYC roles
  -- Adjust job codes to match your Fusion configuration
  RETURN CASE
    WHEN p_job_code LIKE '%RISK_COMPLIANCE_HEAD%'    THEN 'APPROVER_L2'
    WHEN p_job_code LIKE '%RISK_COMPLIANCE_MGR%'     THEN 'APPROVER_L1'
    WHEN p_job_code LIKE '%RISK_COMPLIANCE_SR%'      THEN 'CONTRIBUTOR'
    WHEN p_job_code LIKE '%RISK_COMPLIANCE%'         THEN 'CONTRIBUTOR'
    WHEN p_job_code LIKE '%IT_ADMIN%'                THEN 'ADMIN'
    ELSE 'REQUESTOR'
  END;
END;
```

### 3.4 Nightly Sync Job

```sql
BEGIN
  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'QD_KYC_FUSION_SYNC_JOB',
    job_type        => 'PLSQL_BLOCK',
    job_action      => 'BEGIN QD_KYC_FUSION_SYNC.SYNC_ALL_EMPLOYEES;
                              QD_KYC_FUSION_SYNC.SYNC_ORG_STRUCTURE; END;',
    start_date      => TRUNC(SYSDATE+1) + 2/24,  -- 02:00 AM nightly
    repeat_interval => 'FREQ=DAILY;BYHOUR=2;BYMINUTE=0',
    enabled         => TRUE,
    comments        => 'Sync Fusion HCM employees and org structure to QD_KYC_USERS'
  );
END;
```

---

## 4. APEX Application Configuration

### 4.1 Application Settings

| Setting | Value |
|---|---|
| Application ID | 100 |
| Application Name | QD KYC Management |
| Authentication Scheme | IDCS SSO (Custom) |
| Authorization Scheme | Must Not Be Public User |
| Theme | Universal Theme (Theme 42) |
| Navigation Type | Navigation Menu |
| Logout URL | /ords/apex_authentication.logout |
| Session Timeout | 1800 seconds (30 min) |
| Maximum Session Idle | 900 seconds (15 min) |
| Error Handling Function | `qd_kyc_apex_error_handler` |

### 4.2 Authentication Scheme (IDCS SSO)

```
Type: Oracle IDCS / Social Sign-In
Provider: Oracle Identity Cloud Service
Client ID: <APEX app registered in IDCS>
Client Secret: stored in APEX Web Credentials
Scope: openid profile email

Post-Authentication Procedure: QD_KYC_AUTH.POST_LOGIN
  -- This procedure:
  --   1. Looks up user in QD_KYC_USERS by email
  --   2. If not found: calls QD_KYC_FUSION_SYNC.SYNC_EMPLOYEE to auto-provision
  --   3. Sets APP session state:
  --        APP_KYC_ROLE    := user's kyc_role
  --        APP_USER_ID     := user's user_id
  --        APP_DEPT_ID     := user's department_id
  --        APP_FULL_NAME   := user's full_name
  --   4. Redirects to role-appropriate landing page
```

### 4.3 Authorization Schemes

Define these schemes and apply to pages/buttons/regions:

```
IS_CONTRIBUTOR    → :APP_KYC_ROLE IN ('CONTRIBUTOR','APPROVER_L1','APPROVER_L2','ADMIN')
IS_APPROVER_L1    → :APP_KYC_ROLE IN ('APPROVER_L1','APPROVER_L2','ADMIN')
IS_APPROVER_L2    → :APP_KYC_ROLE IN ('APPROVER_L2','ADMIN')
IS_ADMIN          → :APP_KYC_ROLE = 'ADMIN'
IS_OWN_DRAFT      → :APP_KYC_ROLE IN ('CONTRIBUTOR','ADMIN')
                    AND :P12_CONTRIBUTOR_USER_ID = :APP_USER_ID
                    AND :P12_REPORT_STATUS = 'DRAFT'
IS_REQUESTOR      → :APP_KYC_ROLE = 'REQUESTOR'
NOT_REQUESTOR     → :APP_KYC_ROLE != 'REQUESTOR'
```

### 4.4 Virtual Private Database (Row-Level Security)

Apply after schema creation — ensures data filtering at DB level:

```sql
CREATE OR REPLACE FUNCTION QD_KYC_SECURITY.REPORT_POLICY(
  schema_name VARCHAR2, table_name VARCHAR2
) RETURN VARCHAR2 AS
  v_role    VARCHAR2(30) := SYS_CONTEXT('APEX$SESSION','APP_KYC_ROLE');
  v_uid     VARCHAR2(20) := SYS_CONTEXT('APEX$SESSION','APP_USER_ID');
BEGIN
  RETURN CASE v_role
    WHEN 'ADMIN'       THEN '1=1'
    WHEN 'APPROVER_L2' THEN '1=1'
    WHEN 'APPROVER_L1' THEN 'wf_level >= 1'
    WHEN 'CONTRIBUTOR' THEN
      'contributor_user_id = ' || v_uid ||
      ' OR report_id IN (SELECT report_id FROM QD_KYC_WF_COMMENTS ' ||
      'WHERE comment_type = ''RFI_REQUEST'')'
    ELSE '1=0'
  END;
END;

EXEC DBMS_RLS.ADD_POLICY('QD_KYC','QD_KYC_REPORT','KYC_REPORT_POLICY',
  'QD_KYC_SECURITY','REPORT_POLICY','SELECT,INSERT,UPDATE,DELETE');
```

---

## 5. Page Specifications

### 5.1 Page 70 — Intake Form

| Property | Value |
|---|---|
| Page Title | New KYC Request |
| Authorization | IS_REQUESTOR (or NOT_ADMIN for broader access) |
| Page Mode | Normal |
| Template | Minimal (no left nav) |

**Page Items:**

| Item Name | Type | Source | Validation |
|---|---|---|---|
| P70_REQUESTOR_NAME | Display Only | `SELECT full_name FROM QD_KYC_USERS WHERE user_id = :APP_USER_ID` | — |
| P70_DEPARTMENT | Display Only | From APP_DEPT_ID | — |
| P70_ENTITY_NAME | Text Field | User entry | NOT NULL |
| P70_ENTITY_TYPE | Select List | Static: NATURAL_PERSON / LEGAL_ENTITY | NOT NULL |
| P70_ENTITY_COUNTRY | Select List | `SELECT country_name FROM QD_KYC_REF_COUNTRY ORDER BY country_name` | NOT NULL |
| P70_OWNERSHIP_CAT | Select List | Static: 6 ownership categories | NOT NULL |
| P70_RELATIONSHIP_TYPE | Select List | `SELECT rel_name, rel_type_id FROM QD_KYC_REF_RELATIONSHIP WHERE is_active='Y'` | NOT NULL |
| P70_FINANCIAL_FLAG | Radio Group | Static: CURRENT / PROPOSED / NONE | NOT NULL |
| P70_RELATED_PARTY | Radio Group | Static: Y / N | NOT NULL |
| P70_RELATED_DETAILS | Textarea | User entry | Conditional: required if P70_RELATED_PARTY = Y |
| P70_KYC_RESULT | Display Only | Computed by Ajax callback | — |
| P70_FILES | File Upload | Multiple files | NOT NULL |

**Dynamic Action: Real-time KYC necessity check**
- Event: Change on P70_OWNERSHIP_CAT, P70_RELATIONSHIP_TYPE, P70_FINANCIAL_FLAG, P70_RELATED_PARTY
- Action: Execute Server-side Code (Ajax)
- PL/SQL: `RETURN QD_KYC_RULES.IS_KYC_REQUIRED(:P70_OWNERSHIP_CAT, :P70_RELATIONSHIP_TYPE, :P70_FINANCIAL_FLAG, :P70_RELATED_PARTY);`
- Set P70_KYC_RESULT — apply CSS class based on Y/N result

**Page Process: Submit**
```sql
DECLARE
  v_intake_id  NUMBER;
  v_kyc_req    CHAR(1);
BEGIN
  v_kyc_req := QD_KYC_RULES.IS_KYC_REQUIRED(
    :P70_OWNERSHIP_CAT, :P70_RELATIONSHIP_TYPE,
    :P70_FINANCIAL_FLAG, :P70_RELATED_PARTY);

  INSERT INTO QD_KYC_INTAKE (
    requestor_user_id, department_id, entity_name, entity_type,
    entity_country, ownership_category, relationship_type_id,
    financial_involvement, related_party_flag, related_party_details,
    kyc_required, status, submission_date
  ) VALUES (
    :APP_USER_ID, :APP_DEPT_ID, :P70_ENTITY_NAME, :P70_ENTITY_TYPE,
    :P70_ENTITY_COUNTRY, :P70_OWNERSHIP_CAT, :P70_RELATIONSHIP_TYPE,
    :P70_FINANCIAL_FLAG, :P70_RELATED_PARTY, :P70_RELATED_DETAILS,
    v_kyc_req, 'SUBMITTED', SYSTIMESTAMP
  ) RETURNING intake_id INTO v_intake_id;

  -- Process uploaded files
  QD_KYC_DOCS.SAVE_APEX_FILES(
    p_intake_id  => v_intake_id,
    p_file_names => :P70_FILES
  );

  -- Launch workflow if KYC required
  IF v_kyc_req = 'Y' THEN
    QD_KYC_WORKFLOW.LAUNCH(p_intake_id => v_intake_id);
  END IF;

  -- Send confirmation
  QD_KYC_NOTIFICATIONS.SEND('INTAKE_RECEIVED', :APP_USER_ID, NULL, v_intake_id);

  :P70_INTAKE_ID := v_intake_id;
END;
```

---

### 5.2 Page 11 — KYC Report Wizard

| Property | Value |
|---|---|
| Page Title | New KYC Report |
| Authorization | IS_CONTRIBUTOR |
| Template | Wizard |
| Wizard Type | 4 Steps |

**Step 1: Entity Selection**
- Search bar: calls `QD_KYC_UTILS.CHECK_DUPLICATE_ENTITY` via Ajax
- Results: Interactive Report from function call (inline)
- Select Entity: sets P11_ENTITY_ID session state; proceeds to Step 2
- Or: opens entity creation modal (Page 21)

**Step 2: Classification**
Key Dynamic Actions:
```javascript
// Force ENHANCED when risk is HIGH
if ($v('P11_RISK_LEVEL') === 'HIGH') {
  apex.item('P11_KYC_TYPE').setValue('ENHANCED');
  apex.item('P11_KYC_TYPE').disable();
  // Cannot select SIMPLIFIED when HIGH risk
  $('#P11_KYC_TYPE option[value="SIMPLIFIED"]').prop('disabled', true);
}
```

**Step 3: Conclusion Template**
```sql
-- LOV for conclusion templates (filtered by risk level)
SELECT template_name d, template_id r
FROM   QD_KYC_REF_CONCLUSION_TPL
WHERE  is_active = 'Y'
AND   (risk_level = :P11_RISK_LEVEL OR risk_level IS NULL)
ORDER BY display_order;

-- Dynamic Action: Apply Template button
-- Calls Ajax → returns template_body for selected template_id
-- Sets P11_FINAL_CONCLUSION value
```

**SLA Indicator computation:**
```sql
SELECT CASE
  WHEN SYSDATE - TO_DATE(:P11_DOCS_COMPLETE_DATE,'DD-MON-YYYY HH24:MI:SS')
       <= CASE :P11_KYC_TYPE WHEN 'SIMPLIFIED' THEN 5
                              WHEN 'ENHANCED' THEN 20 ELSE 10 END
  THEN 'u-color-6'   -- green
  WHEN SYSDATE - TO_DATE(:P11_DOCS_COMPLETE_DATE,'DD-MON-YYYY HH24:MI:SS')
       <= CASE :P11_KYC_TYPE WHEN 'SIMPLIFIED' THEN 7
                              WHEN 'ENHANCED' THEN 25 ELSE 13 END
  THEN 'u-color-2'   -- amber
  ELSE 'u-color-1'   -- red
END AS sla_class
FROM DUAL;
```

---

### 5.3 Page 13 — L1 Approval Queue

| Property | Value |
|---|---|
| Page Title | KYC Approval Queue — Level 1 |
| Authorization | IS_APPROVER_L1 |
| Source | `QD_KYC_V_APPROVAL_QUEUE_L1` (view joining report + user + intake) |

**View definition:**
```sql
CREATE OR REPLACE VIEW QD_KYC_V_APPROVAL_QUEUE_L1 AS
SELECT
  r.report_id, r.report_ref, r.kyc_type, r.risk_level,
  r.report_status, r.submitted_date,
  ROUND(SYSDATE - r.submitted_date) AS days_pending,
  u.full_name AS contributor_name,
  e.entity_name,
  CASE r.kyc_type
    WHEN 'SIMPLIFIED' THEN 5 WHEN 'ENHANCED' THEN 20 ELSE 10
  END AS sla_days,
  CASE
    WHEN ROUND(SYSDATE - r.submitted_date) > CASE r.kyc_type
      WHEN 'SIMPLIFIED' THEN 5 WHEN 'ENHANCED' THEN 20 ELSE 10 END
    THEN 'OVERDUE' ELSE 'ON_TRACK'
  END AS sla_status
FROM QD_KYC_REPORT r
JOIN QD_KYC_USERS  u ON u.user_id = r.contributor_user_id
JOIN QD_KYC_ENTITY e ON e.entity_id = r.entity_id
WHERE r.report_status IN ('SUBMITTED','RFI_L1')
AND   r.wf_level = 1;
```

**Row Highlight Rules (Interactive Report → Highlight):**
- Name: Overdue | Condition: `SLA_STATUS = 'OVERDUE'` | CSS: `u-hot`
- Name: Near SLA | Condition: `DAYS_PENDING > SLA_DAYS - 2` | CSS: `u-warning`

**Approval Action Process:**
```sql
-- Called from modal dialog submit
DECLARE
  v_action VARCHAR2(20) := :P13_ACTION;  -- APPROVE / RFI / REJECT
BEGIN
  -- Write to process log (immutable)
  INSERT INTO QD_KYC_PROCESS_LOG (report_id, action_type, from_status, to_status, action_user_id, comments)
  VALUES (:P13_REPORT_ID, v_action,
          (SELECT report_status FROM QD_KYC_REPORT WHERE report_id = :P13_REPORT_ID),
          CASE v_action WHEN 'APPROVE' THEN 'APPROVED_L1'
                        WHEN 'RFI' THEN 'RFI_L1' ELSE 'REJECTED' END,
          :APP_USER_ID, :P13_COMMENT);

  -- Update report status
  UPDATE QD_KYC_REPORT SET
    report_status = CASE v_action WHEN 'APPROVE' THEN 'APPROVED_L1'
                                  WHEN 'RFI' THEN 'RFI_L1' ELSE 'REJECTED' END,
    l1_approval_date = CASE v_action WHEN 'APPROVE' THEN SYSTIMESTAMP END,
    wf_level = CASE v_action WHEN 'APPROVE' THEN 2 ELSE wf_level END
  WHERE report_id = :P13_REPORT_ID;

  -- Route by outcome
  CASE v_action
    WHEN 'APPROVE' THEN
      IF (SELECT risk_level FROM QD_KYC_REPORT WHERE report_id = :P13_REPORT_ID) = 'LOW' THEN
        QD_KYC_WORKFLOW.COMPLETE_FINAL(:P13_REPORT_ID);
      ELSE
        QD_KYC_NOTIFICATIONS.SEND_TO_ACTIVE_APPROVER('APPROVAL_REQUIRED_L2', :P13_REPORT_ID, 'APPROVER_L2');
      END IF;
    WHEN 'RFI' THEN
      INSERT INTO QD_KYC_WF_COMMENTS (report_id, comment_text, comment_type, posted_by_user_id, wf_status_at_time)
      VALUES (:P13_REPORT_ID, :P13_COMMENT, 'RFI_REQUEST', :APP_USER_ID, 'RFI_L1');
      QD_KYC_NOTIFICATIONS.SEND('RFI_ISSUED',
        (SELECT contributor_user_id FROM QD_KYC_REPORT WHERE report_id = :P13_REPORT_ID),
        :P13_REPORT_ID);
    WHEN 'REJECT' THEN
      QD_KYC_WORKFLOW.COMPLETE_REJECTED(:P13_REPORT_ID, :P13_COMMENT);
  END CASE;
END;
```

---

## 6. Key PL/SQL Packages

### 6.1 QD_KYC_WORKFLOW Package

```sql
-- Key procedures

PROCEDURE LAUNCH(p_intake_id IN NUMBER);
-- Creates APEX Workflow instance; assigns first activity

PROCEDURE COMPLETE_FINAL(p_report_id IN NUMBER);
-- Called after final approval:
-- 1. Sets report_status = 'APPROVED', final_approval_date = SYSTIMESTAMP
-- 2. Calls QD_KYC_REPORTS.GENERATE_PDF(p_report_id) → stores to QD_KYC_DOCUMENTS
-- 3. Sends 'KYC_COMPLETE' email with PDF to requestor + contributor
-- 4. Writes final ProcessLog entry
-- 5. Seals report (is_draft = 'N')

PROCEDURE COMPLETE_REJECTED(p_report_id IN NUMBER, p_reason IN VARCHAR2);
-- Sets status = REJECTED; notifies requestor + contributor; closes workflow

FUNCTION GET_ACTIVE_APPROVER(p_role IN VARCHAR2) RETURN NUMBER;
-- Returns user_id of active, non-on-leave approver of given role
-- Falls back to deputy if primary is on leave
-- Raises alert to admin if no approver found
```

### 6.2 QD_KYC_UTILS Package

```sql
FUNCTION CHECK_DUPLICATE_ENTITY(
  p_entity_name  IN VARCHAR2,
  p_legal_reg_no IN VARCHAR2 DEFAULT NULL,
  p_id_number    IN VARCHAR2 DEFAULT NULL
) RETURN SYS_REFCURSOR;
-- Uses UTL_MATCH.JARO_WINKLER_SIMILARITY for fuzzy matching
-- Returns: entity_id, entity_ref, entity_name, version_status, risk_level,
--          name_similarity (descending order)

FUNCTION SUBSTITUTE_TEMPLATE(
  p_template_body IN CLOB,
  p_report_id     IN NUMBER DEFAULT NULL,
  p_intake_id     IN NUMBER DEFAULT NULL
) RETURN CLOB;
-- Replaces: #REPORT_REF#, #ENTITY_NAME#, #CONTRIBUTOR_NAME#,
--           #RISK_LEVEL#, #APPROVAL_DATE#, #APP_URL#
```

### 6.3 QD_KYC_NOTIFICATIONS Package

```sql
PROCEDURE SEND(
  p_template_code IN VARCHAR2,
  p_to_user_id    IN NUMBER,
  p_report_id     IN NUMBER DEFAULT NULL,
  p_intake_id     IN NUMBER DEFAULT NULL
);
-- Loads email template, substitutes variables, calls APEX_MAIL.SEND + PUSH_QUEUE

PROCEDURE SEND_TO_ACTIVE_APPROVER(
  p_template_code IN VARCHAR2,
  p_report_id     IN NUMBER,
  p_role          IN VARCHAR2
);
-- Resolves active approver via GET_ACTIVE_APPROVER, then calls SEND

PROCEDURE SEND_ADMIN_ALERT(p_message IN VARCHAR2);
-- Sends to all users with kyc_role = 'ADMIN'
```

---

## 7. APEX Workflow Definition

### 7.1 Workflow Activities (APEX Workflow Builder)

```
Workflow Name: KYC_APPROVAL_WORKFLOW
Version: 1.0

Activities:
1. DOCS_VALIDATION
   Type: Human Task
   Potential Owner: ROLE:COMPLIANCE_TEAM
   Due Days: 2
   Outcomes: DOCS_COMPLETE | DOCS_INCOMPLETE

2. ASSIGNMENT
   Type: Script Task
   Script: QD_KYC_WORKFLOW.AUTO_ASSIGN(:INTAKE_ID)
   Outcomes: ASSIGNED

3. DUE_DILIGENCE
   Type: Human Task
   Potential Owner: ASSIGNED_USER (from workflow variable)
   Due Days: Computed from KYC type (5/10/20)
   Outcomes: SUBMITTED_FOR_APPROVAL | SAVE_DRAFT

4. RISK_GATEWAY
   Type: Exclusive Gateway
   Condition LOW:  risk_level = 'LOW'  → L1_APPROVAL
   Condition ELSE: risk_level != 'LOW' → L1_APPROVAL → L2_APPROVAL

5. L1_APPROVAL
   Type: Human Task
   Potential Owner: QD_KYC_WORKFLOW.GET_ACTIVE_APPROVER('APPROVER_L1')
   Due Days: 3
   Outcomes: APPROVED_L1 | RFI_L1 | REJECTED_L1
   On RFI: loop back to DUE_DILIGENCE

6. L2_APPROVAL
   Type: Human Task
   Potential Owner: QD_KYC_WORKFLOW.GET_ACTIVE_APPROVER('APPROVER_L2')
   Due Days: 3
   Outcomes: APPROVED_FINAL | RFI_L2 | REJECTED_L2 | SAR_FLAGGED

7. FINAL_COMPLETE
   Type: Script Task
   Script: QD_KYC_WORKFLOW.COMPLETE_FINAL(:REPORT_ID)

8. SAR_REVIEW (conditional branch)
   Type: Human Task — MLRO only
   Outcomes: SAR_FILED | SAR_DISMISSED
   On DISMISSED: return to L2_APPROVAL
```

---

## 8. Nightly Monitoring Job

```sql
-- Full nightly job covering monitoring, SLA alerts, and Fusion sync
BEGIN
  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'QD_KYC_NIGHTLY_JOB',
    job_type        => 'PLSQL_BLOCK',
    job_action      => Q'[
      DECLARE
        CURSOR c_review_due IS
          SELECT report_id, contributor_user_id
          FROM   QD_KYC_REPORT
          WHERE  next_review_date BETWEEN SYSDATE AND SYSDATE + 60
          AND    report_status = 'APPROVED';

        CURSOR c_overdue IS
          SELECT report_id, contributor_user_id
          FROM   QD_KYC_REPORT
          WHERE  next_review_date < SYSDATE
          AND    report_status = 'APPROVED';

        CURSOR c_sla_breach IS
          SELECT r.report_id
          FROM   QD_KYC_REPORT r
          WHERE  r.report_status NOT IN ('APPROVED','REJECTED','DRAFT')
          AND    r.submitted_date IS NOT NULL
          AND    SYSDATE - r.submitted_date >
                 CASE r.kyc_type WHEN 'SIMPLIFIED' THEN 5
                                 WHEN 'ENHANCED' THEN 20 ELSE 10 END;
      BEGIN
        FOR r IN c_review_due LOOP
          QD_KYC_NOTIFICATIONS.SEND('REVIEW_DUE_SOON', r.contributor_user_id, r.report_id);
        END LOOP;
        FOR r IN c_overdue LOOP
          QD_KYC_NOTIFICATIONS.SEND('REVIEW_OVERDUE', r.contributor_user_id, r.report_id);
        END LOOP;
        FOR r IN c_sla_breach LOOP
          QD_KYC_NOTIFICATIONS.SEND_ADMIN_ALERT('SLA breach on report_id=' || r.report_id);
        END LOOP;
        QD_KYC_FUSION_SYNC.SYNC_ALL_EMPLOYEES;
        APEX_MAIL.PUSH_QUEUE;
      END;]',
    start_date      => TRUNC(SYSDATE+1) + 6/24,
    repeat_interval => 'FREQ=DAILY;BYHOUR=6;BYMINUTE=0',
    enabled         => TRUE
  );
END;
```

---

## 9. Performance Indexes

```sql
-- All foreign keys and common query columns must be indexed

CREATE INDEX QD_KYC_RPT_CONTRIB_IDX ON QD_KYC_REPORT(contributor_user_id);
CREATE INDEX QD_KYC_RPT_ENTITY_IDX  ON QD_KYC_REPORT(entity_id);
CREATE INDEX QD_KYC_RPT_STATUS_IDX  ON QD_KYC_REPORT(report_status, wf_level);
CREATE INDEX QD_KYC_RPT_RISK_IDX    ON QD_KYC_REPORT(risk_level);
CREATE INDEX QD_KYC_RPT_DATE_IDX    ON QD_KYC_REPORT(submitted_date, final_approval_date);
CREATE INDEX QD_KYC_RPT_REVIEW_IDX  ON QD_KYC_REPORT(next_review_date, report_status);
CREATE INDEX QD_KYC_ENT_NAME_IDX    ON QD_KYC_ENTITY(UPPER(entity_name));
CREATE INDEX QD_KYC_ENT_REGNO_IDX   ON QD_KYC_ENTITY(legal_reg_number);
CREATE INDEX QD_KYC_ENT_IDNO_IDX    ON QD_KYC_ENTITY(id_number);
CREATE INDEX QD_KYC_ENT_STATUS_IDX  ON QD_KYC_ENTITY(version_status);
CREATE INDEX QD_KYC_LOG_RPT_IDX     ON QD_KYC_PROCESS_LOG(report_id, action_date);
CREATE INDEX QD_KYC_UBO_ENT_IDX     ON QD_KYC_UBO(entity_id);
CREATE INDEX QD_KYC_DOC_RPT_IDX     ON QD_KYC_DOCUMENTS(report_id);
CREATE INDEX QD_KYC_DOC_INTAKE_IDX  ON QD_KYC_DOCUMENTS(intake_id);
CREATE INDEX QD_KYC_USERS_UNAME_IDX ON QD_KYC_USERS(UPPER(username));

-- Materialised view for KPI dashboard (refresh nightly)
CREATE MATERIALIZED VIEW QD_KYC_MV_KPI
  BUILD IMMEDIATE REFRESH COMPLETE ON DEMAND
AS SELECT /* KPI view query from KYC_APEX_DESIGN.md Section 10.1 */;
```

---

## 10. Acceptance Test Checklist (Developer Sign-Off)

```
□ APEX authentication redirects to IDCS login page
□ Successful IDCS login sets APP_KYC_ROLE correctly for each role type
□ First-time Fusion employee login triggers auto-provisioning
□ Nightly Fusion sync job executes without errors
□ Page 70 intake form: KYC necessity engine returns correct Y/N for all 6 ownership categories
□ Page 70: file upload saves to QD_KYC_DOCUMENTS with correct intake_id FK
□ Reference number triggers fire on INSERT for all three sequences
□ Duplicate detection returns results when Jaro-Winkler similarity > 85%
□ Duplicate detection fires mandatory warning on exact registration number match
□ Entity form: natural person fields hidden when entity_nature = LEGAL_ENTITY
□ Report wizard Step 2: SIMPLIFIED disabled when risk_level = HIGH
□ Report wizard Step 3: source_of_funds mandatory when kyc_type = ENHANCED
□ Date validation: future date rejected on all date fields
□ Date validation: invalid date (Feb 31) rejected
□ Submit action: submitted_date stamped; workflow task created for active L1 approver
□ L1 approval queue: only shows reports with wf_level = 1 AND status = SUBMITTED
□ Approve action: LOW risk → FINAL_APPROVED; MEDIUM/HIGH → APPROVED_L1 + L2 task
□ RFI action: comment saved; report status = RFI_L1; contributor email sent
□ Delegation: when approver marked on-leave, new submission routes to deputy
□ SAR gate: L2 approval process blocked if SAR question not answered
□ Final approval: PDF generated; email sent with attachment; record sealed (read-only)
□ Process log: UPDATE trigger raises ORA-20001 error
□ VPD: contributor cannot see another contributor's reports via direct SQL or APEX
□ KPI dashboard values match direct COUNT(*) queries on base tables
□ Nightly monitoring job runs without error; review-due emails sent correctly
```
