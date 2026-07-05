# Technical Specifications

These specifications are written for developers, database administrators, and IT architects.

| Specification | Purpose |
|---|---|
| [V1 — Current System Spec](v1-current-system-spec.md) | Tech stack, DB schema (14 tables), managed beans, known defects TD-01 to TD-10 |
| [V2 — As-Is Requirements](v2-asis-requirements.md) | Functional requirements FR-01 to FR-09, gap register GAP-01 to GAP-14 |
| [V3 — Best Practice Spec](v3-best-practice-spec.md) | System Requirements M1–M11, NFR-01 to NFR-15, 13 acceptance criteria |
| [V4 — Oracle APEX Spec](v4-apex-spec.md) | Full APEX developer spec — DDL, PL/SQL packages, VPD, workflow engine |

---

!!! warning "Security Notice"

    Technical Defect **TD-01** (plain-text password storage) and **TD-02** (SMTP credentials in config file) are documented in the V1 spec. These must be remediated before any production deployment of a replacement system.
