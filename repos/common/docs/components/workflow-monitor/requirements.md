# Workflow Monitor - requirements (COMMON)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/common/docs/README.md`.

## Workflow monitor

- **Purpose:** business administration of running workflows and tasks.
- **What it does:** suspends, resumes, retries, reassigns and delegates workflows and tasks of every application.
- **Why:** administrators act on anyone's behalf from one place.

* **How it works:** administrators see every workflow and task and act on them as business administrators.
* **How it's built:** *APEX:* workflow and task views and APIs, reports. *Custom:* none.

- **DB objects:** *Own:* none. *Uses:* XXFND\_APPLICATIONS, XXFND\_WORKFLOW\_PKG.

* **Shared components:** Authorizations: page-manage, page-view; Breadcrumb: breadcrumb; LOVs: lov-employees; Lists: administration; Page groups: administration.
