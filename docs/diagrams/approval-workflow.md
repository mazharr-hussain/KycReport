# Approval Workflow — State Machine

The complete workflow for a KYC report from creation through to final approval.

!!! tip "How to edit this diagram"
    1. Go to [diagrams.net](https://app.diagrams.net)
    2. Open via **File → Open from → GitHub**
    3. Navigate to `docs/diagrams/drawio/approval-workflow.drawio`
    4. Edit visually and save — it commits directly to GitHub
    5. Netlify rebuilds and this page updates automatically

![Approval Workflow](drawio/approval-workflow.drawio)

!!! info "Multi-page diagram"
    This file has 3 pages — use the page selector in the diagram toolbar to switch between **State Machine**, **Routing Rules**, and **Delegation**.

---

## All Workflow States

| State | Who Can Act | Available Actions |
|---|---|---|
| `DRAFT` | Contributor (owner only) | Edit, Submit for Approval |
| `SUBMITTED / PENDING_L1` | L1 Approver | Approve, RFI, Reject |
| `RFI` | Contributor (owner only) | Edit, Resubmit |
| `APPROVED_L1` | System (auto-routes) | — |
| `PENDING_L2` | L2 / MLRO | Mandatory SAR question, then Approve, RFI, or Reject |
| `FINAL_APPROVED` | Read-only | View, Download PDF |
| `REJECTED` | Read-only | View history |

!!! note "Four-Eyes Principle"
    A contributor **cannot** approve their own submission. This is enforced at the database level — the system checks that the approver's user ID differs from the contributor's user ID before allowing any approval action.
