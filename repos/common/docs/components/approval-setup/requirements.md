# Approval Setup - requirements (COMMON)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/common/docs/README.md`.

## Approval setup

- **Purpose:** who approves which record, step by step.
- **What it does:** approval types and rules, with conditions, steps and approvers.
- **Why:** approval chains are data, not code.

* **How it works:** the application passes its record's attributes; the matching rule gives the steps and approvers; each step becomes an approval task.
* **How it's built:** *APEX:* Human Tasks, interactive grids, forms. *Custom:* `XXFND_APPROVAL_RULE_PKG`, 7 tables.

- **DB objects:** *Own:* Tables: XXFND\_APPROVAL\_RULES, XXFND\_APPROVAL\_RULE\_CONDS, XXFND\_APPROVAL\_RULE\_STEPS, XXFND\_APPROVAL\_TXNS, XXFND\_APPROVAL\_TXN\_STEPS, XXFND\_APPROVAL\_TYPES, XXFND\_APPROVAL\_TYPE\_ATTRS; Packages: XXFND\_APPROVAL\_RULE\_PKG; Types: XXFND\_APPROVAL\_STEP\_ROW, XXFND\_APPROVAL\_STEP\_TAB; Triggers: XXFND\_APPROVAL\_RULES\_BI, XXFND\_APPROVAL\_RULE\_STEPS\_TYPE. *Uses:* XXFND\_LOOKUP\_VALUES\_VL, XXFND\_ROLES, XXHR\_EMPLOYEES.

* **Shared components:** App items: G\_ADMIN\_APP; Authorizations: page-create, page-manage, page-submit, page-view; Breadcrumb: breadcrumb; Lists: administration; Page groups: administration.

## Change - Processes and approval groups (COMMON 113)

- The Process Catalogue lists one row per process (for example KYC case approval, KYC request approval); each process opens its Process page with its approval rules and its approval groups.
- An approval group is a named set of approvers of a process: roles (their active users) and users. A rule level can name a group instead of one role or user; anyone in the group can approve.
- Fixes: the Server form (ORA-00937) and the User form (grid columns) open again.
