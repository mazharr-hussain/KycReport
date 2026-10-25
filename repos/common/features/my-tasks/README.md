# My Tasks

COMMON component, module Workflow (feature `MY_TASKS`).

## Purpose
The tasks of the signed-in user from every application.

## Usage
Page 40 (the task list), 43 (notifications), 143 (answer / review an information request), 144 (configuration change).

## Benefit
One inbox for all applications.

## Depends on (objects of these components are named in its files)
approval-setup, attachments, change-approvals, information-requests, notifications, workflow-setup

## Used by (COMMON components)
-

## Installation requirements
COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites check 00a first; 00b stops an install in the wrong schema).

## Application objects
### Pages
- 40 My Tasks (`pages/p00040-my-tasks.apx`)
- 43 Notifications (`pages/p00043-notifications.apx`)
- 143 Information Request (`pages/p00143-information-request.apx`)
- 144 Configuration Change (`pages/p00144-configuration-change.apx`)

### Shared components
-

## Database objects (schema XXFUSION)
- views: `XXFND_PENDING_APPROVALS_V`

## Roles and privileges
Privileges `MY_TASKS.<action>` for VIEW, MANAGE (VIEW opens its pages, CREATE adds, MANAGE changes and deletes); a page opens with the privilege on the feature it is mapped to.
Roles at install: every role, at install (each user then acts only on what the data and the task allow).

## How another application uses it
1. The application is onboarded (Applications, or its own install with the generic script 00c-onboard-with-common.sql). 2. Its schema gets the grants (SELECT, REFERENCES, EXECUTE - no INSERT, UPDATE or DELETE) and creates synonyms for the COMMON objects (script 00c does both). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type "page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles in the COMMON console.

Link to COMMON page 40 (`app: COMMON`, or the entry My Tasks of `XXFND_APP_MENU_V`); the tasks of the application's workflows appear by themselves. Every signed-in user opens it (release 87) and sees only their own tasks.

### Public routines
-

## Tests
- in `../../tests/` (whole application)

## Files
See `docs/TECHNICAL.md` (generated on every build): pages, database objects, shared components, configuration and tests.
