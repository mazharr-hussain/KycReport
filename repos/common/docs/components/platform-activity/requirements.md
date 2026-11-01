# Platform Activity - requirements (COMMON)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/common/docs/README.md`.

## Platform activity

- **Purpose:** how every application is used and performs.
- **What it does:** page views, top users, errors and page performance from the APEX activity log, for IT.
- **Why:** one activity view for all applications.

* **How it works:** reads the APEX workspace activity log for every registered application.
* **How it's built:** *APEX:* `APEX_WORKSPACE_ACTIVITY_LOG`, reports. *Custom:* none.

- **DB objects:** *Own:* none. *Uses:* XXFND\_APPLICATIONS.

* **Shared components:** Authorizations: page-view; Breadcrumb: breadcrumb; Lists: administration; Page groups: administration.
