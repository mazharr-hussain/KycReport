# Change Approvals - requirements (COMMON)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/common/docs/README.md`.

## Configuration-change approvals

- **Purpose:** maker-checker on setup data of every application.
- **What it does:** a change to a controlled setup table waits for approval; the approver acts on it from My Tasks.
- **Why:** setup changes are controlled without code in the application.

* **How it works:** a change to a controlled table is held as pending and starts the CONFIG\_CHANGE workflow; approval applies it, rejection discards it.
* **How it's built:** *APEX:* Workflow and task definition CONFIG\_CHANGE. *Custom:* `XXFND_APPROVAL_PKG`, 1 table, 1 view.

- **DB objects:** *Own:* Tables: XXFND\_CONFIG\_TABLES; Views: XXFND\_CONFIG\_CHANGES\_V; Packages: XXFND\_APPROVAL\_PKG; Types: XXFND\_CONFIG\_CHANGE\_ROW, XXFND\_CONFIG\_CHANGE\_TAB.

* **Shared components:** Task definitions: CONFIG\_CHANGE; Workflows: CONFIG\_CHANGE.
