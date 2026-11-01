# Roles Privileges - requirements (COMMON)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/common/docs/README.md`.

## Roles and privileges

- **Purpose:** roles, the privileges they grant, and segregation of duties.
- **What it does:** roles within roles; privileges per feature (View / Create / Manage); SoD rules. Every page is mapped to a feature and opened with the privilege on it. Self-service pages (My Tasks, Notifications and similar) are open to any signed-in user, who sees only their own data.
- **Why:** page access is data-driven, and SoD is enforced once for all applications.

* **How it works:** each page belongs to a feature; a role grants View, Create or Manage on features; the page's authorization checks the privilege; SoD rules block conflicting roles.
* **How it's built:** *APEX:* authorization schemes (page-view / page-create / page-manage), forms, reports. *Custom:* `XXFND_PRIVILEGE_PKG`, 6 tables, 1 view.

- **DB objects:** *Own:* Tables: XXFND\_FEATURES, XXFND\_FEATURE\_PAGES, XXFND\_PRIVILEGES, XXFND\_ROLES, XXFND\_ROLE\_PRIVILEGES, XXFND\_SOD\_RULES; Views: XXFND\_EFFECTIVE\_ACCESS\_V; Packages: XXFND\_PRIVILEGE\_PKG; Triggers: XXFND\_ROLES\_EVERY\_ROLE, XXFND\_SOD\_RULES\_ORDER. *Uses:* XXFND\_APPLICATIONS, XXFND\_DATA\_DIMENSIONS, XXFND\_DATA\_OBJECTS, XXFND\_LOOKUP\_PKG, XXFND\_ROLE\_DATA\_ACCESS, XXFND\_ROLE\_MEMBERS, XXFND\_USER\_PKG, XXFND\_USER\_ROLES\_V, XXFND\_VPD\_PKG.

* **Shared components:** App items: G\_ADMIN\_APP, G\_ADMIN\_LOCK; Authorizations: page-create, page-manage, page-submit, page-view; Breadcrumb: breadcrumb; LOVs: lov-applications, lov-privileges, lov-roles, lov-sod-scope; Lists: administration; Page groups: administration.
