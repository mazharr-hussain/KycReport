# Communications - requirements (COMMON)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/common/docs/README.md`.

## Communications (e-mail)

- **Purpose:** e-mails with outside people about a record.
- **What it does:** sends an e-mail, records a received one and keeps the history of a record, with its files.
- **Why:** one e-mail history for every record, without e-mail screens in the application.

* **How it works:** the application opens the COMMON e-mail page for a record; sent and received e-mails are kept against it.
* **How it's built:** *APEX:* modal pages, `APEX_MAIL`. *Custom:* 1 table, notification package routines.

- **DB objects:** *Own:* Tables: XXFND\_COMMUNICATIONS. *Uses:* XXFND\_NOTIFY\_PKG.

* **Shared components:** Authorizations: page-manage, signed-in-user; Breadcrumb: breadcrumb; Lists: administration; Page groups: administration.
