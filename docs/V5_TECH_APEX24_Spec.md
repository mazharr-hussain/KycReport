# Version 5 — Technical Specification
# Oracle APEX 24 Developer Guide

**Document Type:** Technical Specification — Developer Reference
**Audience:** Oracle APEX Developers, DBAs, Integration Architects
**Platform:** Oracle APEX 24.2 | Oracle Autonomous Transaction Processing (ATP) — Database 23ai | Oracle Fusion HCM Cloud
**Schema:** QD_KYC
**Authentication:** OCI IAM SSO (Fusion credentials)

---

## 1. Document Header

| Attribute | V4 (Previous) | V5 (This Document) |
|---|---|---|
| APEX Version | 23.2 | 24.2 (latest stable) |
| Oracle Database | 19c / 21c on-premises | 23ai — Autonomous Transaction Processing (ATP) |
| Identity Provider | Oracle IDCS | OCI IAM Domain |
| Workflow Engine | Custom PL/SQL (`QD_KYC_WORKFLOW`) | Native APEX Workflow Builder |
| Document Storage | BLOB columns / QDocs hybrid | OCI Object Storage via `DBMS_CLOUD` |
| Secret Storage | APEX Web Credentials (plain store) | OCI Vault (secret versioning, rotation) |
| ORDS | Separately installed and configured | Pre-installed on ATP — no setup required |
| Data Guard / HA | Manual RAC / Data Guard configuration | Autonomous Data Guard — included, zero config |

---

## 2. Development Environment Setup

### 2.1 Prerequisites

| Component | Version | Notes |
|---|---|---|
| Oracle APEX | 24.2 minimum | Universal Theme required; pre-installed on ATP |
| Oracle Autonomous Transaction Processing | 23ai | Serverless or dedicated — either supported |
| Oracle REST Data Services (ORDS) | Pre-installed on ATP | No manual installation; exposed via ATP HTTPS endpoint |
| OCI IAM Domain | Current | Replaces IDCS; tenant-level identity domain |
| OCI Object Storage | — | Bucket per environment (dev / uat / prod) |
| OCI Vault | — | Stores Fusion HCM API credentials as secrets |
| Oracle Fusion HCM | Cloud (any current release) | REST APIs must be reachable from ATP egress |
| SQL Developer Web | Included with ATP | Accessible from OCI Console — no client install required |

### 2.2 ATP Provisioning Steps

1. In OCI Console navigate to **Oracle Database → Autonomous Transaction Processing → Create Autonomous Database**.
2. Choose **Transaction Processing** workload type.
3. Set **Database name** to `QDKYCATP` and **Display name** to `QD KYC ATP`.
4. Select **Serverless** (recommended) or Dedicated infrastructure.
5. Set ADMIN password following OCI complexity rules (min 12 chars, upper/lower/digit/special).
6. Enable **Autonomous Data Guard** (standby in same or remote region).
7. Download the **Instance Wallet** (mTLS): OCI Console → Database Connection → Download Wallet. Store securely; required for all JDBC/SQL*Net client connections.
8. Note the **ATP HTTPS endpoint** for ORDS/APEX access: `https://<atp-hostname>/ords/`.

> **ATP storage note:** There are no tablespaces to create or manage. ATP provisions storage automatically and expands on demand. Do not specify `DEFAULT TABLESPACE` or `QUOTA` in DDL — ATP ignores tablespace clauses and manages all allocation internally.

### 2.3 APEX Workspace Setup on ATP

APEX 24.2 is pre-installed on ATP. No separate APEX installation step is required.

1. Access APEX Administration: `https://<atp-hostname>/ords/apex` → Internal workspace → admin user (ADMIN password set during ATP provisioning).
2. Create workspace **QD_KYC** mapped to schema **QD_KYC**.
3. Upload the APEX application export file or develop directly from the workspace.

---

## 3. Database Objects

### 3.1 Schema Creation on ATP

On ATP, schema creation is simplified. No tablespace specification, no quota setting.

```sql
-- Connect as ADMIN user (ATP)
CREATE USER qd_kyc IDENTIFIED BY "<strong-password>";

GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE,
      CREATE TRIGGER, CREATE PROCEDURE, CREATE TYPE,
      CREATE SYNONYM TO qd_kyc;

-- Required for DBMS_CLOUD (OCI Object Storage integration)
EXEC DBMS_CLOUD_ADMIN.ENABLE_PRINCIPAL_PROPAGATION(schema_name => 'QD_KYC');

-- Grant DBMS_CLOUD execution privilege
GRANT EXECUTE ON DBMS_CLOUD TO qd_kyc;

-- Grant APEX workspace access
BEGIN
  APEX_INSTANCE_ADMIN.ADD_WORKSPACE(
    p_workspace_id   => NULL,
    p_workspace      => 'QD_KYC',
    p_primary_schema => 'QD_KYC'
  );
END;
/
```

### 3.2 Core Table Structure

ATP manages storage allocation automatically. All V4 table structures carry forward unchanged. Define tables without tablespace clauses; ATP auto-assigns storage and applies auto-indexing for frequently queried columns.

**All tables follow these standards (unchanged from V4):**

- Primary key: `NUMBER GENERATED ALWAYS AS IDENTITY`
- Audit columns on every table: `created_by`, `created_date`, `updated_by`, `updated_date`, `row_version`
- `created_by` defaults to `SYS_CONTEXT('APEX$SESSION','APP_USER')`
- `created_date` defaults to `SYSTIMESTAMP`
- Enum-style columns enforced via `CHECK` constraints

| Table | Purpose | Key FK Relationships |
|---|---|---|
| `QD_KYC_USERS` | Fusion employee cache + KYC roles | `deputy_user_id → QD_KYC_USERS` |
| `QD_KYC_DEPARTMENTS` | Fusion org cache | `manager_user_id → QD_KYC_USERS` |
| `QD_KYC_INTAKE` | Digital intake submissions | `requestor_user_id`, `department_id`, `assigned_user_id` |
| `QD_KYC_ENTITY` | Counterparty records with versioning | `superseded_by_id → QD_KYC_ENTITY` |
| `QD_KYC_UBO` | UBO/participant records | `entity_id → QD_KYC_ENTITY` |
| `QD_KYC_REPORT` | KYC reports | `intake_id`, `entity_id`, `contributor_user_id` |
| `QD_KYC_PROCESS_LOG` | Immutable compliance audit trail | `report_id`, `intake_id`, `action_user_id` |
| `QD_KYC_WF_COMMENTS` | Workflow comments/RFI thread | `report_id`, `intake_id`, `posted_by_user_id` |
| `QD_KYC_DOCUMENTS` | File metadata (OCI Object Storage) | `report_id`, `intake_id`, `entity_id` |
| `QD_KYC_REF_*` | Reference/lookup tables | None — standalone |

> **V5 change — QD_KYC_DOCUMENTS:** The `file_blob` column is removed. Documents are stored in OCI Object Storage. The table retains metadata columns: `object_storage_uri`, `bucket_name`, `object_name`, `mime_type`, `file_size_bytes`. The `DBMS_CLOUD` package handles upload and download.

### 3.3 Audit Trigger Template (unchanged from V4)

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
/
```

### 3.4 Immutable Process Log Protection (unchanged from V4)

```sql
-- CRITICAL: This trigger must never be removed or disabled
CREATE OR REPLACE TRIGGER QD_KYC_PROCESS_LOG_PROTECT
  BEFORE UPDATE OR DELETE ON QD_KYC_PROCESS_LOG
BEGIN
  RAISE_APPLICATION_ERROR(-20001,
    'QD_KYC_PROCESS_LOG is an immutable audit table. '
    || 'UPDATE and DELETE operations are not permitted.');
END;
/
```

### 3.5 Reference Number Triggers (unchanged from V4)

```sql
-- Intake reference: INTAKE-YYYY-000001
CREATE OR REPLACE TRIGGER QD_KYC_INTAKE_BIR
  BEFORE INSERT ON QD_KYC_INTAKE FOR EACH ROW
BEGIN
  :NEW.intake_ref := 'INTAKE-' || TO_CHAR(SYSDATE,'YYYY')
                     || '-' || LPAD(QD_KYC_INTAKE_SEQ.NEXTVAL,6,'0');
END;
/

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
/

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
/
```

### 3.6 ATP Auto-Management Notes

- **Auto-indexing:** ATP monitors query workloads and creates additional indexes automatically. The performance indexes defined in Section 10 are still required as the baseline; ATP may supplement them. Do not drop ATP-created auto-indexes.
- **Auto-statistics:** `DBMS_STATS` jobs run automatically. Manual statistics gathering is not required in normal operation.
- **Connection from PL/SQL to OCI services:** Uses `DBMS_CLOUD` package which is pre-installed on ATP. No UTL_HTTP ACL configuration is needed for OCI Object Storage or OCI Vault REST endpoints accessed via `DBMS_CLOUD`.

---

## 4. OCI Services Setup

### 4.1 ATP Wallet (mTLS Connection)

All external clients (SQL Developer, CI/CD pipelines, JDBC datasources) connect to ATP using the mTLS wallet downloaded in Section 2.2. Configure `sqlnet.ora` and `tnsnames.ora` from the wallet contents. APEX and ORDS running on the same ATP instance connect internally and do not require the wallet.

### 4.2 OCI Vault — Fusion HCM API Credentials

OCI Vault replaces APEX Web Credentials as the storage mechanism for the Fusion HCM integration user credentials. This provides versioned secrets with audit logging and IAM-controlled access.

**Vault and secret setup (OCI Console):**

1. Create a Vault in the target compartment: **Security → Vault → Create Vault** (type: Default).
2. Create a Master Encryption Key (AES-256).
3. Create two secrets:

| Secret Name | Contents |
|---|---|
| `QD-KYC-FUSION-USERNAME` | Fusion integration service account username |
| `QD-KYC-FUSION-PASSWORD` | Fusion integration service account password |

4. Grant the ATP instance dynamic group read access to these secrets via IAM policy:

```
Allow dynamic-group <atp-dynamic-group> to read secret-bundles
  in compartment <compartment-name>
  where target.vault.id = '<vault-ocid>'
```

**PL/SQL retrieval of secrets at runtime:**

```sql
CREATE OR REPLACE FUNCTION QD_KYC_VAULT.GET_SECRET(
  p_secret_ocid IN VARCHAR2
) RETURN VARCHAR2 AS
  v_response  CLOB;
  v_secret    VARCHAR2(4000);
BEGIN
  -- DBMS_CLOUD.GET_OBJECT retrieves the secret bundle via OCI Vault REST API
  v_response := DBMS_CLOUD.GET_OBJECT(
    credential_name => 'OCI$RESOURCE_PRINCIPAL',
    object_uri      => 'https://secrets.vaults.<region>.oci.oraclecloud.com/20190301/secretbundles/'
                       || p_secret_ocid || '?stage=CURRENT'
  );
  -- Extract secretBundleContent.content (base64 encoded)
  v_secret := UTL_RAW.CAST_TO_VARCHAR2(
    UTL_ENCODE.BASE64_DECODE(
      UTL_RAW.CAST_TO_RAW(
        JSON_VALUE(v_response, '$.secretBundleContent.content')
      )
    )
  );
  RETURN v_secret;
END;
/
```

> Secrets are fetched at call time and never cached in session state or logged. Rotate secrets in OCI Vault without any application code change.

### 4.3 OCI Object Storage — Document Bucket Configuration

1. In OCI Console: **Storage → Object Storage → Create Bucket**.
2. Create one bucket per environment:

| Environment | Bucket Name | Visibility |
|---|---|---|
| Development | `qd-kyc-docs-dev` | Private |
| UAT | `qd-kyc-docs-uat` | Private |
| Production | `qd-kyc-docs-prod` | Private |

3. Enable **Object Versioning** on production bucket.
4. Apply **Lifecycle Policy**: move objects to Infrequent Access storage after 90 days.
5. Grant the ATP instance dynamic group access:

```
Allow dynamic-group <atp-dynamic-group> to manage objects
  in compartment <compartment-name>
  where target.bucket.name = 'qd-kyc-docs-prod'
```

6. In ATP, create a credential referencing the Resource Principal (no API key required when ATP has dynamic group membership):

```sql
-- On ATP: Resource Principal credential is pre-created as OCI$RESOURCE_PRINCIPAL
-- Verify it exists:
SELECT credential_name, enabled
FROM   all_credentials
WHERE  credential_name = 'OCI$RESOURCE_PRINCIPAL';
```

### 4.4 OCI IAM Domain Configuration

OCI IAM replaces Oracle IDCS. The configuration is performed in the OCI IAM Domain console, not the legacy IDCS console.

**Steps:**

1. In OCI Console: **Identity & Security → Domains → [your domain]**.
2. Navigate to **Applications → Add Application → Confidential Application**.
3. Set **Name** to `QD-KYC-APEX`.
4. Under **OAuth Configuration**:
   - Grant types: `Authorization Code`, `Client Credentials`
   - Redirect URL: `https://<atp-hostname>/ords/apex_authentication.callback`
   - Post-logout redirect: `https://<atp-hostname>/ords/f?p=100`
   - Scopes: `openid profile email`
5. Note the **Client ID** and generate a **Client Secret** (store in OCI Vault as `QD-KYC-IAM-CLIENT-SECRET`).
6. Token endpoint (V5 format):
   ```
   https://<domain-prefix>.identity.oraclecloud.com/oauth2/v1/token
   ```
   This replaces the V4 endpoint format `https://idcs-<tenancy>.identity.oraclecloud.com/oauth2/v1/token`.

---

## 5. Oracle Fusion HCM Integration

### 5.1 REST API Connectivity — OCI Vault Credential Retrieval

In V5, credentials are fetched from OCI Vault at runtime rather than read from the APEX Web Credential store.

```sql
-- Package specification: QD_KYC_FUSION_SYNC (updated for V5)
CREATE OR REPLACE PACKAGE QD_KYC_FUSION_SYNC AS
  c_fusion_base_url       CONSTANT VARCHAR2(200) := 'https://<fusion-host>';
  c_fusion_user_secret    CONSTANT VARCHAR2(200) := '<ocid1.vaultsecret...username>';
  c_fusion_pwd_secret     CONSTANT VARCHAR2(200) := '<ocid1.vaultsecret...password>';

  PROCEDURE sync_all_employees;
  PROCEDURE sync_employee(p_person_id IN VARCHAR2);
  PROCEDURE sync_org_structure;
  FUNCTION  get_kyc_role(p_job_code IN VARCHAR2, p_dept_id IN VARCHAR2) RETURN VARCHAR2;

PRIVATE:
  FUNCTION get_credential RETURN apex_t_varchar2;  -- returns (username, password)
END;
/
```

```sql
-- Credential retrieval and REST call
FUNCTION QD_KYC_FUSION_SYNC.CALL_FUSION_API(p_path IN VARCHAR2) RETURN CLOB AS
  v_user      VARCHAR2(200) := QD_KYC_VAULT.GET_SECRET(c_fusion_user_secret);
  v_pass      VARCHAR2(200) := QD_KYC_VAULT.GET_SECRET(c_fusion_pwd_secret);
  v_response  CLOB;
BEGIN
  -- Build Basic Auth header at runtime from Vault secrets
  v_response := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
    p_url         => c_fusion_base_url || p_path,
    p_http_method => 'GET',
    p_username    => v_user,
    p_password    => v_pass
  );
  RETURN v_response;
END;
```

### 5.2 REST Data Source in APEX Workspace

Define an APEX REST Data Source for Fusion HCM employees. In APEX Workspace Builder: **Shared Components → REST Data Sources → Create**.

| Property | Value |
|---|---|
| Name | `FUSION_HCM_EMPLOYEES` |
| URL | `https://<fusion-host>/hcmRestApi/resources/11.13.18.05/emps` |
| Authentication | HTTP Basic — credentials resolved from OCI Vault at runtime via plug-in |
| Pagination | REST Pagination — `offset` / `limit` style |
| Remote Server | Define once; reuse across data sources |

### 5.3 Role Mapping Logic (unchanged from V4)

```sql
FUNCTION get_kyc_role(p_job_code IN VARCHAR2, p_dept_id IN VARCHAR2) RETURN VARCHAR2 AS
BEGIN
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

### 5.4 Nightly Sync Job (unchanged — `DBMS_SCHEDULER` works identically on ATP)

```sql
BEGIN
  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'QD_KYC_FUSION_SYNC_JOB',
    job_type        => 'PLSQL_BLOCK',
    job_action      => 'BEGIN QD_KYC_FUSION_SYNC.SYNC_ALL_EMPLOYEES;
                              QD_KYC_FUSION_SYNC.SYNC_ORG_STRUCTURE; END;',
    start_date      => TRUNC(SYSDATE+1) + 2/24,
    repeat_interval => 'FREQ=DAILY;BYHOUR=2;BYMINUTE=0',
    enabled         => TRUE,
    comments        => 'Sync Fusion HCM employees and org structure to QD_KYC_USERS'
  );
END;
/
```

---

## 6. APEX Application Configuration

### 6.1 Application Settings

| Setting | Value |
|---|---|
| Application ID | 100 |
| Application Name | QD KYC Management |
| Authentication Scheme | OCI IAM SSO (see 6.2) |
| Authorization Scheme | Must Not Be Public User |
| Theme | Universal Theme (Theme 42) |
| Navigation Type | Navigation Menu |
| Logout URL | `/ords/apex_authentication.logout` |
| Session Timeout | 1800 seconds (30 min) |
| Maximum Session Idle | 900 seconds (15 min) |
| Error Handling Function | `qd_kyc_apex_error_handler` |

### 6.2 Authentication Scheme — OCI IAM

In V5, the authentication scheme type changes from "Oracle IDCS / Social Sign-In" to the native **OCI IAM** type available in APEX 24.2.

```
Type:         OCI Native Authentication (IAM)
Name:         OCI IAM SSO

Client ID:    <Client ID from OCI IAM Application — see Section 4.4>
Client Secret Credential:
              Type: OCI Native Authentication (IAM)
              -- Reference the Web Credential created below, which holds
              -- the Client Secret retrieved from OCI Vault

Token Endpoint:
  https://<domain-prefix>.identity.oraclecloud.com/oauth2/v1/token

Scope:        openid profile email

Post-Authentication Procedure: QD_KYC_AUTH.POST_LOGIN
  -- Unchanged logic from V4:
  --   1. Looks up user in QD_KYC_USERS by email from id_token claims
  --   2. If not found: calls QD_KYC_FUSION_SYNC.SYNC_EMPLOYEE to auto-provision
  --   3. Sets APP session state:
  --        APP_KYC_ROLE  := user's kyc_role
  --        APP_USER_ID   := user's user_id
  --        APP_DEPT_ID   := user's department_id
  --        APP_FULL_NAME := user's full_name
  --   4. Redirects to role-appropriate landing page
```

**APEX Web Credential for IAM Client Secret:**

```
Name:           OCI_IAM_CLIENT_CRED
Type:           OCI Native Authentication (IAM)
Client ID:      <same Client ID as above>
Client Secret:  <value fetched from OCI Vault secret QD-KYC-IAM-CLIENT-SECRET>
```

> Unlike V4 where the IDCS client secret was stored directly in the APEX credential store, in V5 the client secret value is sourced from OCI Vault and entered here. Rotation requires updating the Vault secret and re-entering the value in this credential — or automate via OCI Functions + APEX REST API.

### 6.3 Authorization Schemes (unchanged from V4)

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

### 6.4 Virtual Private Database — Row-Level Security (unchanged from V4)

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
/

EXEC DBMS_RLS.ADD_POLICY('QD_KYC','QD_KYC_REPORT','KYC_REPORT_POLICY',
  'QD_KYC_SECURITY','REPORT_POLICY','SELECT,INSERT,UPDATE,DELETE');
```

---

## 7. APEX Workflow Configuration

### 7.1 Overview — Native APEX Workflow Engine

APEX 24.2 includes a fully native Workflow Engine. The V4 custom PL/SQL orchestration package (`QD_KYC_WORKFLOW.LAUNCH`, state machine logic) is replaced by a declarative workflow definition created in **APEX Workflow Builder** (App Builder → Shared Components → Workflows).

Key differences from V4:

| Aspect | V4 Custom PL/SQL | V5 APEX Workflow Builder |
|---|---|---|
| Workflow definition | PL/SQL procedures, status updates in `QD_KYC_REPORT` | Declarative activities configured in Workflow Builder UI |
| Starting a workflow | `QD_KYC_WORKFLOW.LAUNCH(p_intake_id)` | `APEX_WORKFLOW.START_WORKFLOW(...)` |
| Completing a task | Direct `UPDATE QD_KYC_REPORT` + manual routing | `APEX_WORKFLOW.COMPLETE_ACTIVITY(...)` |
| Workflow state | `report_status` column + `QD_KYC_PROCESS_LOG` | APEX internal workflow tables + `QD_KYC_PROCESS_LOG` (compliance copy) |
| Workflow history | Custom `QD_KYC_PROCESS_LOG` queries | Built-in APEX Workflow History view + `QD_KYC_PROCESS_LOG` |
| Human tasks | APEX Interactive Report page + manual status update | Native Human Task activity with APEX Task Manager integration |

`QD_KYC_PROCESS_LOG` is retained in V5 as the **compliance audit trail**. It is written to at each workflow transition by Script Tasks, independent of the APEX workflow state tables.

### 7.2 Workflow Definition — KYC_APPROVAL_WORKFLOW

Configure in Workflow Builder: **App Builder → Shared Components → Workflows → Create**.

```
Workflow Name:    KYC_APPROVAL_WORKFLOW
Static ID:        KYC_APPROVAL_WF
Version:          2.0 (V5)

Workflow Variables:
  INTAKE_ID        NUMBER
  REPORT_ID        NUMBER
  RISK_LEVEL       VARCHAR2(10)
  ASSIGNED_USER_ID NUMBER
  KYC_TYPE         VARCHAR2(20)
```

### 7.3 Workflow Activities

All eight activities are configured declaratively in Workflow Builder. Activity names and logical flow are unchanged from V4.

**Activity 1: DOCS_VALIDATION**

```
Type:             Human Task
Static ID:        DOCS_VALIDATION
Potential Owner:  ROLE:COMPLIANCE_TEAM
Due Days:         2
Task Subject:     'Document Validation required for Intake ' || :INTAKE_ID
Outcomes:         DOCS_COMPLETE | DOCS_INCOMPLETE
On Complete:      Script Task → write QD_KYC_PROCESS_LOG entry
```

**Activity 2: ASSIGNMENT**

```
Type:             Script Task
Static ID:        ASSIGNMENT
PL/SQL Block:
  BEGIN
    :ASSIGNED_USER_ID := QD_KYC_WORKFLOW_UTILS.AUTO_ASSIGN(:INTAKE_ID);
    UPDATE QD_KYC_INTAKE SET assigned_user_id = :ASSIGNED_USER_ID,
           status = 'ASSIGNED' WHERE intake_id = :INTAKE_ID;
    INSERT INTO QD_KYC_PROCESS_LOG (intake_id, action_type, to_status, action_user_id)
    VALUES (:INTAKE_ID, 'AUTO_ASSIGN', 'ASSIGNED', :ASSIGNED_USER_ID);
  END;
Outcome:          ASSIGNED
```

**Activity 3: DUE_DILIGENCE**

```
Type:             Human Task
Static ID:        DUE_DILIGENCE
Potential Owner:  Workflow Variable: ASSIGNED_USER_ID
Due Days:         Expression: CASE :KYC_TYPE WHEN 'SIMPLIFIED' THEN 5
                                             WHEN 'ENHANCED' THEN 20 ELSE 10 END
Task Subject:     'KYC Due Diligence — Report ' || :REPORT_ID
Outcomes:         SUBMITTED_FOR_APPROVAL | SAVE_DRAFT
```

**Activity 4: RISK_GATEWAY**

```
Type:             Exclusive Gateway
Static ID:        RISK_GATEWAY
Conditions:
  LOW:  Workflow Variable RISK_LEVEL = 'LOW'  → next: L1_APPROVAL
  ELSE: Workflow Variable RISK_LEVEL != 'LOW' → next: L1_APPROVAL
        (L1 routes onward to L2 on APPROVED_L1 outcome)
```

**Activity 5: L1_APPROVAL**

```
Type:             Human Task
Static ID:        L1_APPROVAL
Potential Owner:  Expression: QD_KYC_WORKFLOW_UTILS.GET_ACTIVE_APPROVER('APPROVER_L1')
Due Days:         3
Task Subject:     'L1 Approval required — KYC Report ' || :REPORT_ID
Outcomes:         APPROVED_L1 | RFI_L1 | REJECTED_L1
On RFI_L1:        Loop back to DUE_DILIGENCE activity
On APPROVED_L1:   Gateway check — if RISK_LEVEL = 'LOW' → FINAL_COMPLETE
                                  else → L2_APPROVAL
On Complete:      Script Task → INSERT INTO QD_KYC_PROCESS_LOG; UPDATE QD_KYC_REPORT
```

**Activity 6: L2_APPROVAL**

```
Type:             Human Task
Static ID:        L2_APPROVAL
Potential Owner:  Expression: QD_KYC_WORKFLOW_UTILS.GET_ACTIVE_APPROVER('APPROVER_L2')
Due Days:         3
Task Subject:     'L2 Approval required — KYC Report ' || :REPORT_ID
Outcomes:         APPROVED_FINAL | RFI_L2 | REJECTED_L2 | SAR_FLAGGED
On RFI_L2:        Loop back to DUE_DILIGENCE activity
On SAR_FLAGGED:   Route to SAR_REVIEW activity
On Complete:      Script Task → INSERT INTO QD_KYC_PROCESS_LOG; UPDATE QD_KYC_REPORT
```

**Activity 7: FINAL_COMPLETE**

```
Type:             Script Task
Static ID:        FINAL_COMPLETE
PL/SQL Block:
  BEGIN
    QD_KYC_WORKFLOW_UTILS.COMPLETE_FINAL(:REPORT_ID);
    -- COMPLETE_FINAL: sets report_status='APPROVED', stamps final_approval_date,
    -- generates PDF via APEX_EXEC, stores in OCI Object Storage,
    -- sends KYC_COMPLETE email with document link, seals report (is_draft='N'),
    -- writes final QD_KYC_PROCESS_LOG entry
  END;
```

**Activity 8: SAR_REVIEW** (conditional branch)

```
Type:             Human Task
Static ID:        SAR_REVIEW
Potential Owner:  ROLE:MLRO
Due Days:         5
Task Subject:     'SAR Review required — KYC Report ' || :REPORT_ID
Outcomes:         SAR_FILED | SAR_DISMISSED
On SAR_DISMISSED: Return to L2_APPROVAL
On SAR_FILED:     Script Task → record SAR outcome; close workflow as REJECTED
```

### 7.4 Starting a Workflow from Page Process

Replace the V4 call `QD_KYC_WORKFLOW.LAUNCH(p_intake_id => v_intake_id)` with:

```sql
DECLARE
  v_wf_instance_id  NUMBER;
BEGIN
  APEX_WORKFLOW.START_WORKFLOW(
    p_workflow_static_id   => 'KYC_APPROVAL_WF',
    p_initiator            => :APP_USER,
    p_detail_pk            => v_intake_id,
    p_variables            => apex_t_varchar2(
                                'INTAKE_ID=' || v_intake_id
                              )
  );
END;
```

---

## 8. Key PL/SQL Packages

### 8.1 QD_KYC_WORKFLOW_UTILS (replaces QD_KYC_WORKFLOW in V4)

In V5, the workflow orchestration logic moves to APEX Workflow Builder. The PL/SQL package retains utility functions called by Script Tasks and Human Task owner expressions.

```sql
CREATE OR REPLACE PACKAGE QD_KYC_WORKFLOW_UTILS AS
  -- Called by Activity 2 (ASSIGNMENT) Script Task
  FUNCTION AUTO_ASSIGN(p_intake_id IN NUMBER) RETURN NUMBER;

  -- Called by L1_APPROVAL and L2_APPROVAL owner expressions
  FUNCTION GET_ACTIVE_APPROVER(p_role IN VARCHAR2) RETURN NUMBER;
  -- Returns user_id of active, non-on-leave approver; falls back to deputy.
  -- Raises admin alert if no approver found.

  -- Called by Activity 7 (FINAL_COMPLETE) Script Task
  PROCEDURE COMPLETE_FINAL(p_report_id IN NUMBER);
  -- Sets report_status='APPROVED'; stamps final_approval_date;
  -- generates PDF; uploads to OCI Object Storage via QD_KYC_DOCS.UPLOAD_TO_OCI;
  -- sends KYC_COMPLETE notification; seals report; writes process log.

  -- Called by SAR_REVIEW Script Task on SAR_FILED outcome
  PROCEDURE COMPLETE_REJECTED(p_report_id IN NUMBER, p_reason IN VARCHAR2);
END;
/
```

> The following V4 procedures are no longer needed as standalone PL/SQL because APEX Workflow handles state transitions natively:
> `QD_KYC_WORKFLOW.LAUNCH` — replaced by `APEX_WORKFLOW.START_WORKFLOW`
> Workflow routing logic (L1→L2 escalation) — replaced by Workflow Builder gateway conditions
> Task creation and assignment — replaced by Human Task activity owner expressions

### 8.2 QD_KYC_UTILS (unchanged from V4)

```sql
CREATE OR REPLACE PACKAGE QD_KYC_UTILS AS
  FUNCTION CHECK_DUPLICATE_ENTITY(
    p_entity_name  IN VARCHAR2,
    p_legal_reg_no IN VARCHAR2 DEFAULT NULL,
    p_id_number    IN VARCHAR2 DEFAULT NULL
  ) RETURN SYS_REFCURSOR;
  -- Uses UTL_MATCH.JARO_WINKLER_SIMILARITY for fuzzy matching

  FUNCTION SUBSTITUTE_TEMPLATE(
    p_template_body IN CLOB,
    p_report_id     IN NUMBER DEFAULT NULL,
    p_intake_id     IN NUMBER DEFAULT NULL
  ) RETURN CLOB;
  -- Replaces: #REPORT_REF#, #ENTITY_NAME#, #CONTRIBUTOR_NAME#,
  --           #RISK_LEVEL#, #APPROVAL_DATE#, #APP_URL#
END;
/
```

### 8.3 QD_KYC_NOTIFICATIONS (unchanged from V4)

```sql
CREATE OR REPLACE PACKAGE QD_KYC_NOTIFICATIONS AS
  PROCEDURE SEND(
    p_template_code IN VARCHAR2,
    p_to_user_id    IN NUMBER,
    p_report_id     IN NUMBER DEFAULT NULL,
    p_intake_id     IN NUMBER DEFAULT NULL
  );

  PROCEDURE SEND_TO_ACTIVE_APPROVER(
    p_template_code IN VARCHAR2,
    p_report_id     IN NUMBER,
    p_role          IN VARCHAR2
  );

  PROCEDURE SEND_ADMIN_ALERT(p_message IN VARCHAR2);
END;
/
```

---

## 9. OCI Object Storage Integration

### 9.1 Upload Document (from APEX File Upload)

```sql
CREATE OR REPLACE PACKAGE QD_KYC_DOCS AS
  PROCEDURE UPLOAD_TO_OCI(
    p_intake_id   IN NUMBER DEFAULT NULL,
    p_report_id   IN NUMBER DEFAULT NULL,
    p_entity_id   IN NUMBER DEFAULT NULL,
    p_file_name   IN VARCHAR2,
    p_mime_type   IN VARCHAR2,
    p_file_blob   IN BLOB
  );

  PROCEDURE SAVE_APEX_FILES(
    p_intake_id   IN NUMBER,
    p_file_names  IN VARCHAR2  -- colon-separated list from APEX file upload item
  );

  FUNCTION GET_DOWNLOAD_URL(
    p_document_id IN NUMBER,
    p_expiry_mins IN NUMBER DEFAULT 60
  ) RETURN VARCHAR2;

  PROCEDURE DELETE_DOCUMENT(p_document_id IN NUMBER);
END;
/
```

```sql
CREATE OR REPLACE PACKAGE BODY QD_KYC_DOCS AS

  c_bucket_name  CONSTANT VARCHAR2(100) := 'qd-kyc-docs-prod';
  c_namespace    CONSTANT VARCHAR2(100) := '<oci-object-storage-namespace>';
  c_region       CONSTANT VARCHAR2(50)  := '<region>';  -- e.g. me-abudhabi-1

  PROCEDURE UPLOAD_TO_OCI(
    p_intake_id   IN NUMBER DEFAULT NULL,
    p_report_id   IN NUMBER DEFAULT NULL,
    p_entity_id   IN NUMBER DEFAULT NULL,
    p_file_name   IN VARCHAR2,
    p_mime_type   IN VARCHAR2,
    p_file_blob   IN BLOB
  ) AS
    v_object_name  VARCHAR2(500);
    v_object_uri   VARCHAR2(1000);
    v_doc_id       NUMBER;
  BEGIN
    -- Object path: <year>/<intake|report>/<id>/<filename>
    v_object_name := TO_CHAR(SYSDATE,'YYYY') || '/'
      || CASE WHEN p_intake_id  IS NOT NULL THEN 'intake/'  || p_intake_id
              WHEN p_report_id  IS NOT NULL THEN 'report/'  || p_report_id
              WHEN p_entity_id  IS NOT NULL THEN 'entity/'  || p_entity_id
         END || '/' || p_file_name;

    v_object_uri := 'https://objectstorage.' || c_region
      || '.oraclecloud.com/n/' || c_namespace
      || '/b/' || c_bucket_name || '/o/' || v_object_name;

    -- Upload via DBMS_CLOUD (pre-installed on ATP)
    DBMS_CLOUD.PUT_OBJECT(
      credential_name => 'OCI$RESOURCE_PRINCIPAL',
      object_uri      => v_object_uri,
      contents        => p_file_blob
    );

    -- Store metadata in QD_KYC_DOCUMENTS
    INSERT INTO QD_KYC_DOCUMENTS (
      intake_id, report_id, entity_id,
      file_name, mime_type,
      file_size_bytes, object_name, bucket_name, object_storage_uri
    ) VALUES (
      p_intake_id, p_report_id, p_entity_id,
      p_file_name, p_mime_type,
      DBMS_LOB.GETLENGTH(p_file_blob), v_object_name, c_bucket_name, v_object_uri
    ) RETURNING document_id INTO v_doc_id;
  END UPLOAD_TO_OCI;

  PROCEDURE SAVE_APEX_FILES(
    p_intake_id   IN NUMBER,
    p_file_names  IN VARCHAR2
  ) AS
    v_blob      BLOB;
    v_mime      VARCHAR2(200);
    v_fname     VARCHAR2(500);
  BEGIN
    FOR r IN (
      SELECT filename, blob_content, mime_type
      FROM   apex_application_temp_files
      WHERE  name = p_file_names
    ) LOOP
      UPLOAD_TO_OCI(
        p_intake_id => p_intake_id,
        p_file_name => r.filename,
        p_mime_type => r.mime_type,
        p_file_blob => r.blob_content
      );
    END LOOP;
  END SAVE_APEX_FILES;

  FUNCTION GET_DOWNLOAD_URL(
    p_document_id IN NUMBER,
    p_expiry_mins IN NUMBER DEFAULT 60
  ) RETURN VARCHAR2 AS
    v_uri     VARCHAR2(1000);
    v_object  VARCHAR2(500);
    v_preauthenticated_url  VARCHAR2(2000);
  BEGIN
    SELECT object_storage_uri, object_name
    INTO   v_uri, v_object
    FROM   QD_KYC_DOCUMENTS
    WHERE  document_id = p_document_id;

    -- Generate a pre-authenticated request URL via OCI Object Storage API
    v_preauthenticated_url := DBMS_CLOUD.GET_OBJECT(
      credential_name => 'OCI$RESOURCE_PRINCIPAL',
      object_uri      => 'https://objectstorage.' || c_region
        || '.oraclecloud.com/n/' || c_namespace
        || '/b/' || c_bucket_name
        || '/p/?accessType=ObjectRead&name=' || UTL_URL.ESCAPE(v_object)
        || '&timeExpires=' || TO_CHAR(SYSTIMESTAMP + p_expiry_mins/1440,
                               'YYYY-MM-DD"T"HH24:MI:SS"Z"')
    );
    RETURN v_preauthenticated_url;
  END GET_DOWNLOAD_URL;

END QD_KYC_DOCS;
/
```

### 9.2 Performance Indexes (same as V4 — ATP supplements with auto-indexes)

```sql
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
```

---

## 10. Acceptance Test Checklist

### 10.1 ATP / OCI Infrastructure

```
□ ATP instance is accessible from OCI Console; APEX 24.2 pre-installed and confirmed
□ ATP wallet downloaded; SQL Developer connects successfully using wallet (mTLS)
□ QD_KYC schema created on ATP without tablespace/quota errors
□ DBMS_CLOUD pre-installation confirmed: SELECT object_name FROM all_objects
      WHERE object_name = 'DBMS_CLOUD' AND owner = 'SYS' returns a row
□ OCI$RESOURCE_PRINCIPAL credential present and enabled in all_credentials
□ DBMS_CLOUD.PUT_OBJECT to OCI Object Storage bucket succeeds from ATP SQL session
□ Vault secret retrieval: QD_KYC_VAULT.GET_SECRET(<username-secret-ocid>) returns
      correct Fusion username without error
□ Autonomous Data Guard standby confirmed active in OCI Console
```

### 10.2 OCI IAM Authentication

```
□ OCI IAM application registered with correct redirect URL and scopes
□ APEX authentication scheme type set to OCI Native Authentication (IAM)
□ Token endpoint uses new OCI IAM domain format (not legacy idcs- prefix)
□ Clicking Login redirects to OCI IAM domain login page (not IDCS)
□ Successful login with Fusion credentials returns id_token with email claim
□ POST_LOGIN procedure fires: APP_KYC_ROLE, APP_USER_ID, APP_DEPT_ID set in session
□ First-time login auto-provisions user from Fusion HCM via SYNC_EMPLOYEE
□ Logout clears APEX session and redirects to IAM logout endpoint
□ Session timeout after 30 minutes of inactivity redirects to login
```

### 10.3 APEX Native Workflow

```
□ Workflow KYC_APPROVAL_WF is active and version 2.0 in Shared Components
□ APEX_WORKFLOW.START_WORKFLOW called from Page 70 submit creates a workflow instance
□ APEX Task Manager shows DOCS_VALIDATION task assigned to COMPLIANCE_TEAM role
□ Completing DOCS_VALIDATION with DOCS_COMPLETE outcome advances to ASSIGNMENT activity
□ ASSIGNMENT Script Task sets ASSIGNED_USER_ID workflow variable correctly
□ DUE_DILIGENCE human task assigned to user from ASSIGNED_USER_ID variable
□ Risk Gateway routes LOW risk directly to FINAL_COMPLETE (skips L2)
□ Risk Gateway routes MEDIUM/HIGH through L1_APPROVAL then L2_APPROVAL
□ RFI_L1 outcome loops workflow back to DUE_DILIGENCE activity
□ L2 SAR_FLAGGED outcome routes to SAR_REVIEW task (MLRO role only)
□ FINAL_COMPLETE Script Task: report_status = 'APPROVED'; is_draft = 'N'
□ Workflow history visible in APEX built-in workflow history region
□ QD_KYC_PROCESS_LOG written at each transition (compliance audit trail intact)
□ Workflow instance terminates cleanly on FINAL_COMPLETE and COMPLETE_REJECTED
```

### 10.4 OCI Object Storage Documents

```
□ Page 70 file upload: SAVE_APEX_FILES uploads file to OCI bucket; object visible
      in OCI Console under correct year/intake/<id>/ path
□ QD_KYC_DOCUMENTS row created with object_storage_uri populated; file_blob column absent
□ GET_DOWNLOAD_URL returns a pre-authenticated URL valid for 60 minutes
□ Downloading the pre-authenticated URL retrieves the original file correctly
□ Documents report page shows file metadata (name, size, type) from QD_KYC_DOCUMENTS
□ FINAL_COMPLETE procedure uploads generated PDF to OCI; document_id returned
```

### 10.5 Core Application (unchanged from V4 — re-verify on new platform)

```
□ Page 70 intake form: KYC necessity engine returns correct Y/N for all 6 ownership categories
□ Reference number triggers fire on INSERT for all three sequences
□ Duplicate detection returns results when Jaro-Winkler similarity > 85%
□ Entity form: natural person fields hidden when entity_nature = LEGAL_ENTITY
□ Report wizard Step 2: SIMPLIFIED disabled when risk_level = HIGH
□ Date validation: future date rejected on all date fields
□ L1 approval queue: only shows reports with wf_level = 1 AND correct status
□ Delegation: when approver marked on-leave, new submission routes to deputy
□ VPD: contributor cannot see another contributor's reports via direct SQL or APEX
□ Process log: UPDATE trigger raises ORA-20001 (immutability intact)
□ KPI dashboard values match direct COUNT(*) queries on base tables
□ Nightly monitoring and Fusion sync jobs run without error on ATP scheduler
```
