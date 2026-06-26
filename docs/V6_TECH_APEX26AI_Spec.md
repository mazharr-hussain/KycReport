# Version 6 — Technical Specification
# Oracle APEX 26 AI — KYC Management System

**Document Type:** Technical Specification — Developer Reference
**Audience:** Oracle APEX Developers, DBAs, AI/ML Integration Architects
**Platform:** Oracle APEX 26 | Oracle Autonomous Transaction Processing (ATP) — Database 23ai | OCI Generative AI Service | OCI AI Document Understanding
**Schema:** QD_KYC
**Authentication:** OCI IAM SSO (Fusion credentials)

---

## 1. Document Header

| Component | V5 (APEX 24) | V6 (APEX 26 AI) |
|---|---|---|
| APEX Version | 24.2 | 26.x |
| Oracle Database | ATP 23ai | ATP 23ai (AI Vector Search enabled) |
| Identity Provider | OCI IAM Domain | OCI IAM Domain (unchanged) |
| Workflow Engine | Native APEX Workflow Builder | Native APEX Workflow Builder (unchanged) |
| Document Storage | OCI Object Storage via `DBMS_CLOUD` | OCI Object Storage + AI Document Understanding classification |
| Secret Storage | OCI Vault | OCI Vault (unchanged) |
| Duplicate Detection | Manual name search | AI Vector Search — `VECTOR_DISTANCE` cosine similarity |
| Document Classification | Manual officer selection | OCI AI Document Understanding — automated classification with confidence score |
| Risk Scoring | Officer manual entry | OCI Generative AI suggestion — officer accepts or overrides |
| Conclusion Authoring | Officer free-text | OCI Generative AI draft — officer edits and finalises |
| Natural Language Query | Not supported | Select AI — `SELECT AI NARRATE` on approved views |
| AI Assistant | Not supported | APEX AI Assistant (APEX 26 built-in) — reference data only |
| AI Audit | Not applicable | `QD_KYC_AI_AUDIT` — immutable record of every AI interaction |

All V5 components (APEX Workflow, OCI Object Storage, OCI IAM, APEX Web Credentials, Fusion HCM integration) carry forward unchanged. This document covers only the AI-specific additions.

---

## 2. Prerequisites and OCI AI Services Setup

### 2.1 All V5 Prerequisites

Refer to V5 specification section 2 for ATP provisioning, ORDS configuration, OCI IAM SSO setup, OCI Vault, and OCI Object Storage bucket configuration. These are unchanged in V6.

### 2.2 OCI Generative AI Service

1. In OCI Console navigate to **AI Services → Generative AI**.
2. Confirm the service is available in your tenancy region. As of the publication date, OCI Generative AI is available in `us-chicago-1`, `us-ashburn-1`, `eu-frankfurt-1`, and `ap-osaka-1`. If the KYC tenancy home region is not listed, enable a **remote region subscription** under OCI Console → Administration → Region Management.
3. No additional provisioning is required; the service is consumption-based.
4. Note the inference endpoint format — used in all PL/SQL REST calls:

```
https://inference.generativeai.{region}.oci.oraclecloud.com
```

Example for Chicago:

```
https://inference.generativeai.us-chicago-1.oci.oraclecloud.com
```

### 2.3 OCI AI Document Understanding

1. In OCI Console navigate to **AI Services → Document Understanding**.
2. Enable the service for the tenancy compartment.
3. Create a **Project**: AI Services → Document Understanding → Projects → Create Project. Name: `KYC_DOC_PROJECT`. Note the project OCID.
4. The service uses inline document submission (base64) — no Object Storage pre-staging required for classification calls.

### 2.4 IAM Policies

Add the following policies to the KYC dynamic group (`QD_KYC_ATP_DG`) that covers the ATP database instance:

```hcl
# Allow ATP to call OCI Generative AI
allow dynamic-group QD_KYC_ATP_DG to use generative-ai-family
  in compartment id <KYC_COMPARTMENT_OCID>

# Allow ATP to call OCI AI Document Understanding
allow dynamic-group QD_KYC_ATP_DG to use ai-document-family
  in compartment id <KYC_COMPARTMENT_OCID>
```

Verify the dynamic group rule matches the ATP OCID:

```hcl
matching_rule = "resource.id = '<ATP_OCID>'"
```

### 2.5 Database Credential for OCI Gen AI

Create an OCI Vault-backed credential in the ATP schema:

```sql
BEGIN
  DBMS_CLOUD.CREATE_CREDENTIAL(
    credential_name => 'OCI_GENAI_CRED',
    user_ocid       => '<USER_OR_INSTANCE_PRINCIPAL_OCID>',
    tenancy_ocid    => '<TENANCY_OCID>',
    private_key     => '<PEM_PRIVATE_KEY>',
    fingerprint     => '<API_KEY_FINGERPRINT>'
  );
END;
/
```

For production, prefer **Instance Principal** authentication via the ATP dynamic group — omit `user_ocid`, `private_key`, and `fingerprint`, and set `auth_type => 'instance_principal'` where supported by the APEX_WEB_SERVICE call.

---

## 3. Database Schema Changes

All V5 tables remain unchanged. The following DDL adds AI-specific columns and creates the new AI audit table.

### 3.1 QD_KYC_ENTITY — Vector Embedding Columns

```sql
ALTER TABLE QD_KYC_ENTITY ADD (
  name_embedding   VECTOR(1536, FLOAT32),
  embedding_date   DATE
);

COMMENT ON COLUMN QD_KYC_ENTITY.name_embedding  IS 'OCI Gen AI 1536-dim embedding of normalised entity name';
COMMENT ON COLUMN QD_KYC_ENTITY.embedding_date  IS 'Date embedding was last generated or refreshed';
```

### 3.2 QD_KYC_REPORT — AI Risk and Conclusion Columns

```sql
ALTER TABLE QD_KYC_REPORT ADD (
  ai_risk_suggestion      VARCHAR2(10),     -- LOW / MEDIUM / HIGH
  ai_risk_rationale       VARCHAR2(2000),
  ai_risk_accepted_flag   CHAR(1),          -- Y = accepted, N = overridden
  ai_risk_override_reason VARCHAR2(500),
  ai_conclusion_draft     CLOB,
  ai_conclusion_gen_date  DATE
);

COMMENT ON COLUMN QD_KYC_REPORT.ai_risk_suggestion      IS 'AI-suggested risk level prior to officer decision';
COMMENT ON COLUMN QD_KYC_REPORT.ai_risk_rationale       IS 'Plain-text rationale returned by AI model';
COMMENT ON COLUMN QD_KYC_REPORT.ai_risk_accepted_flag   IS 'Y if officer accepted suggestion; N if overridden';
COMMENT ON COLUMN QD_KYC_REPORT.ai_risk_override_reason IS 'Mandatory reason text when officer overrides AI suggestion';
COMMENT ON COLUMN QD_KYC_REPORT.ai_conclusion_draft     IS 'AI-generated conclusion draft — immutable after first save';
COMMENT ON COLUMN QD_KYC_REPORT.ai_conclusion_gen_date  IS 'Date draft was first generated';
```

### 3.3 QD_KYC_DOCUMENTS — Document AI Classification Columns

```sql
ALTER TABLE QD_KYC_DOCUMENTS ADD (
  ai_doc_type           VARCHAR2(100),
  ai_confidence_score   NUMBER(5,4),
  ai_doc_corrected_flag CHAR(1),        -- Y if officer corrected the AI classification
  ai_doc_corrected_type VARCHAR2(100)   -- Officer's corrected document type
);

COMMENT ON COLUMN QD_KYC_DOCUMENTS.ai_doc_type           IS 'Document type label returned by OCI AI Document Understanding';
COMMENT ON COLUMN QD_KYC_DOCUMENTS.ai_confidence_score   IS 'Confidence score 0.0000 to 1.0000';
COMMENT ON COLUMN QD_KYC_DOCUMENTS.ai_doc_corrected_flag IS 'Y if officer manually corrected AI classification';
COMMENT ON COLUMN QD_KYC_DOCUMENTS.ai_doc_corrected_type IS 'Officer-supplied document type when AI classification was incorrect';
```

### 3.4 QD_KYC_AI_AUDIT — New Immutable Audit Table

```sql
CREATE TABLE QD_KYC_AI_AUDIT (
  audit_id        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  report_id       NUMBER,
  document_id     NUMBER,
  entity_id       NUMBER,
  ai_feature      VARCHAR2(50),   -- RISK_SCORING / CONCLUSION_DRAFT / DOC_CLASSIFY / VECTOR_SEARCH / SELECT_AI
  model_id        VARCHAR2(200),
  prompt_hash     VARCHAR2(64),   -- SHA-256 hex of prompt sent to model
  ai_response     CLOB,
  accepted_flag   CHAR(1),        -- Y / N / NULL (not applicable for search features)
  override_reason VARCHAR2(500),
  action_user_id  NUMBER,
  action_date     TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT fk_ai_audit_report FOREIGN KEY (report_id)   REFERENCES QD_KYC_REPORT(report_id),
  CONSTRAINT fk_ai_audit_doc    FOREIGN KEY (document_id) REFERENCES QD_KYC_DOCUMENTS(document_id),
  CONSTRAINT fk_ai_audit_entity FOREIGN KEY (entity_id)   REFERENCES QD_KYC_ENTITY(entity_id),
  CONSTRAINT chk_ai_feature CHECK (ai_feature IN (
    'RISK_SCORING','CONCLUSION_DRAFT','DOC_CLASSIFY','VECTOR_SEARCH','SELECT_AI'
  ))
);

COMMENT ON TABLE  QD_KYC_AI_AUDIT IS 'Immutable audit log of all AI interactions. No UPDATE or DELETE permitted.';
```

Immutability trigger — same pattern as `QD_KYC_PROCESS_LOG`:

```sql
CREATE OR REPLACE TRIGGER trg_ai_audit_immutable
  BEFORE UPDATE OR DELETE ON QD_KYC_AI_AUDIT
  FOR EACH ROW
BEGIN
  RAISE_APPLICATION_ERROR(-20001,
    'QD_KYC_AI_AUDIT is immutable. UPDATE and DELETE are not permitted.');
END trg_ai_audit_immutable;
/
```

---

## 4. AI Vector Search for Duplicate Entity Detection

### 4.1 Package Specification

```sql
CREATE OR REPLACE PACKAGE QD_KYC_VECTOR_SEARCH AS

  -- Generate or refresh name embedding for a single entity
  PROCEDURE GENERATE_EMBEDDING (p_entity_id IN NUMBER);

  -- Return top-N most similar entities by cosine distance
  FUNCTION FIND_SIMILAR_ENTITIES (
    p_name  IN VARCHAR2,
    p_top_n IN NUMBER DEFAULT 10
  ) RETURN SYS_REFCURSOR;

END QD_KYC_VECTOR_SEARCH;
/
```

### 4.2 Package Body

```sql
CREATE OR REPLACE PACKAGE BODY QD_KYC_VECTOR_SEARCH AS

  C_EMBED_URL  CONSTANT VARCHAR2(500) :=
    'https://inference.generativeai.us-chicago-1.oci.oraclecloud.com'
    || '/20231130/actions/embedText';
  C_EMBED_MODEL CONSTANT VARCHAR2(200) := 'cohere.embed-multilingual-v3.0';

  ----------------------------------------------------------------------------
  PROCEDURE GENERATE_EMBEDDING (p_entity_id IN NUMBER) IS
    l_entity_name  QD_KYC_ENTITY.entity_name%TYPE;
    l_req_body     CLOB;
    l_response     CLOB;
    l_embedding    VECTOR(1536, FLOAT32);
  BEGIN
    SELECT UPPER(TRIM(entity_name))
    INTO   l_entity_name
    FROM   QD_KYC_ENTITY
    WHERE  entity_id = p_entity_id;

    -- Build OCI Gen AI embedText request body
    APEX_JSON.INITIALIZE_CLOB_OUTPUT;
    APEX_JSON.OPEN_OBJECT;
    APEX_JSON.WRITE('inputs',     APEX_JSON.EMPTY_ARRAY); -- overwritten below
    APEX_JSON.CLOSE_OBJECT;
    -- Build manually for array input
    l_req_body := '{"inputs":["' || REPLACE(l_entity_name, '"', '\"')
                  || '"],"model":"' || C_EMBED_MODEL || '","inputType":"SEARCH_DOCUMENT"}';

    l_response := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
      p_url         => C_EMBED_URL,
      p_http_method => 'POST',
      p_body        => l_req_body,
      p_credential_static_id => 'OCI_GENAI_CRED',
      p_http_headers => APEX_WEB_SERVICE.NEW_HEADERS(
        APEX_WEB_SERVICE.NEW_HEADER('Content-Type','application/json')
      )
    );

    -- Parse first embedding array from response: {"embeddings":[[0.1,0.2,...]]}
    APEX_JSON.PARSE(l_response);
    -- Convert JSON array to VECTOR — DB 23ai native function
    l_embedding := TO_VECTOR(
      APEX_JSON.GET_VARCHAR2(p_path => 'embeddings[1]'),
      1536, FLOAT32
    );

    UPDATE QD_KYC_ENTITY
    SET    name_embedding = l_embedding,
           embedding_date = SYSDATE
    WHERE  entity_id = p_entity_id;

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END GENERATE_EMBEDDING;

  ----------------------------------------------------------------------------
  FUNCTION FIND_SIMILAR_ENTITIES (
    p_name  IN VARCHAR2,
    p_top_n IN NUMBER DEFAULT 10
  ) RETURN SYS_REFCURSOR IS
    l_req_body      CLOB;
    l_response      CLOB;
    l_query_vector  VECTOR(1536, FLOAT32);
    l_cursor        SYS_REFCURSOR;
  BEGIN
    -- Generate embedding for the query name on the fly
    l_req_body := '{"inputs":["' || REPLACE(UPPER(TRIM(p_name)), '"', '\"')
                  || '"],"model":"' || C_EMBED_MODEL || '","inputType":"SEARCH_QUERY"}';

    l_response := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
      p_url         => C_EMBED_URL,
      p_http_method => 'POST',
      p_body        => l_req_body,
      p_credential_static_id => 'OCI_GENAI_CRED',
      p_http_headers => APEX_WEB_SERVICE.NEW_HEADERS(
        APEX_WEB_SERVICE.NEW_HEADER('Content-Type','application/json')
      )
    );

    APEX_JSON.PARSE(l_response);
    l_query_vector := TO_VECTOR(
      APEX_JSON.GET_VARCHAR2(p_path => 'embeddings[1]'),
      1536, FLOAT32
    );

    OPEN l_cursor FOR
      SELECT e.entity_id,
             e.entity_name,
             e.entity_ref,
             ROUND(VECTOR_DISTANCE(e.name_embedding, l_query_vector, COSINE), 6) AS distance
      FROM   QD_KYC_ENTITY e
      WHERE  e.name_embedding IS NOT NULL
      ORDER BY VECTOR_DISTANCE(e.name_embedding, l_query_vector, COSINE)
      FETCH FIRST p_top_n ROWS ONLY;

    RETURN l_cursor;
  END FIND_SIMILAR_ENTITIES;

END QD_KYC_VECTOR_SEARCH;
/
```

### 4.3 APEX Ajax Callback — Duplicate Check

Create an APEX Ajax Callback process named `VECTOR_SIMILAR_ENTITIES` on the entity edit page:

```sql
DECLARE
  l_cursor   SYS_REFCURSOR;
  l_id       NUMBER;
  l_name     VARCHAR2(500);
  l_ref      VARCHAR2(100);
  l_distance NUMBER;
BEGIN
  l_cursor := QD_KYC_VECTOR_SEARCH.FIND_SIMILAR_ENTITIES(
    p_name  => APEX_APPLICATION.G_X01,
    p_top_n => 10
  );

  APEX_JSON.OPEN_OBJECT;
  APEX_JSON.OPEN_ARRAY('results');
  LOOP
    FETCH l_cursor INTO l_id, l_name, l_ref, l_distance;
    EXIT WHEN l_cursor%NOTFOUND;
    APEX_JSON.OPEN_OBJECT;
    APEX_JSON.WRITE('entity_id', l_id);
    APEX_JSON.WRITE('entity_name', l_name);
    APEX_JSON.WRITE('entity_ref', l_ref);
    APEX_JSON.WRITE('distance', l_distance);
    APEX_JSON.CLOSE_OBJECT;
  END LOOP;
  CLOSE l_cursor;
  APEX_JSON.CLOSE_ARRAY;
  APEX_JSON.CLOSE_OBJECT;
END;
```

Wire a Dynamic Action on the entity name field (Event: Change, debounce 600 ms) to call this Ajax Callback and render results in a sub-region below the field. Similarity distance below `0.15` should be highlighted as a potential duplicate.

### 4.4 Nightly Embedding Refresh Job

```sql
BEGIN
  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'QD_KYC_REFRESH_EMBEDDINGS',
    job_type        => 'PLSQL_BLOCK',
    job_action      => q'[
      BEGIN
        FOR r IN (
          SELECT entity_id
          FROM   QD_KYC_ENTITY
          WHERE  (name_embedding IS NULL
                  OR embedding_date < SYSDATE - 1)
          AND    last_update_date >= SYSDATE - 1
        ) LOOP
          QD_KYC_VECTOR_SEARCH.GENERATE_EMBEDDING(r.entity_id);
        END LOOP;
      END;
    ]',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=DAILY;BYHOUR=2;BYMINUTE=0',
    enabled         => TRUE,
    comments        => 'Refresh name embeddings for entities modified in last 24 hours'
  );
END;
/
```

---

## 5. Select AI Configuration

### 5.1 Approved Views

Select AI is restricted to three read-only views that expose no sensitive PII columns directly:

```sql
-- Reports search view — no individual PII fields
CREATE OR REPLACE VIEW QD_KYC_V_REPORT_SEARCH AS
SELECT r.report_id,
       r.report_ref,
       r.report_status,
       r.risk_level,
       r.ai_risk_suggestion,
       r.created_date,
       r.submitted_date,
       r.assigned_officer_id,
       e.entity_ref,
       e.entity_type
FROM   QD_KYC_REPORT   r
JOIN   QD_KYC_ENTITY   e ON e.entity_id = r.entity_id;

-- Entity search view — name visible for search, no DOB / national ID
CREATE OR REPLACE VIEW QD_KYC_V_ENTITY_SEARCH AS
SELECT entity_id,
       entity_ref,
       entity_name,
       entity_type,
       country_of_incorporation,
       fatf_tier,
       pep_flag,
       screening_status,
       created_date
FROM   QD_KYC_ENTITY;

-- Intake search view
CREATE OR REPLACE VIEW QD_KYC_V_INTAKE_SEARCH AS
SELECT intake_id,
       intake_ref,
       intake_status,
       intake_date,
       entity_ref,
       assigned_officer_id
FROM   QD_KYC_INTAKE;
```

### 5.2 Create Select AI Profile

```sql
BEGIN
  DBMS_CLOUD_AI.CREATE_PROFILE(
    profile_name => 'KYC_SELECT_AI',
    attributes   => '{
      "provider": "oci",
      "credential_name": "OCI_GENAI_CRED",
      "object_list": [
        {"owner": "QD_KYC", "name": "QD_KYC_V_REPORT_SEARCH"},
        {"owner": "QD_KYC", "name": "QD_KYC_V_ENTITY_SEARCH"},
        {"owner": "QD_KYC", "name": "QD_KYC_V_INTAKE_SEARCH"}
      ]
    }'
  );
END;
/
```

Grant the Select AI profile role SELECT on approved views only:

```sql
CREATE ROLE QD_KYC_SELECT_AI_ROLE;
GRANT SELECT ON QD_KYC_V_REPORT_SEARCH  TO QD_KYC_SELECT_AI_ROLE;
GRANT SELECT ON QD_KYC_V_ENTITY_SEARCH  TO QD_KYC_SELECT_AI_ROLE;
GRANT SELECT ON QD_KYC_V_INTAKE_SEARCH  TO QD_KYC_SELECT_AI_ROLE;
```

Do not grant SELECT on any base table to this role. The profile user context operates with minimum privilege.

### 5.3 APEX Page Implementation

On the KYC Search page, add:

- **Text Field** P30_NL_QUERY — placeholder "Ask a question about KYC reports..."
- **Button** SEARCH_NL — label "Ask"
- **Static Content Region** to display the result

Ajax Callback process `SELECT_AI_QUERY`:

```sql
DECLARE
  l_sql    CLOB;
  l_result CLOB;
BEGIN
  -- Set Select AI profile for this session
  DBMS_CLOUD_AI.SET_PROFILE('KYC_SELECT_AI');

  -- Use NARRATE action to return a natural language answer
  EXECUTE IMMEDIATE
    'SELECT AI NARRATE ' || DBMS_ASSERT.NOOP(APEX_APPLICATION.G_X01)
  INTO l_result;

  -- Log to AI audit (query hash only — no data returned is stored)
  INSERT INTO QD_KYC_AI_AUDIT (
    ai_feature, model_id, prompt_hash, ai_response, action_user_id
  ) VALUES (
    'SELECT_AI',
    'KYC_SELECT_AI',
    LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(
      UTL_I18N.STRING_TO_RAW(APEX_APPLICATION.G_X01, 'AL32UTF8'),
      DBMS_CRYPTO.HASH_SH256
    ))),
    'NARRATE query executed — data not stored in audit',
    APEX_CUSTOM_AUTH.GET_USER_ID
  );
  COMMIT;

  APEX_JSON.OPEN_OBJECT;
  APEX_JSON.WRITE('result', l_result);
  APEX_JSON.CLOSE_OBJECT;
END;
```

Security note: validate `APEX_APPLICATION.G_X01` length (max 500 chars) and reject if it contains SQL injection patterns before passing to `SELECT AI NARRATE`.

---

## 6. OCI AI Document Understanding Integration

### 6.1 Document Type Mapping

| OCI Label | KYC Document Type |
|---|---|
| `BANK_STATEMENT` | Bank Statement |
| `PASSPORT` | Passport |
| `DRIVING_LICENSE` | Driving Licence |
| `CHEQUE` | Cheque |
| `INVOICE` | Invoice |
| `RECEIPT` | Receipt |
| `RESUME` | (flag as unexpected — no KYC match) |
| `TAX_FORM` | Tax Document |

KYC-specific labels not in the OCI taxonomy (e.g. Commercial Registration, Ownership Declaration) will return low confidence; the officer classification correction workflow handles these.

### 6.2 Package `QD_KYC_DOC_AI`

```sql
CREATE OR REPLACE PACKAGE QD_KYC_DOC_AI AS

  PROCEDURE CLASSIFY_DOCUMENT (p_document_id IN NUMBER);

END QD_KYC_DOC_AI;
/

CREATE OR REPLACE PACKAGE BODY QD_KYC_DOC_AI AS

  C_DOC_AI_URL CONSTANT VARCHAR2(500) :=
    'https://document.aiservice.us-chicago-1.oci.oraclecloud.com'
    || '/20221109/actions/analyzeDocument';

  PROCEDURE CLASSIFY_DOCUMENT (p_document_id IN NUMBER) IS
    l_doc_content   BLOB;
    l_doc_b64       CLOB;
    l_req_body      CLOB;
    l_response      CLOB;
    l_doc_type      VARCHAR2(100);
    l_confidence    NUMBER;
    l_kyc_doc_type  VARCHAR2(100);
  BEGIN
    -- Retrieve document BLOB from Object Storage pre-authenticated URL or inline
    SELECT doc_content
    INTO   l_doc_content
    FROM   QD_KYC_DOCUMENTS
    WHERE  document_id = p_document_id;

    -- Base64-encode for inline submission
    l_doc_b64 := UTL_RAW.CAST_TO_VARCHAR2(
      UTL_ENCODE.BASE64_ENCODE(l_doc_content)
    );

    -- Build OCI Document Understanding request
    l_req_body :=
      '{'
      || '"processorConfig":{"processorType":"GENERAL","features":[{"featureType":"DOCUMENT_CLASSIFICATION"}]},'
      || '"document":{"source":"INLINE","data":"' || l_doc_b64 || '"}'
      || '}';

    l_response := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
      p_url         => C_DOC_AI_URL,
      p_http_method => 'POST',
      p_body        => l_req_body,
      p_credential_static_id => 'OCI_GENAI_CRED',
      p_http_headers => APEX_WEB_SERVICE.NEW_HEADERS(
        APEX_WEB_SERVICE.NEW_HEADER('Content-Type','application/json')
      )
    );

    APEX_JSON.PARSE(l_response);
    l_doc_type   := APEX_JSON.GET_VARCHAR2(p_path => 'pages[1].documentClassification.documentType');
    l_confidence := APEX_JSON.GET_NUMBER(p_path  => 'pages[1].documentClassification.confidence');

    -- Map OCI label to KYC doc type
    l_kyc_doc_type := CASE l_doc_type
      WHEN 'PASSPORT'         THEN 'Passport'
      WHEN 'DRIVING_LICENSE'  THEN 'Driving Licence'
      WHEN 'BANK_STATEMENT'   THEN 'Bank Statement'
      WHEN 'TAX_FORM'         THEN 'Tax Document'
      WHEN 'INVOICE'          THEN 'Invoice'
      WHEN 'RECEIPT'          THEN 'Receipt'
      WHEN 'CHEQUE'           THEN 'Cheque'
      ELSE 'Unknown — Officer Review Required'
    END;

    -- Store classification result
    UPDATE QD_KYC_DOCUMENTS
    SET    ai_doc_type         = l_kyc_doc_type,
           ai_confidence_score = l_confidence,
           ai_doc_corrected_flag = 'N'
    WHERE  document_id = p_document_id;

    -- Audit
    INSERT INTO QD_KYC_AI_AUDIT (
      document_id, ai_feature, model_id, prompt_hash,
      ai_response, action_user_id
    ) VALUES (
      p_document_id,
      'DOC_CLASSIFY',
      'OCI_AI_DOCUMENT_UNDERSTANDING',
      LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(
        UTL_RAW.CAST_TO_RAW(TO_CHAR(p_document_id)),
        DBMS_CRYPTO.HASH_SH256
      ))),
      l_response,
      APEX_CUSTOM_AUTH.GET_USER_ID
    );
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END CLASSIFY_DOCUMENT;

END QD_KYC_DOC_AI;
/
```

### 6.3 APEX Dynamic Action — Post Upload Classification

On the Document Upload page:

1. **Event:** After Successful Upload (File Browse item `P20_DOC_FILE`)
2. **True Action 1:** Execute Server-Side Code

```sql
BEGIN
  QD_KYC_DOC_AI.CLASSIFY_DOCUMENT(p_document_id => :P20_DOCUMENT_ID);
END;
```

3. **True Action 2:** Refresh region `Documents_List` to display classification badges.

Display badge logic in the Documents interactive grid: show confidence as a coloured badge (green >= 0.80, amber 0.50–0.79, red < 0.50). When red or `Unknown`, the officer's `ai_doc_corrected_type` field becomes mandatory before the document can be marked as verified.

---

## 7. OCI Generative AI — Risk Scoring

### 7.1 Package `QD_KYC_AI_RISK`

```sql
CREATE OR REPLACE PACKAGE QD_KYC_AI_RISK AS

  PROCEDURE SUGGEST_RISK_LEVEL (p_report_id IN NUMBER);
  PROCEDURE ACCEPT_SUGGESTION  (p_report_id IN NUMBER, p_user_id IN NUMBER);
  PROCEDURE OVERRIDE_SUGGESTION(
    p_report_id     IN NUMBER,
    p_user_id       IN NUMBER,
    p_override_reason IN VARCHAR2
  );

END QD_KYC_AI_RISK;
/
```

### 7.2 Package Body

```sql
CREATE OR REPLACE PACKAGE BODY QD_KYC_AI_RISK AS

  C_CHAT_URL   CONSTANT VARCHAR2(500) :=
    'https://inference.generativeai.us-chicago-1.oci.oraclecloud.com'
    || '/20231130/actions/chat';
  C_CHAT_MODEL CONSTANT VARCHAR2(200) := 'meta.llama-3.1-70b-instruct';

  ----------------------------------------------------------------------------
  PROCEDURE SUGGEST_RISK_LEVEL (p_report_id IN NUMBER) IS
    l_entity_name   VARCHAR2(500);
    l_country       VARCHAR2(100);
    l_fatf_tier     VARCHAR2(20);
    l_pep_flag      CHAR(1);
    l_ownership_layers NUMBER;
    l_screening_match  VARCHAR2(20);
    l_prompt        CLOB;
    l_req_body      CLOB;
    l_response      CLOB;
    l_risk_level    VARCHAR2(10);
    l_rationale     VARCHAR2(2000);
    l_prompt_hash   VARCHAR2(64);
  BEGIN
    -- Gather report context
    SELECT e.entity_name,
           e.country_of_incorporation,
           e.fatf_tier,
           e.pep_flag,
           e.ownership_layers,
           e.screening_status
    INTO   l_entity_name, l_country, l_fatf_tier,
           l_pep_flag, l_ownership_layers, l_screening_match
    FROM   QD_KYC_REPORT r
    JOIN   QD_KYC_ENTITY e ON e.entity_id = r.entity_id
    WHERE  r.report_id = p_report_id;

    -- Build structured prompt
    l_prompt :=
      'You are a KYC compliance analyst for Qatari Diar, a Qatari sovereign wealth real estate company. '
      || 'Assess the following entity and return ONLY valid JSON in this exact format: '
      || '{"risk_level":"LOW|MEDIUM|HIGH","rationale":"<max 300 words>"}' || CHR(10)
      || CHR(10)
      || 'Entity: ' || l_entity_name || CHR(10)
      || 'Country of Incorporation: ' || l_country || CHR(10)
      || 'FATF Tier: ' || l_fatf_tier || CHR(10)
      || 'PEP Status: ' || CASE l_pep_flag WHEN 'Y' THEN 'YES' ELSE 'NO' END || CHR(10)
      || 'Ownership Layers: ' || TO_CHAR(l_ownership_layers) || CHR(10)
      || 'Screening Match Status: ' || l_screening_match || CHR(10)
      || CHR(10)
      || 'Apply FATF recommendations, Qatari AML Law No. 4 of 2010, and standard CDD thresholds. '
      || 'Do not include any text outside the JSON object.';

    -- Hash prompt for audit
    l_prompt_hash := LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(
      UTL_I18N.STRING_TO_RAW(l_prompt, 'AL32UTF8'),
      DBMS_CRYPTO.HASH_SH256
    )));

    -- Build OCI Gen AI chat request
    l_req_body :=
      '{"model":"' || C_CHAT_MODEL || '",'
      || '"chatRequest":{"messages":[{"role":"USER","content":[{"type":"TEXT","text":'
      || APEX_JSON.STRINGIFY(l_prompt)
      || '}]}],"maxTokens":500,"temperature":0.1,"isStream":false}}';

    l_response := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
      p_url         => C_CHAT_URL,
      p_http_method => 'POST',
      p_body        => l_req_body,
      p_credential_static_id => 'OCI_GENAI_CRED',
      p_http_headers => APEX_WEB_SERVICE.NEW_HEADERS(
        APEX_WEB_SERVICE.NEW_HEADER('Content-Type','application/json')
      )
    );

    -- Parse JSON response: {"chatResponse":{"text":"{\"risk_level\":\"HIGH\",...}"}}
    APEX_JSON.PARSE(l_response);
    DECLARE
      l_inner CLOB;
    BEGIN
      l_inner := APEX_JSON.GET_CLOB_OUTPUT;  -- fallback
      l_inner := APEX_JSON.GET_VARCHAR2(p_path => 'chatResponse.text');
      APEX_JSON.PARSE(l_inner);
      l_risk_level := APEX_JSON.GET_VARCHAR2(p_path => 'risk_level');
      l_rationale  := APEX_JSON.GET_VARCHAR2(p_path => 'rationale');
    END;

    -- Validate
    IF l_risk_level NOT IN ('LOW','MEDIUM','HIGH') THEN
      RAISE_APPLICATION_ERROR(-20010, 'AI returned invalid risk level: ' || l_risk_level);
    END IF;

    UPDATE QD_KYC_REPORT
    SET    ai_risk_suggestion = l_risk_level,
           ai_risk_rationale  = l_rationale
    WHERE  report_id = p_report_id;

    INSERT INTO QD_KYC_AI_AUDIT (
      report_id, ai_feature, model_id, prompt_hash, ai_response, action_user_id
    ) VALUES (
      p_report_id, 'RISK_SCORING', C_CHAT_MODEL, l_prompt_hash, l_response,
      APEX_CUSTOM_AUTH.GET_USER_ID
    );
    COMMIT;
  END SUGGEST_RISK_LEVEL;

  ----------------------------------------------------------------------------
  PROCEDURE ACCEPT_SUGGESTION (p_report_id IN NUMBER, p_user_id IN NUMBER) IS
  BEGIN
    UPDATE QD_KYC_REPORT
    SET    ai_risk_accepted_flag = 'Y',
           risk_level            = ai_risk_suggestion
    WHERE  report_id = p_report_id;

    UPDATE QD_KYC_AI_AUDIT
    SET    accepted_flag   = 'Y',
           action_user_id  = p_user_id
    WHERE  report_id   = p_report_id
    AND    ai_feature  = 'RISK_SCORING'
    AND    audit_id    = (
      SELECT MAX(audit_id) FROM QD_KYC_AI_AUDIT
      WHERE  report_id = p_report_id AND ai_feature = 'RISK_SCORING'
    );
    COMMIT;
  END ACCEPT_SUGGESTION;

  ----------------------------------------------------------------------------
  PROCEDURE OVERRIDE_SUGGESTION (
    p_report_id       IN NUMBER,
    p_user_id         IN NUMBER,
    p_override_reason IN VARCHAR2
  ) IS
  BEGIN
    IF p_override_reason IS NULL OR LENGTH(TRIM(p_override_reason)) < 10 THEN
      RAISE_APPLICATION_ERROR(-20011,
        'Override reason is mandatory and must be at least 10 characters.');
    END IF;

    UPDATE QD_KYC_REPORT
    SET    ai_risk_accepted_flag   = 'N',
           ai_risk_override_reason = p_override_reason
    WHERE  report_id = p_report_id;

    UPDATE QD_KYC_AI_AUDIT
    SET    accepted_flag   = 'N',
           override_reason = p_override_reason,
           action_user_id  = p_user_id
    WHERE  report_id   = p_report_id
    AND    ai_feature  = 'RISK_SCORING'
    AND    audit_id    = (
      SELECT MAX(audit_id) FROM QD_KYC_AI_AUDIT
      WHERE  report_id = p_report_id AND ai_feature = 'RISK_SCORING'
    );
    COMMIT;
  END OVERRIDE_SUGGESTION;

END QD_KYC_AI_RISK;
/
```

### 7.3 APEX Page Wiring

On the Report Review page:

- **Button** SUGGEST_RISK (label: "Get AI Risk Suggestion") — calls process `AI_SUGGEST_RISK`, then refreshes the risk region.
- **Display Only** field P25_AI_RISK_SUGGESTION bound to `ai_risk_suggestion`.
- **Text Area** P25_AI_RISK_RATIONALE (read only) bound to `ai_risk_rationale`.
- **Button** ACCEPT_RISK — visible only when `ai_risk_suggestion IS NOT NULL AND ai_risk_accepted_flag IS NULL`. Calls `QD_KYC_AI_RISK.ACCEPT_SUGGESTION`.
- **Button** OVERRIDE_RISK — opens inline dialog with mandatory textarea for override reason. Calls `QD_KYC_AI_RISK.OVERRIDE_SUGGESTION`.

---

## 8. OCI Generative AI — Conclusion Drafting

### 8.1 Package `QD_KYC_AI_CONCLUSION`

```sql
CREATE OR REPLACE PACKAGE QD_KYC_AI_CONCLUSION AS

  PROCEDURE GENERATE_DRAFT (p_report_id IN NUMBER);

END QD_KYC_AI_CONCLUSION;
/

CREATE OR REPLACE PACKAGE BODY QD_KYC_AI_CONCLUSION AS

  C_CHAT_URL   CONSTANT VARCHAR2(500) :=
    'https://inference.generativeai.us-chicago-1.oci.oraclecloud.com'
    || '/20231130/actions/chat';
  C_CHAT_MODEL CONSTANT VARCHAR2(200) := 'meta.llama-3.1-70b-instruct';

  PROCEDURE GENERATE_DRAFT (p_report_id IN NUMBER) IS
    l_entity_name   VARCHAR2(500);
    l_country       VARCHAR2(100);
    l_fatf_tier     VARCHAR2(20);
    l_pep_flag      CHAR(1);
    l_risk_level    VARCHAR2(10);
    l_screening     VARCHAR2(20);
    l_doc_count     NUMBER;
    l_existing_draft CLOB;
    l_prompt        CLOB;
    l_req_body      CLOB;
    l_response      CLOB;
    l_draft_text    CLOB;
    l_prompt_hash   VARCHAR2(64);
  BEGIN
    -- Immutability guard — draft cannot be regenerated once saved
    SELECT ai_conclusion_draft
    INTO   l_existing_draft
    FROM   QD_KYC_REPORT
    WHERE  report_id = p_report_id;

    IF l_existing_draft IS NOT NULL THEN
      RAISE_APPLICATION_ERROR(-20012,
        'AI conclusion draft already exists for this report and cannot be regenerated.');
    END IF;

    -- Gather context
    SELECT e.entity_name, e.country_of_incorporation, e.fatf_tier,
           e.pep_flag, r.risk_level, e.screening_status,
           (SELECT COUNT(*) FROM QD_KYC_DOCUMENTS d WHERE d.report_id = r.report_id)
    INTO   l_entity_name, l_country, l_fatf_tier,
           l_pep_flag, l_risk_level, l_screening, l_doc_count
    FROM   QD_KYC_REPORT r
    JOIN   QD_KYC_ENTITY e ON e.entity_id = r.entity_id
    WHERE  r.report_id = p_report_id;

    l_prompt :=
      'You are a KYC compliance officer at Qatari Diar. '
      || 'Write a formal KYC conclusion paragraph (200-300 words) for the following entity review. '
      || 'Use professional regulatory language. Do not include section headings or bullet points — '
      || 'produce a single flowing paragraph suitable for a compliance report.' || CHR(10)
      || CHR(10)
      || 'Entity Name: '           || l_entity_name  || CHR(10)
      || 'Country: '               || l_country      || CHR(10)
      || 'FATF Tier: '             || l_fatf_tier     || CHR(10)
      || 'PEP: '                   || CASE l_pep_flag WHEN 'Y' THEN 'Yes' ELSE 'No' END || CHR(10)
      || 'Risk Level Assigned: '   || l_risk_level    || CHR(10)
      || 'Screening Outcome: '     || l_screening     || CHR(10)
      || 'Documents Reviewed: '    || TO_CHAR(l_doc_count) || CHR(10);

    l_prompt_hash := LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(
      UTL_I18N.STRING_TO_RAW(l_prompt, 'AL32UTF8'),
      DBMS_CRYPTO.HASH_SH256
    )));

    l_req_body :=
      '{"model":"' || C_CHAT_MODEL || '",'
      || '"chatRequest":{"messages":[{"role":"USER","content":[{"type":"TEXT","text":'
      || APEX_JSON.STRINGIFY(l_prompt)
      || '}]}],"maxTokens":700,"temperature":0.3,"isStream":false}}';

    l_response := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
      p_url         => C_CHAT_URL,
      p_http_method => 'POST',
      p_body        => l_req_body,
      p_credential_static_id => 'OCI_GENAI_CRED',
      p_http_headers => APEX_WEB_SERVICE.NEW_HEADERS(
        APEX_WEB_SERVICE.NEW_HEADER('Content-Type','application/json')
      )
    );

    APEX_JSON.PARSE(l_response);
    l_draft_text := APEX_JSON.GET_VARCHAR2(p_path => 'chatResponse.text');

    -- Save draft — immutable from this point
    UPDATE QD_KYC_REPORT
    SET    ai_conclusion_draft    = l_draft_text,
           ai_conclusion_gen_date = SYSDATE
    WHERE  report_id = p_report_id;

    INSERT INTO QD_KYC_AI_AUDIT (
      report_id, ai_feature, model_id, prompt_hash, ai_response, action_user_id
    ) VALUES (
      p_report_id, 'CONCLUSION_DRAFT', C_CHAT_MODEL, l_prompt_hash, l_response,
      APEX_CUSTOM_AUTH.GET_USER_ID
    );
    COMMIT;
  END GENERATE_DRAFT;

END QD_KYC_AI_CONCLUSION;
/
```

### 8.2 APEX Page Implementation

On the Report Conclusion page:

- **Button** GENERATE_DRAFT (label: "Generate AI Draft") — visible only when `ai_conclusion_draft IS NULL`. After click, calls server-side process invoking `QD_KYC_AI_CONCLUSION.GENERATE_DRAFT`, then refreshes the page.
- **Text Area** P30_CONCLUSION — editable. Initially populated from `ai_conclusion_draft`. Officer edits this field before final submission.
- `ai_conclusion_draft` column is never modified after first save. The officer's final text is stored in a separate `conclusion_text` column on `QD_KYC_REPORT`.
- The Generate Draft button is conditionally hidden once `ai_conclusion_draft IS NOT NULL`, enforcing single-generation.

---

## 9. APEX AI Assistant Configuration

APEX 26 introduces a built-in AI Assistant configurable at workspace level. Configure in APEX Administration → Workspace Settings → AI Assistant.

| Setting | Value |
|---|---|
| Enable AI Assistant | Yes |
| AI Provider | OCI Generative AI |
| OCI Credential | OCI_GENAI_CRED |
| Model | `meta.llama-3.1-70b-instruct` or `cohere.command-r-plus` |
| System Prompt | See below |
| Allowed Schema Objects | `QD_KYC_REF_*` tables and `QD_KYC_REF_COUNTRY` only |
| Blocked Objects | All `QD_KYC_REPORT`, `QD_KYC_ENTITY`, `QD_KYC_DOCUMENTS`, `QD_KYC_AI_AUDIT` |

System prompt:

```
You are a KYC compliance assistant for Qatari Diar Real Estate Investment Company.
You help KYC officers understand compliance policies, FATF recommendations, Qatar AML regulations,
document requirements, and risk categorisation guidelines.
You MUST NOT retrieve, display, or reference any individual report data, entity data,
personal data, or document content from the database.
You MAY only answer general policy questions and reference publicly available regulatory guidance.
If asked for data about a specific entity, report, or individual, respond:
"I cannot provide data on specific cases. Please use the KYC Report screen to review that information."
```

Data access enforcement: in APEX 26 AI Assistant page settings, grant the assistant access only to the `QD_KYC_REF_*` reference tables. Do not grant it the `KYC_SELECT_AI` profile or any base table access. The assistant's data access runs under a dedicated low-privilege database role `QD_KYC_AI_ASSIST_ROLE` that has SELECT on reference tables only.

```sql
CREATE ROLE QD_KYC_AI_ASSIST_ROLE;
GRANT SELECT ON QD_KYC_REF_COUNTRY      TO QD_KYC_AI_ASSIST_ROLE;
GRANT SELECT ON QD_KYC_REF_DOC_TYPE     TO QD_KYC_AI_ASSIST_ROLE;
GRANT SELECT ON QD_KYC_REF_RISK_FACTOR  TO QD_KYC_AI_ASSIST_ROLE;
```

---

## 10. AI Audit Trail

The `QD_KYC_AI_AUDIT` table is the single record of all AI interactions. Every AI feature writes one row per invocation before committing. The immutability trigger prevents post-hoc modification.

| Feature | Trigger | Fields Captured |
|---|---|---|
| Vector Search | Duplicate check run by officer or nightly job | `entity_id`, query text hash (`prompt_hash`), top result distance scores in `ai_response` |
| Doc Classification | Document uploaded to system | `document_id`, `ai_doc_type`, confidence score, full OCI response in `ai_response` |
| Risk Scoring | Officer clicks "Get AI Risk Suggestion" | `report_id`, `model_id`, `prompt_hash`, suggested level, `accepted_flag`, `override_reason` |
| Conclusion Draft | Officer clicks "Generate AI Draft" | `report_id`, `model_id`, `prompt_hash`, draft character length, full response in `ai_response` |
| Select AI | Officer submits natural language query | `action_user_id`, query hash in `prompt_hash`, note in `ai_response` — raw query data is never stored |

Downstream reports join `QD_KYC_AI_AUDIT` to `QD_KYC_REPORT` to produce per-report AI decision summaries for compliance review. The audit table is included in the ATP scheduled export to OCI Object Storage alongside `QD_KYC_PROCESS_LOG`.

Immutability trigger (restated for completeness):

```sql
CREATE OR REPLACE TRIGGER trg_ai_audit_immutable
  BEFORE UPDATE OR DELETE ON QD_KYC_AI_AUDIT
  FOR EACH ROW
BEGIN
  RAISE_APPLICATION_ERROR(-20001,
    'QD_KYC_AI_AUDIT is immutable. UPDATE and DELETE are not permitted.');
END trg_ai_audit_immutable;
/
```

---

## 11. Acceptance Test Checklist

The following tests are specific to V6 AI features. All V5 acceptance tests remain applicable.

### AI Vector Search

- [ ] Enter an entity name variation (abbreviation, Arabic transliteration) in the entity edit form — vector search returns the matching entity with distance < 0.20 within 3 seconds.
- [ ] Enter an unrelated name — no results returned with distance < 0.30.
- [ ] Run `QD_KYC_REFRESH_EMBEDDINGS` job manually — completes without error; `embedding_date` updated for entities modified in last 24 hours.
- [ ] Verify `QD_KYC_ENTITY.name_embedding` is populated (not NULL) for all entities after full refresh run.

### Select AI

- [ ] Submit 5 test natural language queries and verify the returned SQL references only `QD_KYC_V_REPORT_SEARCH`, `QD_KYC_V_ENTITY_SEARCH`, or `QD_KYC_V_INTAKE_SEARCH`.
- [ ] Confirm SQL generated does not reference `QD_KYC_DOCUMENTS`, `QD_KYC_ENTITY` base table, or `QD_KYC_REPORT` base table directly.
- [ ] Each query execution inserts a row in `QD_KYC_AI_AUDIT` with `ai_feature = 'SELECT_AI'`.

### Document Classification

- [ ] Upload a Commercial Registration PDF — OCI returns label, confidence badge displays in document region.
- [ ] Upload a Passport JPEG — OCI returns `PASSPORT` label with confidence >= 0.80; badge displays green.
- [ ] Upload an Ownership Declaration — OCI returns unknown or low-confidence label (< 0.50); badge displays red; officer correction fields become mandatory.
- [ ] Correct an AI classification — `ai_doc_corrected_flag = 'Y'` and `ai_doc_corrected_type` saved; audit row written.

### Risk Scoring

- [ ] On a report with entity data and screening status saved, click "Get AI Risk Suggestion" — `ai_risk_suggestion` populated within 10 seconds.
- [ ] Click "Accept" — `ai_risk_accepted_flag = 'Y'`, `risk_level` updated to match suggestion.
- [ ] Click "Override" with no reason text — validation error raised; save blocked.
- [ ] Click "Override" with valid reason (>= 10 chars) — `ai_risk_accepted_flag = 'N'`, `ai_risk_override_reason` saved.
- [ ] Audit row present with `ai_feature = 'RISK_SCORING'` for both accept and override paths.

### Conclusion Drafting

- [ ] Click "Generate AI Draft" on a report — `ai_conclusion_draft` populated; button hidden on page refresh.
- [ ] Attempt to call `QD_KYC_AI_CONCLUSION.GENERATE_DRAFT` a second time on same report — `ORA-20012` raised.
- [ ] Officer edits the conclusion textarea and saves — `conclusion_text` updated; `ai_conclusion_draft` column unchanged.
- [ ] Audit row present with `ai_feature = 'CONCLUSION_DRAFT'`.

### AI Audit Immutability

- [ ] Execute `UPDATE QD_KYC_AI_AUDIT SET accepted_flag = 'Y' WHERE ROWNUM = 1` — `ORA-20001` raised by trigger; no row updated.
- [ ] Execute `DELETE FROM QD_KYC_AI_AUDIT WHERE ROWNUM = 1` — `ORA-20001` raised; no row deleted.

### APEX AI Assistant

- [ ] Ask the AI Assistant a general FATF policy question — coherent answer returned without referencing any specific entity or report data.
- [ ] Ask the AI Assistant "Show me all HIGH risk reports" — assistant returns the standard refusal message without querying the database.
- [ ] Confirm assistant session does not have access to `QD_KYC_REPORT` or `QD_KYC_ENTITY` by inspecting grants on `QD_KYC_AI_ASSIST_ROLE`.
