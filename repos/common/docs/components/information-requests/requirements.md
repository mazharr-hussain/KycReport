# Information Requests - requirements (COMMON)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/common/docs/README.md`.

## Information requests (RFI)

- **Purpose:** ask a colleague or an outside person for information on a record.
- **What it does:** the application raises the request; a colleague answers from My Tasks, an outside person on a public page through a one-time link; the raiser reviews the answer.
- **Why:** one RFI process, with e-mail and an answer page, for every application.

* **How it works:** the RFI workflow sends the question, waits for the answer (task or public page), then has the raiser review it, looping until resolved.
* **How it's built:** *APEX:* Workflow RFI, task definitions RFI\_RESPONSE and RFI\_REVIEW, public page with a one-time token. *Custom:* `XXFND_RFI_PKG`, 2 tables, 1 view.

- **DB objects:** *Own:* Tables: XXFND\_RFIS, XXFND\_RFI\_ROUNDS; Views: XXFND\_QA\_HISTORY\_V; Packages: XXFND\_RFI\_PKG; Types: XXFND\_QA\_ROW, XXFND\_QA\_TAB; Triggers: XXFND\_RFIS\_BI.

* **Shared components:** Lists: administration; Page groups: administration; Task definitions: RFI\_RESPONSE, RFI\_REVIEW; Workflows: RFI.

## Change - Menu group page, RFI lookups (COMMON 111)

- Clicking a menu group opens its group page (page 100): the group's entries the user may open, as cards. The breadcrumb's group level opens the same page. Works for every application's menu.
- `RFI_STATUS`, `RFI_RECIPIENT_TYPE` and `RFI_CATEGORY` are shared COMMON lookups.
- The `KYC_USER` scheme is retired; every application uses `APP_USER` (KYC must switch: COMMON-ISSUES C18).
- Fix: the release 109 install of `XXFND_SERVERS_V` failed in SQL Developer (a comment ending with `;`).
- Retention stays a placeholder.
