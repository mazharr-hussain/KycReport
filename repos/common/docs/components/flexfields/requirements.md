# Flexfields - requirements (COMMON)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/common/docs/README.md`.

## Flexfields

- **Purpose:** extra fields on a record without a database change.
- **What it does:** maintains value sets, flexfields, contexts and segments, with validation; renders and saves them on any record.
- **Why:** new attributes without new columns or new screens.

* **How it works:** the segments of a record's context are drawn on the page at run time and their values saved in reserved columns.
* **How it's built:** *APEX:* interactive grids, forms, a dynamic content region. *Custom:* `XXFND_DFF_PKG` (renders the fields: the one approved HTML exception), 4 tables, 1 view.

- **DB objects:** *Own:* Tables: XXFND\_DF\_CONTEXTS, XXFND\_DF\_FLEXFIELDS, XXFND\_DF\_SEGMENTS, XXFND\_VALUE\_SETS; Views: XXFND\_DF\_CONTEXTS\_VL; Packages: XXFND\_DFF\_PKG; Triggers: XXFND\_DF\_CONTEXTS\_PROTECT, XXFND\_DF\_FLEXFIELDS\_CHK, XXFND\_DF\_SEGMENTS\_CHK. *Uses:* XXFND\_ATTACHED\_DOCUMENTS, XXFND\_LOOKUP\_PKG, XXFND\_LOOKUP\_TYPES, XXFND\_SETUP\_COLUMNS\_V, XXFND\_SETUP\_TABLES\_V.

* **Shared components:** App items: G\_ADMIN\_APP, G\_ADMIN\_LOCK; Authorizations: page-create, page-manage, page-submit, page-view; Breadcrumb: breadcrumb; LOVs: lov-applications, lov-df-default-type, lov-lookup-types, lov-value-sets, lov-vs-format-type, lov-vs-validation-type; Lists: administration; Page groups: administration.
