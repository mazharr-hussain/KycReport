# Version 3 — Business Process Guide
# Best Practice KYC Process

**Document Type:** Business Process Guide  
**Audience:** Compliance Team, Management, Internal Auditors, Regulators  
**Standards:** FATF 40 Recommendations | Basel KYC | EU 6AMLD (as benchmark) | ISO 31000  
**Note on EU 6AMLD:** The Sixth Anti-Money Laundering Directive is an EU instrument. It is referenced here as an international best-practice benchmark, not as a binding regulatory obligation. Qatari Diar applies these standards where they represent the current global compliance standard and where they govern relationships with European counterparties or subsidiaries.  
**Status:** Target operating model — design for next-generation system  

---

## Why This Redesign?

The requirements gathering session identified that the current process relies too heavily on individual memory, email threads, and personal judgment. This creates inconsistency, audit gaps, and significant operational risk.

This redesigned process achieves four things:
1. **Replaces manual steps** with system-enforced controls wherever the decision is rule-based
2. **Preserves human judgment** for the steps that genuinely require expertise
3. **Creates a complete evidence trail** that satisfies regulatory examination
4. **Gives management visibility** without needing to request data extracts

---

## The Seven Principles This Process Upholds

Every step in this process is designed around seven core compliance principles:

1. **Know Who You Are Dealing With** — Identity verified, ownership traced
2. **Assess the Risk** — Risk level determined systematically, not just by feel
3. **Match the Effort to the Risk** — More scrutiny for higher-risk counterparties
4. **Two Pairs of Eyes** — No single person approves their own work
5. **Leave a Trail** — Every action documented, timestamped, and attributable
6. **Protect the Evidence** — Documents stored properly, not on someone's laptop
7. **Keep It Current** — KYCs reviewed regularly, not just once

---

## Complete To-Be Process — One Page

```mermaid
flowchart TD
    START([Business Department]) --> P0

    subgraph PORTAL["Self-Service Portal — Business Department"]
        P0[Phase 0\nStructured Digital Intake\nWeb Form + Rules Engine]
        P0 -->|Not Required| WAIVER([Waiver Record Created\nDocuments stored automatically])
        P0 -->|Required| P1[Phase 1\nDocument Upload\nvia Portal]
    end

    subgraph SYSTEM["Oracle APEX — KYC Management System"]
        P1B[Phase 1\nDocument Validation\nCompliance Officer\nSystem checklist + SLA clock starts]
        P1B --> P2[Phase 2\nRisk Pre-Assessment\nSystem suggests risk level\nOfficer confirms or overrides]
        P2 --> P3[Phase 3\nDue Diligence\nStructured screening record\nper entity and UBO]
        P3 --> P4[Phase 4 & 5\nEntity + KYC Report\nAuto-populated from intake\nNo re-entry]
        P4 --> P6[Phase 6\nLevel 1 Approval\nWith automatic delegation]
        P6 -->|Low Risk| DONE
        P6 -->|Medium / High Risk| P7[Phase 7\nLevel 2 / MLRO Approval\nMandatory SAR gate]
        P7 --> DONE([Phase 8\nCompletion\nPDF generated\nRequestor notified automatically\nReview date set])
    end

    P1 --> P1B

    style PORTAL fill:#E8F5E9,stroke:#2E7D32,color:#1B5E20
    style SYSTEM fill:#E8EAF6,stroke:#3949AB,color:#1A237E
    style START fill:#E3F2FD,color:#0D47A1,stroke:#1565C0
    style WAIVER fill:#E8F5E9,color:#1B5E20,stroke:#2E7D32
    style DONE fill:#E8F5E9,color:#1B5E20,stroke:#2E7D32
    style P0 fill:#E8F5E9,color:#1B5E20,stroke:#2E7D32
    style P1 fill:#E8F5E9,color:#1B5E20,stroke:#2E7D32
    style P1B fill:#E8EAF6,color:#1A237E,stroke:#3949AB
    style P2 fill:#E8EAF6,color:#1A237E,stroke:#3949AB
    style P3 fill:#E8EAF6,color:#1A237E,stroke:#3949AB
    style P4 fill:#E8EAF6,color:#1A237E,stroke:#3949AB
    style P6 fill:#E8EAF6,color:#1A237E,stroke:#3949AB
    style P7 fill:#E8EAF6,color:#1A237E,stroke:#3949AB
```

---

## The Improved Process: Phase by Phase

---

### Phase 0: Standardised Digital Intake

**What changes:** Business departments no longer send emails in any format they like. Instead, they complete a **structured digital intake form** in the system.

**How it works:**

```mermaid
flowchart TD
    DEPT([Business Department\nOpens KYC Request Portal]) --> AUTOFILL[Name & department\nauto-filled from Oracle Fusion HCM]
    AUTOFILL --> FORM[Fills in structured form:\nCounterparty name, type, country\nRelationship type\nFinancial involvement\nRelated party declaration]
    FORM --> RULES{System Rules Engine\nCalculates automatically}
    RULES -->|KYC Not Required| WAIVER[Waiver record created\nDocuments stored as evidence\nConfirmation sent to dept]
    RULES -->|KYC Required| CHECKLIST[System shows document checklist\nbased on entity type and country]
    CHECKLIST --> UPLOAD[Department uploads documents\ndirectly in portal — no email]
    UPLOAD --> SUBMIT[Submit]
    SUBMIT --> CASE[Case created: INTAKE-YYYY-NNNNNN\nCompliance team notified automatically]

    style WAIVER fill:#E8F5E9,color:#1B5E20,stroke:#2E7D32
    style CASE fill:#E8EAF6,color:#1A237E,stroke:#3949AB
    style DEPT fill:#E3F2FD,color:#0D47A1,stroke:#1565C0
```

**What this fixes:**
- Every request is in the same format, regardless of which department sends it
- When KYC is not required, there is a permanent evidence record — not just a forgotten email
- The documents are attached to the case from the very beginning — no local folders

---

### Phase 1: Document Validation — System-Assisted

**What changes:** The compliance team uses a structured checklist rather than relying on experience and memory. The system tracks how many rounds of document requests happen.

```mermaid
flowchart TD
    REVIEW([Compliance Officer\nReviews Submitted Documents]) --> CHECK{Documents meet\nchecklist?}
    CHECK -->|No — Missing or unclear| REQ[Send structured request to department\nSelect document type\nSet deadline\nSystem sends notification automatically]
    REQ --> UPLOAD[Department uploads via portal\nnot by email\nAll rounds tracked with timestamps]
    UPLOAD --> CHECK
    CHECK -->|Yes — All complete| CONFIRM[Officer marks:\nDocuments Complete ✅]
    CONFIRM --> KPI[System records docs_complete_date\n🕐 KPI Clock Starts Here]

    style KPI fill:#F3E5F5,color:#4A148C,stroke:#6A1B9A
    style CONFIRM fill:#E8F5E9,color:#1B5E20,stroke:#2E7D32
    style REQ fill:#FFF3E0,color:#BF360C,stroke:#E65100
```

**The KPI start point** is the moment the compliance team confirms they have everything they need. Turnaround time is measured from here — not from the first email the department sent — because the compliance team cannot be held accountable for the department's delay in providing documents.

**Duplicate check:**  
When the officer is about to create an entity, the system automatically searches for similar names. If the same company was screened before, the officer is shown the previous record and can choose to link to it, rather than creating a duplicate.

---

### Phase 2: Risk Pre-Assessment

**What is new:** Before the compliance officer begins their research, the system shows them a **risk indicator panel** — a summary of automated risk signals computed from the data already provided.

```mermaid
flowchart LR
    SYS([System Pre-Computes\nRisk Signals]) --> G[🌍 Geographic Risk\nFATF country tier]
    SYS --> E[🏢 Entity Type Risk\nState-owned = PEP-linked]
    SYS --> S[🔗 Structure Risk\nMultiple ownership layers]
    SYS --> H[⚠️ Historical Flags\nPrior adverse findings]
    G & E & S & H --> SUGGEST[System Suggests\nLOW / MEDIUM / HIGH]
    SUGGEST --> OFFICER{Officer\nAgrees?}
    OFFICER -->|Yes| CONFIRM[Confirm risk level\nand proceed]
    OFFICER -->|No| OVERRIDE[Override risk level\nDocument reason — mandatory]

    style SUGGEST fill:#E8EAF6,color:#1A237E,stroke:#3949AB
    style OVERRIDE fill:#FFF3E0,color:#BF360C,stroke:#E65100
    style CONFIRM fill:#E8F5E9,color:#1B5E20,stroke:#2E7D32
```

This does not replace the officer's judgment — it gives them a structured starting point and ensures that obvious risk factors are never overlooked.

**Risk determines the path:**
- **Low risk** → Simplified Due Diligence (one approval required)
- **Medium risk** → Standard KYC (two approvals required)
- **High risk** → Enhanced Due Diligence (two approvals + mandatory additional fields)

---

### Phase 3: Due Diligence Research — Structured Evidence Recording

**What changes:** The screening itself continues to be conducted manually using WorldCheck (or equivalent databases). The change is in how results are **recorded** in the system.

Instead of a free-text box, the officer completes structured fields for each entity and each UBO:

| What is recorded | Example |
|---|---|
| Date screening was performed | 15 June 2025 |
| Which database(s) were checked | WorldCheck (Refinitiv) |
| Reference number from screening tool | WC-2025-123456 |
| Match status | Potential Match / No Match / Confirmed Match / False Positive |
| PEP flag | Yes / No |
| Adverse media flag | Yes / No |
| Findings narrative | Free text — what was found |
| Resolution note | If false positive: why it was dismissed |

**Why this matters:** If a regulator asks "when did you last screen ABC Company, and what did you find?", the answer is in the record — not in someone's email archive.

**Escalation rule:** If a confirmed match or PEP flag is recorded, the system automatically activates Enhanced Due Diligence requirements, regardless of what was initially selected.

---

### Phase 4 & 5: Entity and Report Creation — No Duplicate Entry

**What changes:** When the officer creates a KYC report after creating the entity, the system automatically copies across the data that was already entered. The officer verifies and enriches — they do not retype.

**New mandatory fields for Enhanced KYC:**
- Source of funds — where does the counterparty's money come from?
- Source of wealth — how did they accumulate their assets?

These are required by international standards for high-risk counterparties and cannot be skipped when Enhanced KYC is selected.

**Conclusion templates in the system:**  
Standard conclusion texts are stored in the system by risk category. The officer selects the appropriate template, which appears pre-filled in the conclusion field, ready to be personalised. No more opening Word documents.

**Date validation:**  
The system will not accept:
- Future dates in any date field
- Invalid day/month combinations (no 32nd of the 13th month)
- Request dates more than 2 years in the past (flags a warning)

**SLA indicator:**  
Every report shows a traffic-light indicator: how many days have elapsed versus the target completion time for that report type.

| KYC Type | Target Completion |
|---|---|
| Simplified | 5 business days |
| Standard | 10 business days |
| Enhanced | 20 business days |

---

### Phase 6: Level 1 Approval — With Delegation

**What changes:**

1. **Delegation is pre-configured**, not ad-hoc. If the Level 1 Approver marks themselves as on leave, the system automatically routes new submissions to their designated deputy — no phone calls needed.

2. **Structured screening results** are visible to the approver in a clear format — not buried in a free-text narrative.

3. **SLA indicator** shows the approver if a report is approaching or past its target completion time.

The three approval actions remain the same: Approve / Request For Information / Reject.

For **RFI**, the approver selects a category (Missing Document / Unclear Conclusion / Insufficient Screening / Other) before entering their comment. This helps analyse why RFIs are happening and whether they can be prevented.

---

### Phase 7: Level 2 / MLRO Approval — With SAR Gate

**What is new:** Before the Level 2 Approver makes their decision, the system asks one additional question:

> *"Based on your review of this report, is there any information that may require a Suspicious Activity Report (SAR)?"*

This is a mandatory step. If the answer is yes, the approval is paused and the Head of Compliance is alerted. The SAR process runs separately. If the answer is no, the approval proceeds normally.

This gate ensures that the compliance head consciously considers their SAR obligation on every high-risk case — it cannot be overlooked.

---

### Phase 8: Completion — Automated and Monitored

**What changes:**

**On final approval:**
- The system automatically generates the completed KYC report as a PDF
- The requesting department receives an email with the report attached — no manual follow-up needed
- The record is sealed (read-only)
- A next review date is set automatically based on risk level: **12 months** for High risk, **24 months** for Medium risk, **36 months** for Low risk

**Ongoing monitoring:**
- **60 days before** a KYC is due for review: compliance officer notified
- **On the review date** (if not yet renewed): manager notified
- **SLA breaches** on open reports: flagged to manager daily

**Live KPI Dashboard — replaces "Madi, send me an export":**

The dashboard shows in real time:
- Total KYCs completed this month / quarter / year
- Average turnaround time
- SLA compliance rate
- Reports by risk level
- Reports by contributor (team productivity)
- Pending pipeline (what is in each stage right now)
- Overdue cases

---

## The Improved Approval Process

```mermaid
flowchart TD
    DEPT([Requesting Department\nStructured digital form]) --> CASE[Case Created Automatically\nSystem notification to compliance]
    CASE --> DOCVAL[Document Validation\nAll rounds tracked\nKPI clock starts when docs confirmed]
    DOCVAL --> ASSIGN[Work Assignment\nSystem auto-assigns or Manager assigns]
    ASSIGN --> RISK[Risk Pre-Assessment\nSystem flags — Officer confirms]
    RISK --> DD[Due Diligence — WorldCheck\nStructured results recorded in system]
    DD --> ENTITY[Entity Record Created\nwith duplicate check]
    ENTITY --> REPORT[KYC Report Created\nauto-populated from entity\nSLA indicator visible]
    REPORT --> SUBMIT[Submitted for Approval\nActive approver identified\ndelegation applied]
    SUBMIT --> RISKSPLIT{Risk Level?}

    RISKSPLIT -->|Low Risk| L1_LOW[L1 Approver Reviews]
    RISKSPLIT -->|Medium or High Risk| L1_HIGH[L1 Approver Reviews]

    L1_LOW -->|Approve| FINAL([✅ FINAL APPROVED\nAuto PDF generated\nRequestor notified\nReview date set])
    L1_LOW -->|RFI or Reject| OFFICER[Back to Officer]
    OFFICER --> SUBMIT

    L1_HIGH -->|Approve| L2[L2 Approver / MLRO\nSAR Gate — mandatory]
    L1_HIGH -->|RFI or Reject| OFFICER

    L2 -->|SAR = No, Approve| FINAL
    L2 -->|SAR = Yes| SAR([⚠️ SAR Process\nApproval paused\nHead of Compliance alerted])
    L2 -->|RFI or Reject| OFFICER

    style FINAL fill:#E8F5E9,color:#1B5E20,stroke:#2E7D32
    style SAR fill:#FFEBEE,color:#7F0000,stroke:#B71C1C
    style OFFICER fill:#FFF3E0,color:#BF360C,stroke:#E65100
    style DEPT fill:#E3F2FD,color:#0D47A1,stroke:#1565C0
```

---

## What Changes for Each Person

### For Requesting Departments
- Use a simple web form instead of sending emails
- Upload documents in one place
- Receive automatic confirmation and tracking
- Get notified automatically when the KYC is complete

### For Compliance Officers
- No more email triage — requests arrive in a structured queue
- Duplicate check happens automatically
- No double-entry between entity and report
- Conclusion templates are in the system
- SLA indicator keeps the workload visible
- Documents stay with the case — no more local folders

### For Approvers
- Delegation is pre-configured — no disruption when on leave
- Screening results presented clearly, not in a text wall
- SAR obligation is prompted explicitly for senior reviewers

### For Management
- Live dashboard — no data exports needed
- Overdue cases flagged automatically
- Team performance visible in real time
- Periodic review schedule enforced by system, not memory
