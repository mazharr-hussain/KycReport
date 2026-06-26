# Process Diagrams

All key process flows for the QD KYC Management System.

!!! info "Diagram Formats"

    - **Mermaid diagrams** on this site are interactive — hover to highlight paths
    - **draw.io source files** are in `docs/diagrams/drawio/` — open with [diagrams.net](https://app.diagrams.net) or the VS Code draw.io extension for full editing

| Diagram | Description |
|---|---|
| [KYC Necessity Decision](kyc-necessity.md) | Rules engine — when is a full KYC required vs. a waiver? |
| [Intake & Document Validation](intake-flow.md) | Phase 0–1: from request submission to compliance queue |
| [Approval Workflow](approval-workflow.md) | Full state machine — DRAFT through FINAL_APPROVED |
| [Best Practice End-to-End](best-practice-e2e.md) | All 8 phases of the redesigned process |
| [APEX System Architecture](apex-architecture.md) | Oracle APEX + Fusion HCM + Oracle DB architecture |
