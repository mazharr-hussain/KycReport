# Oracle APEX System Architecture

The technical architecture of the target KYC system built on Oracle APEX with Oracle Fusion HCM integration.

!!! tip "How to edit this diagram"
    1. Go to [diagrams.net](https://app.diagrams.net)
    2. Open via **File → Open from → GitHub**
    3. Navigate to `docs/diagrams/drawio/apex-architecture.drawio`
    4. Edit visually and save — it commits directly to GitHub
    5. Netlify rebuilds and this page updates automatically

![APEX System Architecture](drawio/apex-architecture.drawio)

---

## System Architecture Overview

```mermaid
graph TB
    subgraph USERS["Users — Any Web Browser"]
        U1[Requestor\nBusiness Dept]
        U2[Compliance Officer\nContributor]
        U3[L1 Approver]
        U4[L2 Approver / MLRO]
        U5[Administrator]
    end

    subgraph APEX["Oracle APEX — Application Server"]
        APP[APEX Application 100\nKYC Management System]
        AUTH[IDCS SSO\nAuthentication Scheme]
        VPD[Virtual Private Database\nRow-Level Security]
        WORKFLOW[APEX Workflow Engine\nQD_KYC_WORKFLOW]
        MAIL[APEX_MAIL\nEmail Notifications]
    end

    subgraph DB["Oracle Database 19c/21c"]
        SCHEMA[QD_KYC Schema]
        TABLES[Tables\nIntake · Entity · UBO\nReport · Approval · Documents\nProcess Log · Users]
        TRIGGERS[Audit Triggers\nImmutable ProcessLog]
        SCHEDULER[DBMS_SCHEDULER\nNightly Sync + Monitoring]
        PACKAGES[PL/SQL Packages\nQD_KYC_WORKFLOW\nQD_KYC_UTILS\nQD_KYC_NOTIFICATIONS\nQD_KYC_SECURITY]
    end

    subgraph FUSION["Oracle Fusion HCM Cloud"]
        FUSION_API[HCM REST API\n/hcm/v4/workers]
        FUSION_IDCS[Oracle IDCS\nIdentity Cloud Service]
    end

    subgraph EXTERNAL["External — Manual Process"]
        WORLDCHECK[WorldCheck\nRefinitiv\nManual Screening]
    end

    U1 & U2 & U3 & U4 & U5 -->|HTTPS| APP
    APP --> AUTH
    AUTH <-->|SSO Token| FUSION_IDCS
    APP --> VPD
    VPD --> SCHEMA
    APP --> WORKFLOW
    WORKFLOW --> PACKAGES
    PACKAGES --> TABLES
    TABLES --> TRIGGERS
    SCHEDULER -->|Nightly sync| FUSION_API
    FUSION_API -->|Employee data| SCHEMA
    WORKFLOW --> MAIL
    U2 -.->|Manual screening\nresults recorded in system| WORLDCHECK

    style USERS fill:#F3E5F5,stroke:#7B1FA2
    style APEX fill:#E3F2FD,stroke:#1565C0
    style DB fill:#E8F5E9,stroke:#2E7D32
    style FUSION fill:#FFF3E0,stroke:#E65100
    style EXTERNAL fill:#FFEBEE,stroke:#B71C1C
```

---

## Authentication & User Provisioning Flow

```mermaid
sequenceDiagram
    participant User
    participant APEX
    participant IDCS as Oracle IDCS
    participant Fusion as Fusion HCM API
    participant DB as Oracle DB

    User->>APEX: Navigate to KYC URL
    APEX->>IDCS: Redirect to SSO login
    User->>IDCS: Enter Fusion credentials
    IDCS-->>APEX: OAuth token + user attributes
    APEX->>DB: POST_AUTHENTICATION trigger
    DB->>DB: Look up user in QD_KYC_USERS

    alt User exists in local cache
        DB-->>APEX: Return role + permissions
    else First login — user not yet synced
        DB->>Fusion: REST call /hcm/v4/workers/{personId}
        Fusion-->>DB: Employee record + job code
        DB->>DB: Insert into QD_KYC_USERS\nMap job code to KYC role
        DB-->>APEX: Return role + permissions
    end

    APEX->>User: Show personalised home page
```

---

## Nightly Sync Process

```mermaid
flowchart TD
    SCHED([DBMS_SCHEDULER\nRuns nightly at 02:00]) --> FETCH

    FETCH[Fetch active workers\nfrom Fusion HCM REST API\n/hcm/v4/workers?q=activeFlag=Y]

    FETCH --> LOOP[For each employee]

    LOOP --> EXISTS{Exists in\nQD_KYC_USERS?}

    EXISTS -->|Yes| UPDATE[UPDATE record\nname, email, job_code\nif changed]
    EXISTS -->|No| INSERT[INSERT new user\nMap job_code to kyc_role]

    UPDATE & INSERT --> DEACT

    DEACT[Deactivate users\nnot in Fusion response\n= left company]

    DEACT --> LOG[Write to sync log\ntimestamp + count]

    style SCHED fill:#F3E5F5,color:#4A148C
    style DEACT fill:#FFEBEE,color:#7F0000
```

---

## Security Model — VPD Row-Level Security

```mermaid
flowchart LR
    QUERY([Any SELECT\non QD_KYC_REPORT]) --> VPD[VPD Policy\nQD_KYC_SECURITY\n.REPORT_POLICY]

    VPD --> ROLE{User Role\nfrom APP_KYC_ROLE}

    ROLE -->|CONTRIBUTOR| OWN[WHERE created_by = :user_id\nOR status = RFI AND owner = :user_id]
    ROLE -->|APPROVER_L1| L1_VIEW[WHERE status IN\nPENDING_L1, APPROVED_L1]
    ROLE -->|APPROVER_L2| L2_VIEW[WHERE status IN\nAPPROVED_L1, PENDING_L2]
    ROLE -->|ADMIN| ALL[No filter\nSee all records]

    style VPD fill:#F3E5F5,color:#4A148C
    style ALL fill:#E8F5E9,color:#1B5E20
```

---

## Application Page Structure

| Page Group | Page Numbers | Audience |
|---|---|---|
| Public / Auth | 101 (Login), 9999 (Error) | All |
| Requestor Portal | 70–79 | Requestors |
| Compliance Worklist | 1–19 | Contributors |
| Entity Management | 20–29 | Contributors |
| KYC Report | 10–19 | Contributors |
| L1 Approval Queue | 30–39 | Approvers L1 |
| L2 Approval Queue | 40–49 | Approvers L2 |
| Administration | 80–89 | Administrators |
| Executive Dashboard | 90–99 | Admins + Management |

---

## Technology Stack

| Layer | Technology | Version |
|---|---|---|
| Application | Oracle APEX | 23.2+ |
| Database | Oracle Database | 19c / 21c |
| Authentication | Oracle IDCS SSO | — |
| User Source | Oracle Fusion HCM Cloud | REST API v4 |
| Email | APEX_MAIL (SMTP) | — |
| Fuzzy Matching | UTL_MATCH.JARO_WINKLER_SIMILARITY | Built-in |
| Row Security | DBMS_RLS (VPD) | Built-in |
| Scheduling | DBMS_SCHEDULER | Built-in |
| Workflow | APEX_WORKFLOW | APEX 23.2+ |
