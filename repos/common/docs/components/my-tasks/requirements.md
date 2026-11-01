# My Tasks - requirements (COMMON)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/common/docs/README.md`.

## My Tasks

- **Purpose:** one inbox for the signed-in user.
- **What it does:** lists the user's tasks and notifications from every application, and opens information requests and configuration changes to act on.
- **Why:** users work from one place across all applications.

* **How it works:** lists the user's open tasks of every application and opens each on its task page.
* **How it's built:** *APEX:* Human Task API (`APEX_HUMAN_TASK`), reports. *Custom:* none.

- **DB objects:** *Own:* none. *Uses:* XXFND\_APPROVAL\_PKG, XXFND\_APPROVAL\_RULE\_PKG, XXFND\_ATTACHED\_DOCUMENTS, XXFND\_NOTIFICATIONS, XXFND\_NOTIFY\_CHANNELS, XXFND\_NOTIFY\_PKG, XXFND\_RFIS, XXFND\_RFI\_PKG, XXFND\_WORKFLOW\_PKG.

* **Shared components:** Authorizations: signed-in-user; Breadcrumb: breadcrumb; Lists: administration; Page groups: administration; Task definitions: RFI\_RESPONSE, RFI\_REVIEW.
