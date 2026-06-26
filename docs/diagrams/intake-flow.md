# Intake & Document Validation Flow

Covers Phase 0 (Request Intake) and Phase 1 (Document Validation) of the KYC process.

!!! tip "How to edit this diagram"
    1. Go to [diagrams.net](https://app.diagrams.net)
    2. Open via **File → Open from → GitHub**
    3. Navigate to `docs/diagrams/drawio/intake-flow.drawio`
    4. Edit visually and save — it commits directly to GitHub
    5. Netlify rebuilds and this page updates automatically

![Intake & Document Validation Flow](drawio/intake-flow.drawio)

---

## Phase 0 — Structured Digital Intake

```mermaid
flowchart TD
    DEPT([Business Department]) --> PORTAL

    PORTAL[Open KYC Request Portal\nwww - APEX Application]

    PORTAL --> AUTOFILL[Name & Department\nauto-filled from Oracle Fusion HCM]
    AUTOFILL --> FORM

    FORM[Complete Intake Form\n• Counterparty name, type, country\n• Relationship type\n• Financial involvement\n• Related party declaration]

    FORM --> RULES{KYC Rules\nEngine}

    RULES -->|KYC Not Required| WAIVER
    RULES -->|KYC Required| DOCS

    WAIVER[Create Waiver Record\n+ Store Documents\n→ Confirmation to Department]

    DOCS[Show Document Checklist\nbased on entity type & country]
    DOCS --> UPLOAD[Department Uploads Documents\ndirectly in portal — no email]
    UPLOAD --> SUBMIT[Submit]
    SUBMIT --> CASE[System Creates Case\nINTAKE-YYYY-NNNNNN\nNotify Compliance Team]

    style DEPT fill:#E3F2FD,color:#0D47A1,stroke:#1565C0
    style WAIVER fill:#E8F5E9,color:#1B5E20,stroke:#2E7D32
    style CASE fill:#E8EAF6,color:#1A237E,stroke:#3949AB
```

---

## Phase 1 — Document Validation

```mermaid
flowchart TD
    CASE([Case Arrives in\nCompliance Queue]) --> OFFICER

    OFFICER[Compliance Officer\nReviews Documents\nagainst checklist]

    OFFICER --> CHECK{Documents\nComplete?}

    CHECK -->|No — Missing or Unclear| RFQ
    CHECK -->|Yes — All Documents Present| CONFIRM

    RFQ[Send Structured Document Request\n• Select missing document type\n• Set deadline\n• System sends notification to department]

    RFQ --> DEPT_UPLOAD[Department Uploads\nvia Portal\nnot by email]

    DEPT_UPLOAD --> AUTO_REMIND{Deadline\nPassed?}
    AUTO_REMIND -->|Yes| REMINDER[Automatic Reminder Sent\nto Department & Manager]
    AUTO_REMIND -->|No| OFFICER

    REMINDER --> OFFICER

    CONFIRM[Officer marks:\nDocuments Complete ✅]
    CONFIRM --> KPI_START[KPI Clock Starts\ndocs_complete_date recorded\nSLA begins from here]

    KPI_START --> DUP_CHECK

    DUP_CHECK[System runs Duplicate Check\nV3–V5: Jaro-Winkler fuzzy match\nV6: AI Vector Search cosine similarity]

    DUP_CHECK --> DUP{Match\nFound?}
    DUP -->|Similar name found| SHOW_MATCH[Show Officer\nExisting Record]
    DUP -->|No match| CREATE_ENTITY

    SHOW_MATCH --> OFFICER_DECIDE{Officer\nDecides}
    OFFICER_DECIDE -->|Same entity — link to existing| LINK[Link to Existing Entity\nNo duplicate created]
    OFFICER_DECIDE -->|Different entity — create new| CREATE_ENTITY

    CREATE_ENTITY([Proceed to Phase 2\nRisk Pre-Assessment])
    LINK([Proceed to Phase 2\nRisk Pre-Assessment])

    style CASE fill:#E3F2FD,color:#0D47A1,stroke:#1565C0
    style KPI_START fill:#F3E5F5,color:#4A148C,stroke:#6A1B9A
    style CREATE_ENTITY fill:#E8EAF6,color:#1A237E,stroke:#3949AB
    style LINK fill:#E8EAF6,color:#1A237E,stroke:#3949AB
```

---

## KPI Note

!!! important "KPI Clock Start Point"

    The turnaround time SLA is measured from `docs_complete_date` — the moment the compliance officer confirms all documents are present and correct.

    It is **not** measured from when the department first sent their email or submitted the form. The compliance team cannot be held accountable for delays in the department providing documentation.

    | KYC Type | SLA Target |
    |---|---|
    | Simplified | 5 business days |
    | Standard | 10 business days |
    | Enhanced | 20 business days |
