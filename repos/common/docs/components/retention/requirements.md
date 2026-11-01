# Retention - requirements (COMMON)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/common/docs/README.md`.

## Retention

- **Purpose:** how long records and documents are kept.
- **What it does:** a placeholder for now; retention policies (review stage, then archive or delete, with reminders) come later.
- **Why:** one retention rule set for every application.

* **How it works:** not active yet; the screen shows a message and the package changes nothing.
* **How it's built:** *APEX:* form pages. *Custom:* `XXFND_RETENTION_PKG` (stub), 1 table.

- **DB objects:** *Own:* Tables: XXFND\_RETENTION\_POLICIES; Packages: XXFND\_RETENTION\_PKG. *Uses:* XXFND\_SETUP\_TABLES\_V.

* **Shared components:** App items: G\_ADMIN\_APP, G\_ADMIN\_LOCK; Authorizations: page-create, page-manage, page-submit, page-view; Breadcrumb: breadcrumb; LOVs: lov-applications, lov-jurisdiction, lov-retention-action; Lists: administration; Page groups: administration.
