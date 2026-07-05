# KYC Management System — As-Is / To-Be Business Review

**Organisation:** Qatari Diar Real Estate Investment Company
**System:** Know Your Customer (KYC) Management System
**Scope of this site:** Business documentation only — As-Is (V2) and To-Be (V3) processes
**Last Updated:** July 2026

---

## What Is This Documentation?

This site is a **business-only working set**, scoped deliberately to two documents:

- **V2 — As-Is Process**: how the KYC process works today, step by step, including every known pain point
- **V3 — Best Practice Process**: the target To-Be process, aligned to FATF, Basel, and EU 6AMLD standards

No technical specifications, developer documentation, or platform-specific content (Oracle APEX, database schemas, etc.) is included here. The purpose is to get the As-Is and To-Be **business process** confirmed and signed off first — technical/development documentation for the target system is tracked separately and will be brought in once this business review is complete.

=== "Business & Management"

    👉 [V2 — How the process works today](business/v2-asis-process.md)
    👉 [V3 — How the process should work](business/v3-best-practice.md)

---

## Document Map

| Version | Business Guide | Status |
|---|---|---|
| **V2** — As-Is Process | [Process Guide](business/v2-asis-process.md) | For review |
| **V3** — Best Practice | [Best Practice Guide](business/v3-best-practice.md) | For review |

---

## Regulatory Standards Applied (V3)

!!! info "Standards Referenced"

    - **FATF 40 Recommendations** (2023 update) — Financial Action Task Force
    - **Basel Committee KYC Guidelines** — Sound Practices for Managing Risks
    - **EU 6AMLD** — Sixth Anti-Money Laundering Directive (referenced as a best-practice benchmark, not a binding obligation)
    - **ISO 31000** — Risk Management Principles and Guidelines

---

## Process Diagrams

All process flows are draw.io diagrams — one source per flow, editable visually, rendering automatically wherever referenced. See the [Process Diagrams overview](diagrams/index.md) for the full name/purpose/usage map.

- [As-Is Process (Current)](diagrams/asis-process.md)
- [Intake & Document Validation Flow](diagrams/intake-flow.md)
- [Approval Workflow State Machine](diagrams/approval-workflow.md)
- [Best Practice End-to-End Process](diagrams/best-practice-e2e.md)
