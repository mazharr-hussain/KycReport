# Oracle APEX System Architecture

!!! warning "Version Scope — V4"
    This architecture diagram covers **Version 4 — Oracle APEX 23.2 on Oracle Database 19c/21c with Oracle IDCS SSO**.
    V5 (APEX 24 on ATP 23ai, OCI IAM) and V6 (APEX 26 AI) introduce different infrastructure components.
    See `V5_TECH_APEX24_Spec.md` and `V6_TECH_APEX26AI_Spec.md` for updated architecture details.

The technical architecture of the V4 KYC system built on Oracle APEX 23.2 with Oracle Fusion HCM integration.

!!! tip "How to edit this diagram"
    1. Go to [diagrams.net](https://app.diagrams.net)
    2. Open via **File → Open from → GitHub**
    3. Navigate to `docs/diagrams/drawio/apex-architecture.drawio`
    4. Edit visually and save — it commits directly to GitHub
    5. Netlify rebuilds and this page updates automatically

![APEX System Architecture](drawio/apex-architecture.drawio)

!!! info "Multi-page diagram"
    This file has 4 pages — **Architecture Overview**, **Authentication Flow**, **Nightly Sync Process**, and **Security Model (VPD)**. Use the page selector in the diagram toolbar to switch between them.

---

## Application Page Structure

| Page Group | Page Numbers | Audience |
|---|---|---|
| Public / Auth | 101 (Login), 9999 (Error) | All |
| Requestor Portal | 70–79 | Requestors |
| Compliance Worklist | 1–19 | Contributors |
| Entity Management | 20–29 | Contributors |
| KYC Report | 10–19 | Contributors |
| L1 Approval Queue | 30–39 | Approvers L1 |
| L2 Approval Queue | 40–49 | Approvers L2 |
| Administration | 80–89 | Administrators |
| Executive Dashboard | 90–99 | Admins + Management |

---

## Technology Stack

| Layer | Technology | Version |
|---|---|---|
| Application | Oracle APEX | 23.2+ |
| Database | Oracle Database | 19c / 21c |
| Authentication | Oracle IDCS SSO | — |
| User Source | Oracle Fusion HCM Cloud | REST API v4 |
| Email | APEX_MAIL (SMTP) | — |
| Fuzzy Matching | UTL_MATCH.JARO_WINKLER_SIMILARITY | Built-in |
| Row Security | DBMS_RLS (VPD) | Built-in |
| Scheduling | DBMS_SCHEDULER | Built-in |
| Workflow | APEX_WORKFLOW | APEX 23.2+ |
