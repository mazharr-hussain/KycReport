# Process Diagrams

All KYC process flows are maintained as **draw.io files** — one authoritative source per flow, editable visually at [diagrams.net](https://app.diagrams.net), rendering automatically everywhere it's referenced. This site is scoped to As-Is (V2) and To-Be (V3) diagrams only.

!!! tip "How to edit any diagram"
    1. Go to [diagrams.net](https://app.diagrams.net)
    2. Open via **File → Open from → GitHub**
    3. Navigate to the `.drawio` file listed below (all live under `docs/diagrams/drawio/`)
    4. Edit visually and save — it commits directly to GitHub
    5. The docs workflow rebuilds the site and every page referencing that file updates automatically

!!! warning "Editing pages inside a multi-page file"
    Several files below have more than one page (visible via the page selector in the diagram toolbar). Pages are matched into documents **by exact name** — if you rename a page in diagrams.net, update the "Used In" links for that page too, or the embed will silently fall back to page 1 instead of erroring. If you only redraw shapes/arrows inside a page without renaming it, nothing else needs to change.

---

## File Index

| File | Pages | Diagram Set |
|---|---|---|
| [`intake-flow.drawio`](drawio/intake-flow.drawio) | 1 | Intake & Document Validation (To-Be) |
| [`approval-workflow.drawio`](drawio/approval-workflow.drawio) | 3 | Approval Workflow (To-Be) |
| [`best-practice-e2e.drawio`](drawio/best-practice-e2e.drawio) | 9 | Best Practice End-to-End (To-Be) |
| [`asis-process.drawio`](drawio/asis-process.drawio) | 8 | As-Is Process (Current) |

---

## Page-Level Map — Name, Purpose, Used In

### `intake-flow.drawio`

| Page Name | Purpose | Used In |
|---|---|---|
| Intake and Document Validation | Phase 0–1 To-Be: structured portal intake through document validation | [Diagram page](intake-flow.md) · [V3 Best Practice — Phase 0](../V3_BUS_BestPractice.md) |

### `approval-workflow.drawio`

| Page Name | Purpose | Used In |
|---|---|---|
| Approval Workflow State Machine | Full To-Be state machine, DRAFT through FINAL_APPROVED, corrected SAR handling | [Diagram page](approval-workflow.md) · [V3 Best Practice — Improved Approval Process](../V3_BUS_BestPractice.md) |
| Routing Rules | Risk-level → approver routing (Low/Medium/High → L1/L2) | [Diagram page](approval-workflow.md) *(toolbar only)* |
| Delegation | Deputy/leave resolution logic for active approver | [Diagram page](approval-workflow.md) *(toolbar only)* |

### `best-practice-e2e.drawio`

| Page Name | Purpose | Used In |
|---|---|---|
| Best Practice End-to-End Process | High-level 8-phase To-Be process map | [Diagram page](best-practice-e2e.md) · [V3 Best Practice — One Page overview](../V3_BUS_BestPractice.md) |
| Phase 0 Detail | Structured digital intake detail | [Diagram page](best-practice-e2e.md) *(toolbar only)* |
| Phase 1 Detail | Document validation detail | [Diagram page](best-practice-e2e.md) *(toolbar only)* |
| Phase 2 Detail | Risk pre-assessment detail | [Diagram page](best-practice-e2e.md) *(toolbar only)* |
| Phase 3 Detail | Due diligence research detail | [Diagram page](best-practice-e2e.md) *(toolbar only)* |
| Phase 4-5 Detail | Entity & report creation detail | [Diagram page](best-practice-e2e.md) *(toolbar only)* |
| Phase 6-7 Detail | L1/L2 approval detail | [Diagram page](best-practice-e2e.md) *(toolbar only)* |
| Phase 8 Detail | Completion & ongoing monitoring detail | [Diagram page](best-practice-e2e.md) *(toolbar only)* |
| Phase 2 Risk Panel | Risk indicator panel — system signals, officer confirm/override | [V3 Best Practice — Phase 2](../V3_BUS_BestPractice.md) |

### `asis-process.drawio`

| Page Name | Purpose | Used In |
|---|---|---|
| System Boundary | What's inside vs outside the KYC Report Application | [Diagram page](asis-process.md) · [V2 As-Is — Overview](../V2_BUS_AsIs_Process.md) |
| Complete As-Is Process | One-page overview, all 8 current-state phases | [V2 As-Is — One Page overview](../V2_BUS_AsIs_Process.md) |
| Phase 0 Decision | Excel Risk Calculator decision tree | [V2 As-Is — Phase 0](../V2_BUS_AsIs_Process.md) |
| Phase 1 Doc Validation | Email-based document collection (current) | [V2 As-Is — Phase 1](../V2_BUS_AsIs_Process.md) |
| Phase 3 WorldCheck | Manual due diligence screening (current) | [V2 As-Is — Phase 3](../V2_BUS_AsIs_Process.md) |
| Phase 5 Report Creation | Manual report drafting in-system (current) | [V2 As-Is — Phase 5](../V2_BUS_AsIs_Process.md) |
| Phase 6 L1 Approval | Level 1 approval, current process | [V2 As-Is — Phase 6](../V2_BUS_AsIs_Process.md) |
| Phase 7 L2 Approval | Level 2 approval, current process | [V2 As-Is — Phase 7](../V2_BUS_AsIs_Process.md) |

---

## Removed From This Scope

This is a business-only, As-Is/To-Be branch. The following were removed (they still exist on `main`):

- V1, V4, V5, V6 business guides and all technical specifications
- `apex-architecture.drawio` (V4-specific architecture) and `kyc-necessity.drawio` (was only referenced from removed V1/other pages — not used by V2/V3)
- The "V1 Approval Workflow (Legacy)" page that lived in `asis-process.drawio`, since it was only referenced by the now-removed V1 document
- `index.md`'s Mermaid version-history timeline — was documentation roadmap, not a process flow, and referenced removed versions
