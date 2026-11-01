# Documents - requirements (COMMON)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/common/docs/README.md`.

## Documents

- **Purpose:** the documents of a record of any application.
- **What it does:** adds, views and replaces a record's documents, with versions, opened from the application with the record's entity and key.
- **Why:** applications need no document screens of their own.

* **How it works:** the application opens the COMMON page with the record's entity and key; COMMON checks the record's rules and shows its documents.
* **How it's built:** *APEX:* modal dialog pages, reports, file upload. *Custom:* uses `XXFND_ATTACH_PKG`.

- **DB objects:** *Own:* none. *Uses:* XXFND\_ATTACHED\_DOCUMENTS\_V, XXFND\_ATTACH\_PKG, XXFND\_DOCUMENT\_CATEGORIES\_VL.

* **Shared components:** Authorizations: page-manage, signed-in-user; Breadcrumb: breadcrumb; Lists: administration; Page groups: administration.
