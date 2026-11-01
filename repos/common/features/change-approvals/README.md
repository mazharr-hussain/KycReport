# Configuration Change Approvals

COMMON component, module Workflow (feature `CHANGE_APPROVALS`).

## Purpose
Who approves the configuration changes of every application (maker-checker, process CONFIG_CHANGE).

## Usage
A change to a controlled setup table waits for approval; the approver acts on COMMON page 144 from My Tasks.

## Benefit
Maker-checker on setup data for every application without code in the application.

## Depends on (objects of these components are named in its files)
applications, attachments, audit-log, data-security, flexfields, integrations, lookups, notifications, retention, roles-privileges, users-access, workflow-setup

## Used by (COMMON components)
integrations, my-tasks, users-access, workflow-setup

## Installation requirements
COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites check 00a first; 00b stops an install in the wrong schema).

## Application objects
### Pages
-

### Shared components
- `shared-components/task-definitions/CONFIG-CHANGE.apx`
- `shared-components/workflows/CONFIG-CHANGE.apx`

## Database objects (schema XXFUSION)
- tables: `XXFND_CONFIG_TABLES`
- views: `XXFND_CONFIG_CHANGES_V`
- packages: `XXFND_APPROVAL_PKG`, `XXFND_CONFIG_APPROVAL_PKG`
- types: `XXFND_CONFIG_CHANGE_ROW`, `XXFND_CONFIG_CHANGE_TAB`
- seed: `XXFND_CONFIG_TABLES`

## Roles and privileges
Privileges `CHANGE_APPROVALS.<action>` for VIEW, MANAGE (VIEW opens its pages, CREATE adds, MANAGE changes and deletes); a page opens with the privilege on the feature it is mapped to.
Roles at install: The roles that manage the Approval Setup, once at install (26).

## How another application uses it
1. The application is onboarded (Applications, or its own install with the generic script 00c-onboard-with-common.sql). 2. Its schema gets the grants (SELECT, REFERENCES, EXECUTE - no INSERT, UPDATE or DELETE) and creates synonyms for the COMMON objects (script 00c does both). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type "page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles in the COMMON console.

The application registers its controlled setup tables with `XXFND_APPROVAL_PKG.REGISTER_CONFIG_TABLE` and submits a change with `REQUEST` (release 87: a faulted earlier change no longer blocks it).

### Public routines
- `XXFND_APPROVAL_PKG`: APPLY_RULES, APPROVE, APPROVE_CHANGE, CONFIG_CHANGES, IS_CONTROLLED, IS_PENDING, REGISTER_CONFIG_TABLE, REJECT, REJECT_CHANGE, REQUEST, SUBMIT, TASK_CHANGE (registration: REGISTER_CONFIG_TABLE)

## Tests
- in `../../tests/` (whole application)

## Files
See `repos/common/docs/components/change-approvals/technical.md` (generated on every build): pages, database objects, shared components, configuration and tests.
