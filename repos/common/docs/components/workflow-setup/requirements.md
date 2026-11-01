# Workflow Setup - requirements (COMMON)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/common/docs/README.md`.

## Workflow setup

- **Purpose:** the workflow engine around APEX workflows and tasks.
- **What it does:** manages workflow start, end and state; task deadlines and escalation; the process catalogue (which workflows are on for each application); approval delegations.
- **Why:** one workflow engine for all applications.

* **How it works:** applications start, end and query workflows through COMMON; an automation applies task deadlines and escalation.
* **How it's built:** *APEX:* Workflows, Human Tasks, automation (task deadlines), interactive grids and forms. *Custom:* `XXFND_WORKFLOW_PKG`, 3 tables.

- **DB objects:** *Own:* Tables: XXFND\_TASK\_ALERTS, XXFND\_TASK\_SETTINGS, XXFND\_WF\_DELEGATIONS; Packages: XXFND\_WORKFLOW\_PKG. *Uses:* XXFND\_APPLICATIONS, XXFND\_APPROVAL\_RULES, XXFND\_APPROVAL\_RULE\_PKG, XXFND\_APPROVAL\_RULE\_STEPS, XXFND\_APPROVAL\_TYPES, XXFND\_ROLES, XXFND\_WORKFLOW\_PROCESSES.

* **Shared components:** App items: G\_ADMIN\_APP, G\_ADMIN\_LOCK; Authorizations: page-create, page-manage, page-submit, page-view; Automations: task-deadlines; Breadcrumb: breadcrumb; LOVs: lov-employees, lov-roles, lov-task-definitions; Lists: administration; Page groups: administration; Workflows: RFI.

## Delegation and absence rules (planned)

- **Purpose:** keep approvals moving while someone is away.
- **What it does:** a user records "not available from date to date" with a comment, and delegates, transfers or reassigns all approvals, or those of chosen processes, to a named person. Users set rules for themselves; administrators for anyone. Every workflow checks these rules when it assigns an approval.
- **Why:** delegation covers approvals only, never page or data access.

* **How it works (planned):** when a task is assigned, COMMON checks the absence rules and assigns it to the substitute.
* **How it's built (planned):** *APEX:* Human Task delegation API. *Custom:* absence-rule table and checks in `XXFND_WORKFLOW_PKG`.

## Change - Processes and approval groups (COMMON 113)

- The Process Catalogue lists one row per process (for example KYC case approval, KYC request approval); each process opens its Process page with its approval rules and its approval groups.
- An approval group is a named set of approvers of a process: roles (their active users) and users. A rule level can name a group instead of one role or user; anyone in the group can approve.
- Fixes: the Server form (ORA-00937) and the User form (grid columns) open again.
