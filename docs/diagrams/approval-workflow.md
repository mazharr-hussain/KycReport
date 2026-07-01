# Approval Workflow — State Machine

The complete workflow for a KYC report from creation through to final approval.

!!! tip "How to edit this diagram"
    1. Go to [diagrams.net](https://app.diagrams.net)
    2. Open via **File → Open from → GitHub**
    3. Navigate to `docs/diagrams/drawio/approval-workflow.drawio`
    4. Edit visually and save — it commits directly to GitHub
    5. Netlify rebuilds and this page updates automatically

![Approval Workflow](drawio/approval-workflow.drawio)


---

> **Note:** The image above (draw.io) is the single source of truth for this diagram — edit it visually, not the Mermaid below. The Mermaid sections that follow are a supplementary text-based detail view (per-phase breakdowns, state tables) kept for readability and diffability in pull requests; they are not independently editable diagrams and should be updated to match the draw.io file if it changes structurally.

---

## State Machine

```mermaid
stateDiagram-v2
    [*] --> DRAFT : Compliance officer\ncreates report

    DRAFT --> SUBMITTED : Officer submits\nfor approval

    SUBMITTED --> PENDING_L1 : System routes to\nactive L1 Approver\n(delegation applied)

    PENDING_L1 --> APPROVED_L1 : L1 Approves
    PENDING_L1 --> REJECTED : L1 Rejects\n(reason mandatory)
    PENDING_L1 --> RFI : L1 requests\nmore information

    RFI --> SUBMITTED : Officer responds\nand resubmits

    APPROVED_L1 --> FINAL_APPROVED : Low-risk report\n(L1 approval is final)
    APPROVED_L1 --> PENDING_L2 : Medium or High-risk\nroutes to L2 / MLRO

    PENDING_L2 --> PENDING_L2 : SAR question answered\n(mandatory before any action)

    PENDING_L2 --> FINAL_APPROVED : SAR = No\nL2 Approves
    PENDING_L2 --> SAR_PROCESS : SAR = Yes\nApproval paused
    PENDING_L2 --> REJECTED : L2 Rejects
    PENDING_L2 --> RFI : L2 requests\nmore information

    SAR_PROCESS --> [*] : SAR process\nruns separately

    FINAL_APPROVED --> [*] : PDF generated\nRequestor notified\nReview date set\nRecord sealed

    REJECTED --> [*] : Contributor &\nRequestor notified

    note right of RFI
        RFI Categories:
        - Missing Document
        - Unclear Conclusion
        - Insufficient Screening
        - Other
    end note

    note right of PENDING_L2
        Mandatory SAR question before any action:
        "Does any information warrant
        a Suspicious Activity Report?"
    end note
```

---

## Routing Rules

```mermaid
flowchart LR
    SUBMIT([Report Submitted]) --> RISK{Risk Level}

    RISK -->|Low| L1_LOW[L1 Approver]
    RISK -->|Medium| L1_MED[L1 Approver]
    RISK -->|High| L1_HIGH[L1 Approver]

    L1_LOW -->|Approve| FINAL_LOW([Final Approved])
    L1_LOW -->|RFI or Reject| OFFICER[Back to Officer]

    L1_MED -->|Approve| L2_MED[L2 / MLRO]
    L1_MED -->|RFI or Reject| OFFICER

    L1_HIGH -->|Approve| L2_HIGH[L2 / MLRO]
    L1_HIGH -->|RFI or Reject| OFFICER

    L2_MED --> SAR{SAR Gate}
    L2_HIGH --> SAR

    SAR -->|No SAR + Approve| FINAL([Final Approved])
    SAR -->|SAR Identified| SAR_PROC([SAR Process])
    SAR -->|RFI or Reject| OFFICER

    style FINAL_LOW fill:#E8F5E9,color:#1B5E20,stroke:#2E7D32
    style FINAL fill:#E8F5E9,color:#1B5E20,stroke:#2E7D32
    style SAR_PROC fill:#FFEBEE,color:#7F0000,stroke:#B71C1C
    style OFFICER fill:#FFF3E0,color:#BF360C,stroke:#E65100
```

---

## Delegation — Active Approver Resolution

```mermaid
flowchart TD
    SUBMIT([Report Ready for L1 Approval]) --> CHECK

    CHECK{Is Primary\nL1 Approver\nOn Leave?}

    CHECK -->|No — Available| PRIMARY[Route to\nPrimary L1 Approver]
    CHECK -->|Yes — On Leave| DEPUTY{Is Deputy\nConfigured?}

    DEPUTY -->|Yes| ROUTE_DEPUTY[Route to\nDesignated Deputy]
    DEPUTY -->|No| ALERT[Alert Administrator\nNo deputy configured]

    PRIMARY --> QUEUE[Appears in\nApprover's Queue]
    ROUTE_DEPUTY --> QUEUE
    ALERT --> MANUAL[Manual Assignment\nRequired]

    style PRIMARY fill:#E8EAF6,color:#1A237E,stroke:#3949AB
    style ROUTE_DEPUTY fill:#F3E5F5,color:#4A148C,stroke:#6A1B9A
    style ALERT fill:#FFEBEE,color:#7F0000,stroke:#B71C1C
```

---

## All Workflow States

| State | Who Can Act | Available Actions |
|---|---|---|
| `DRAFT` | Contributor (owner only) | Edit, Submit for Approval |
| `SUBMITTED / PENDING_L1` | L1 Approver | Approve, RFI, Reject |
| `RFI` | Contributor (owner only) | Edit, Resubmit |
| `APPROVED_L1` | System (auto-routes) | — |
| `PENDING_L2` | L2 / MLRO | SAR Gate → Approve, RFI, Reject |
| `FINAL_APPROVED` | Read-only | View, Download PDF |
| `REJECTED` | Read-only | View history |

!!! note "Four-Eyes Principle"
    A contributor **cannot** approve their own submission. This is enforced at the database level — the system checks that the approver's user ID differs from the contributor's user ID before allowing any approval action.
