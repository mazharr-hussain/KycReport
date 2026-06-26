# Best Practice — End-to-End Process

The complete redesigned KYC process across all 8 phases, aligned to FATF 40 Recommendations, Basel KYC Guidelines, and EU 6AMLD.

---

## High-Level Process Map

```mermaid
flowchart TD
    P0([Phase 0\nStructured Digital Intake]) --> P1
    P1([Phase 1\nDocument Validation]) --> P2
    P2([Phase 2\nRisk Pre-Assessment]) --> P3
    P3([Phase 3\nDue Diligence Research]) --> P4
    P4([Phase 4\nEntity Record Creation]) --> P5
    P5([Phase 5\nKYC Report Creation]) --> P6
    P6([Phase 6\nLevel 1 Approval]) --> P7_BRANCH

    P7_BRANCH{Risk Level?}
    P7_BRANCH -->|Low Risk| FINAL
    P7_BRANCH -->|Medium / High Risk| P7

    P7([Phase 7\nLevel 2 / MLRO Approval\nSAR Gate]) --> FINAL

    FINAL([Phase 8\nCompletion\nPDF + Notification + Review Date])

    style P0 fill:#1565C0,color:#fff
    style P1 fill:#1565C0,color:#fff
    style P2 fill:#6A1B9A,color:#fff
    style P3 fill:#6A1B9A,color:#fff
    style P4 fill:#BF360C,color:#fff
    style P5 fill:#BF360C,color:#fff
    style P6 fill:#2E7D32,color:#fff
    style P7 fill:#2E7D32,color:#fff
    style FINAL fill:#37474F,color:#fff
```

---

## Phase Detail

### Phase 0 — Structured Digital Intake

```mermaid
flowchart LR
    DEPT([Business Dept]) -->|Structured form| PORTAL[KYC Portal]
    PORTAL -->|Auto-fill| FUSION[(Oracle Fusion\nHCM)]
    PORTAL --> RULES{Rules Engine}
    RULES -->|Not Required| WAIVER[Waiver Record\n+ Evidence]
    RULES -->|Required| CASE[Case Created\nINTAKE-YYYY-NNNNNN]

    style WAIVER fill:#2E7D32,color:#fff
    style CASE fill:#1565C0,color:#fff
```

### Phase 1 — Document Validation

```mermaid
flowchart LR
    CASE([New Case]) --> CO[Compliance Officer\nReviews Checklist]
    CO -->|Missing docs| RFQ[Structured Document\nRequest + Deadline]
    RFQ -->|Uploaded via portal| CO
    CO -->|All complete| KPI[KPI Clock Starts\ndocs_complete_date]
    KPI --> DUP[Duplicate Check\nJaro-Winkler]

    style KPI fill:#6A1B9A,color:#fff
```

### Phase 2 — Risk Pre-Assessment

```mermaid
flowchart LR
    DUP([Entity\nVerified]) --> SYS[System Computes\nRisk Signals]
    SYS --> GEO[Geographic Risk\nFATF country tier]
    SYS --> TYPE[Entity Type Risk\nState-owned = PEP-linked]
    SYS --> STRUCT[Structure Risk\nOwnership layers]
    SYS --> HIST[Historical Flags\nPrior adverse findings]
    GEO & TYPE & STRUCT & HIST --> SUGGEST[System Suggests\nLOW / MEDIUM / HIGH]
    SUGGEST --> CO{Officer\nAgrees?}
    CO -->|Yes| PROCEED[Confirm Risk Level]
    CO -->|No| OVERRIDE[Override + Document Why]
    PROCEED & OVERRIDE --> NEXT([Phase 3])
```

### Phase 3 — Due Diligence Research

```mermaid
flowchart LR
    NEXT([Risk Confirmed]) --> SCREEN[Manual Screening\nWorldCheck / Equivalent]
    SCREEN --> RECORD[Record Structured Results\nper Entity + per UBO]
    RECORD --> FIELDS[screening_date\nscreening_source\nmatch_status\nis_pep\nadverse_media\nfindings_narrative\nresolution_note]
    FIELDS --> ESCALATE{Confirmed Match\nor PEP?}
    ESCALATE -->|Yes| EDD[Auto-escalate to\nEnhanced Due Diligence]
    ESCALATE -->|No| CONTINUE([Phase 4])
    EDD --> CONTINUE

    style EDD fill:#B71C1C,color:#fff
```

### Phases 4 & 5 — Entity & Report Creation

```mermaid
flowchart LR
    SCREEN_DONE([Screening Complete]) --> ENTITY[Create Entity Record\nData auto-populated\nfrom intake form]
    ENTITY --> UBO[Add UBOs &\nAuthorised Signatories]
    UBO --> REPORT[Create KYC Report\nAuto-populated from entity]
    REPORT --> TYPE{KYC Type}
    TYPE -->|Simplified| SIMPLE[Standard fields]
    TYPE -->|Enhanced| EDD_FIELDS[+ Source of Funds\n+ Source of Wealth\nMandatory]
    SIMPLE & EDD_FIELDS --> TEMPLATE[Select Conclusion Template\nfrom system dropdown]
    TEMPLATE --> SLA[SLA Indicator Shows\nDays elapsed vs target]
    SLA --> SUBMIT([Submit for Approval])
```

### Phase 6 & 7 — Approval

```mermaid
flowchart TD
    SUBMIT([Submitted]) --> DELEGATE[System finds\nActive Approver\nwith delegation]
    DELEGATE --> L1[L1 Review]

    L1 -->|Approve| RISK_CHECK{Risk Level?}
    L1 -->|RFI| OFFICER[Back to Officer]
    L1 -->|Reject| REJECT([Rejected])

    RISK_CHECK -->|Low| FINAL([Final Approved])
    RISK_CHECK -->|Medium/High| L2

    L2[L2 / MLRO Review] --> SAR_Q{SAR Gate\nMandatory}
    SAR_Q -->|No SAR| L2_APPROVE[Approve]
    SAR_Q -->|SAR Required| SAR_PROC([SAR Process\nApproval Paused])
    SAR_Q -->|RFI| OFFICER
    SAR_Q -->|Reject| REJECT

    L2_APPROVE --> FINAL

    style FINAL fill:#2E7D32,color:#fff
    style REJECT fill:#B71C1C,color:#fff
    style SAR_PROC fill:#B71C1C,color:#fff
    style OFFICER fill:#BF360C,color:#fff
```

### Phase 8 — Completion & Ongoing Monitoring

```mermaid
flowchart LR
    FINAL([Final Approved]) --> PDF[Auto-generate PDF]
    PDF --> NOTIFY[Email Requestor\nwith report attached]
    NOTIFY --> SEAL[Seal Record\nRead-only]
    SEAL --> REVIEW_DATE[Set Next Review Date\nbased on risk level]

    REVIEW_DATE --> MONITOR[Ongoing Monitoring\nScheduled Alerts]
    MONITOR --> D60[60 days before review:\nNotify Compliance Officer]
    MONITOR --> D0[On review date:\nNotify Manager if not renewed]
    MONITOR --> SLA_BREACH[Daily:\nFlag SLA breaches to Manager]

    style FINAL fill:#2E7D32,color:#fff
    style SEAL fill:#6A1B9A,color:#fff
```

---

## What Changes for Each Person

| Role | Before | After |
|---|---|---|
| **Requesting Dept** | Email in any format, no tracking | Structured web form, automatic confirmation, live tracking |
| **Compliance Officer** | Email triage, local folders, copy-paste | Structured queue, no re-typing, SLA visible, documents in system |
| **L1 Approver** | Ad-hoc delegation calls | Pre-configured deputy, clear screening results, delegation automatic |
| **L2 / MLRO** | Same as L1 | Plus mandatory SAR gate — cannot be skipped |
| **Management** | Excel data exports on request | Live dashboard, overdue cases flagged automatically |
