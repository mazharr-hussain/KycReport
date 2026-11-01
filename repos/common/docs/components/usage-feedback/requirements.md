# Usage Feedback - requirements (COMMON)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/common/docs/README.md`.

## Usage feedback

- **Purpose:** follow up the feedback people gave.
- **What it does:** IT reads feedback from every application and follows it up.
- **Why:** all feedback in one place.

* **How it works:** IT sees all feedback and records its follow-up status.
* **How it's built:** *APEX:* feedback views, reports. *Custom:* none.

- **DB objects:** *Own:* none. *Uses:* XXFND\_APPLICATIONS, XXFND\_APPLICATION\_PKG.

* **Shared components:** Authorizations: page-manage, page-view; Breadcrumb: breadcrumb; Lists: administration; Page groups: administration.
