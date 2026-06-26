# KYC Necessity Decision

This diagram shows the rules engine that determines whether a full KYC report is required or whether a simplified waiver record is sufficient.

!!! info "This replaces the Excel calculator used in the current process."

!!! tip "How to edit this diagram"
    1. Go to [diagrams.net](https://app.diagrams.net)
    2. Click **Extras → Edit Diagram** or open via **File → Open from → GitHub**
    3. Navigate to `docs/diagrams/drawio/kyc-necessity.drawio`
    4. Edit visually and save — it commits directly to GitHub
    5. Netlify rebuilds and this page updates automatically

![KYC Necessity Decision](drawio/kyc-necessity.drawio)

---

## Detail

```mermaid
flowchart TD
    START([Business Department\nSubmits Request]) --> Q1

    Q1{Entity Type?}
    Q1 -->|Individual| Q2_IND
    Q1 -->|Company / Legal Entity| Q2_LE

    Q2_IND{Ownership Category}
    Q2_IND -->|Qatari National Person| Q3A
    Q2_IND -->|Non-Qatari Person| Q3B

    Q2_LE{Ownership Category}
    Q2_LE -->|Fully Qatari Legal Entity| Q3C
    Q2_LE -->|Qatar Majority Owned| Q3D
    Q2_LE -->|Qatar Minority Owned| Q3E
    Q2_LE -->|Foreign / Non-Qatari Entity| Q3F

    Q3A{Financial\nInvolvement?}
    Q3A -->|Yes| REQUIRED
    Q3A -->|No| Q4A

    Q4A{Related\nParty?}
    Q4A -->|Yes| REQUIRED
    Q4A -->|No| NOT_REQUIRED

    Q3B{Any Involvement?} --> REQUIRED

    Q3C{Financial\nInvolvement?}
    Q3C -->|No| NOT_REQUIRED
    Q3C -->|Yes| Q5C

    Q5C{Related\nParty?}
    Q5C -->|No| NOT_REQUIRED
    Q5C -->|Yes| REQUIRED

    Q3D --> REQUIRED
    Q3E --> REQUIRED
    Q3F --> REQUIRED

    REQUIRED([✅ KYC REQUIRED\nCreate Case\nAssign Reference Number])
    NOT_REQUIRED([📋 KYC NOT REQUIRED\nCreate Waiver Record\nStore Documents as Evidence])

    style REQUIRED fill:#E8EAF6,color:#1A237E,stroke:#3949AB
    style NOT_REQUIRED fill:#E8F5E9,color:#1B5E20,stroke:#2E7D32
    style START fill:#E3F2FD,color:#0D47A1,stroke:#1565C0
```

---

## Ownership Categories

| Category | Code | Description |
|---|---|---|
| Fully Qatari Legal Entity | QLE-FULL | 100% Qatari-owned company |
| Qatar Majority Owned | QLE-MAJ | >50% Qatari ownership |
| Qatar Minority Owned | QLE-MIN | <50% Qatari ownership |
| Foreign / Non-Qatari Entity | FOREIGN | No Qatari ownership |
| Qatari National Person | QNP | Individual with Qatari nationality |
| Non-Qatari Person | NQP | Individual without Qatari nationality |

---

## Outcome Actions

=== "KYC Required"

    1. System creates a case with a unique reference number (`INTAKE-YYYY-NNNNNN`)
    2. Business department proceeds to document upload
    3. Case enters the compliance queue automatically
    4. Compliance officer is notified

=== "KYC Not Required"

    1. System creates a **waiver record** — not just a dismissal
    2. All submitted documents are attached to the waiver record as evidence
    3. Business department receives a confirmation with the waiver reference
    4. Record is retained for audit purposes (5-year minimum)

!!! warning "Important"
    Even when KYC is **not required**, a permanent evidence record is created. This satisfies the regulatory obligation to show that the determination was made consciously and documented.
