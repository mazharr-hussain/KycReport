# Best Practice — End-to-End Process

The complete redesigned KYC process across all 8 phases, aligned to FATF 40 Recommendations, Basel KYC Guidelines, and EU 6AMLD.

!!! tip "How to edit this diagram"
    1. Go to [diagrams.net](https://app.diagrams.net)
    2. Open via **File → Open from → GitHub**
    3. Navigate to `docs/diagrams/drawio/best-practice-e2e.drawio`
    4. Edit visually and save — it commits directly to GitHub
    5. Netlify rebuilds and this page updates automatically

![Best Practice End-to-End Process](drawio/best-practice-e2e.drawio)

!!! info "Multi-page diagram"
    This file has 9 pages — page 1 is the high-level process map; pages 2–8 are per-phase detail (Phase 0, Phase 1, Phase 2, Phase 3, Phases 4–5, Phases 6–7, Phase 8); page 9 is the Phase 2 risk indicator panel detail (referenced separately from [V3 Best Practice](../V3_BUS_BestPractice.md)). Use the page selector in the diagram toolbar to switch between them.

---

## What Changes for Each Person

| Role | Before | After |
|---|---|---|
| **Requesting Dept** | Email in any format, no tracking | Structured web form, automatic confirmation, live tracking |
| **Compliance Officer** | Email triage, local folders, copy-paste | Structured queue, no re-typing, SLA visible, documents in system |
| **L1 Approver** | Ad-hoc delegation calls | Pre-configured deputy, clear screening results, delegation automatic |
| **L2 / MLRO** | Same as L1 | Plus mandatory SAR gate — cannot be skipped |
| **Management** | Excel data exports on request | Live dashboard, overdue cases flagged automatically |
