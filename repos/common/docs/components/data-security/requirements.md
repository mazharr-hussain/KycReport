# Data Security - requirements (COMMON)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/common/docs/README.md`.

## Data security

- **Purpose:** which rows each user and role can see.
- **What it does:** data access rules by table, column and allowed values (data objects, dimensions, organizations), assigned to roles and users, with per-user overrides.
- **Why:** row-level security (VPD) for every application from one set of rules.

* **How it works:** database policies add each user's allowed values to every query on a protected table.
* **How it's built:** *Oracle:* Virtual Private Database (`DBMS_RLS`). *APEX:* reports and forms. *Custom:* `XXFND_VPD_PKG`, 2 tables.

- **DB objects:** *Own:* Tables: XXFND\_DATA\_RULE\_ASSIGNMENTS, XXFND\_DATA\_SECURITY\_RULES; Packages: XXFND\_VPD\_PKG; Triggers: XXFND\_DATA\_RULES\_ASSIGN. *Uses:* XXFND\_APPLICATIONS, XXFND\_ASSIGNMENT\_VALUES, XXFND\_DATA\_DIMENSIONS, XXFND\_DATA\_OBJECTS, XXFND\_PRIVILEGE\_PKG, XXFND\_ROLES, XXFND\_ROLE\_DATA\_ACCESS, XXFND\_SETUP\_COLUMNS\_V, XXFND\_USER\_ROLES\_V, XXHR\_ORGANIZATIONS.

* **Shared components:** App items: G\_ADMIN\_APP; Authorizations: page-submit, page-view; Breadcrumb: breadcrumb; Lists: administration; Page groups: administration.

## Data visibility rule

- **Setup data** (lookups, flexfields, categories, approval rules, templates, roles, menu entries): each application sees its own rows plus COMMON's shared rows; IT sees all.
- **Transaction data** (tasks, notifications, documents, information requests, e-mails): each user sees what they are allowed to, from every application.
