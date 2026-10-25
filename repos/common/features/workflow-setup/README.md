# Workflow Setup

COMMON component, module Workflow (feature `WORKFLOW_SETUP`).

## Purpose
Delegations, deadlines and escalation, process catalogue.

## Usage
Pages 114 / 115 (delegations), 145 / 146 (task deadlines and escalation), 147 (process catalogue: which application workflows are switched on).

## Benefit
One workflow engine around APEX workflows and tasks: start / end / state, deadlines, delegations, notifications.

## Depends on (objects of these components are named in its files)
applications, approval-setup, audit-log, change-approvals, communications, data-security, information-requests, lookups, notifications, roles-privileges, users-access

## Used by (COMMON components)
applications, approval-setup, change-approvals, data-security, home, information-requests, my-tasks, notifications, workflow-monitor

## Installation requirements
COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites check 00a first; 00b stops an install in the wrong schema). APEX workflows and human tasks; COMMON runs the task-deadlines automation for every application.

## Application objects
### Pages
- 114 Delegations (`pages/p00114-delegations.apx`)
- 115 Delegation (`pages/p00115-delegation.apx`)
- 145 Deadlines and Escalation (`pages/p00145-deadlines-and-escalation.apx`)
- 146 Task Deadline (`pages/p00146-task-deadline.apx`)
- 147 Process Catalogue (`pages/p00147-process-catalogue.apx`)

### Shared components
- `shared-components/automations/task-deadlines.apx`
- `shared-components/lovs.apx`

## Database objects (schema XXFUSION)
- tables: `XXFND_TASK_ALERTS`, `XXFND_TASK_SETTINGS`, `XXFND_WF_DELEGATIONS`, `XXFND_WORKFLOW_PROCESSES`
- packages: `XXFND_TASK_PKG`, `XXFND_WORKFLOW_PKG`

## Roles and privileges
Privileges `WORKFLOW_SETUP.<action>` for VIEW, CREATE, MANAGE (VIEW opens its pages, CREATE adds, MANAGE changes and deletes); a page opens with the privilege on the feature it is mapped to.
Roles at install: Common Administrator (COMMON_ADMIN) holds every privilege of an admin feature (19c); other roles get them from the COMMON console.

## How another application uses it
1. The application is onboarded (Applications, or its own install with the generic script 00c-onboard-with-common.sql). 2. Its schema gets the grants (SELECT, REFERENCES, EXECUTE - no INSERT, UPDATE or DELETE) and creates synonyms for the COMMON objects (script 00c does both). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type "page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles in the COMMON console.

The application registers its workflows as processes (`XXFND_WORKFLOW_PKG.SYNC_PROCESSES`, `SET_PROCESS_ENABLED`) and its task deadlines (`REGISTER_TASK_SETTING`), starts and ends them with `START_PROCESS` / `END_PROCESS`, and reads `STATE`, `IS_RUNNING`, `BUSINESS_ADMINS`.

### Public routines
- `XXFND_WORKFLOW_PKG`: BUSINESS_ADMINS, CANCEL_OPEN, CAN_REQUEST_INFO, COMMON_APPLICATION_ID, COMPLETE_OPEN, CREATE_TASK, DUE_DATE, EMAIL_ENABLED, END_PROCESS, INFO_TASK, IS_RUNNING, LAST_COMMENT, MONITOR_TASK, MONITOR_WORKFLOW, NOTIFY_CREATED, ON_TASK_EVENT, OPEN_TASK_COUNT, PROCESS_DEADLINES, PROCESS_OF_TASK, REGISTER_TASK_SETTING, SET_PROCESS_ENABLED, SET_WORKSPACE_EMAIL, START_PROCESS, STATE, SYNC_PROCESSES, TASK_MESSAGES, TASK_RECORD, UNREGISTER_APPLICATION, UNREGISTER_CONFIG_TABLE, USERS_IN_ROLE, USERS_WITH_PRIVILEGE, VACATION_RULE, WORKFLOW_APPLICATION, WORKFLOW_ENABLED (registration: REGISTER_TASK_SETTING)

## Tests
- in `../../tests/` (whole application)

## Files
See `docs/TECHNICAL.md` (generated on every build): pages, database objects, shared components, configuration and tests.
