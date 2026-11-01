# Audit Log - requirements (COMMON)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/common/docs/README.md`.

## Audit log

- **Purpose:** who changed what and when.
- **What it does:** shows the change history of audited tables.
- **Why:** one audit trail for every application.

* **How it works:** triggers on audited tables write each change (who, when, old and new value).
* **How it's built:** *APEX:* interactive report. *Custom:* `XXFND_AUDIT_PKG`, generated audit triggers, 1 table.

- **DB objects:** *Own:* Tables: XXFND\_AUDIT\_LOG; Packages: XXFND\_AUDIT\_PKG.

* **Shared components:** Authorizations: page-view; Breadcrumb: breadcrumb; Lists: administration; Page groups: administration.
