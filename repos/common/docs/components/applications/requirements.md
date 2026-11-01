# Applications - requirements (COMMON)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/common/docs/README.md`.

## Applications

- **Purpose:** one register of every application that uses COMMON.
- **What it does:** IT registers (onboards) each application; defines setup types and levels; shows which applications use COMMON masters; follows the application journey.
- **Why:** COMMON knows each application, its APEX ID and schema, and scopes security, setup and workflow by it.

* **How it works:** onboarding records the application (APEX ID, alias, schema), grants it COMMON objects and switches on the COMMON functions it uses; everything else is scoped by that record.
* **How it's built:** *APEX:* interactive and classic reports, forms, a list, the APEX dictionary (`APEX_APPLICATION_PAGES`). *Custom:* `XXFND_APPLICATION_PKG`, 5 tables, 5 views, onboarding script.

- **DB objects:** *Own:* Tables: XXFND\_APPLICATIONS, XXFND\_APPLICATION\_FUNCTIONS, XXFND\_SETUP\_TYPES, XXFND\_SETUP\_TYPE\_APPS, XXFND\_WORKFLOW\_PROCESSES; Views: XXFND\_ADMIN\_MENU\_V, XXFND\_MODULES\_V, XXFND\_SETUP\_COLUMNS\_V, XXFND\_SETUP\_ROWS\_V, XXFND\_SETUP\_TABLES\_V; Packages: XXFND\_APPLICATION\_PKG; Sequences: XXFND\_APPLICATIONS\_S; Triggers: XXFND\_APPLICATIONS\_ID. *Uses:* XXFND\_FEATURES, XXFND\_PRIVILEGE\_PKG, XXFND\_USERS, XXFND\_WORKFLOW\_PKG.

* **Shared components:** Authorizations: page-create, page-manage, page-submit, page-view; Breadcrumb: breadcrumb; Lists: administration, application-journey; Page groups: administration.
