# Lookups - requirements (COMMON)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/common/docs/README.md`.

## Lookups

- **Purpose:** the lists of values used across applications.
- **What it does:** maintains lookup types and their values, with translations and levels.
- **Why:** lists of values are data, maintained from the console.

* **How it works:** LOVs in every application read lookup values through a view, by type, language and application.
* **How it's built:** *APEX:* interactive grid, form, shared LOVs. *Custom:* `XXFND_LOOKUP_PKG`, 2 tables, 1 view.

- **DB objects:** *Own:* Tables: XXFND\_LOOKUP\_TYPES, XXFND\_LOOKUP\_VALUES; Views: XXFND\_LOOKUP\_VALUES\_VL; Packages: XXFND\_LOOKUP\_PKG; Triggers: XXFND\_LOOKUP\_VALUES\_LVL.

* **Shared components:** App items: G\_ADMIN\_APP, G\_ADMIN\_LOCK; Authorizations: page-create, page-manage, page-submit, page-view; Breadcrumb: breadcrumb; LOVs: lov-applications, lov-lookup-types; Lists: administration; Page groups: administration.
