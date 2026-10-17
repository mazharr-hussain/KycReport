# My Tasks

COMMON component, module Workflow (feature `MY_TASKS`).

## Purpose
The tasks of the signed-in user from every application.

## Usage
Page 40 (the task list), 43 (notifications), 143 (answer / review an information request), 144 (configuration change).

## Benefit
One inbox for all applications.

## Depends on (objects of these components are named in its files)
approval-setup, change-approvals, information-requests, notifications, workflow-setup

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
1. The application is onboarded (Applications). 2. Its schema gets the grants and creates synonyms for the COMMON objects (as KYC script 03 does). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type "page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles in the COMMON console.

Link to COMMON page 40 (`app: COMMON`); the tasks of the application's workflows appear by themselves. The user must be able to open COMMON (COMMON issue C1).

### Public routines
-

## Tests
- in `../../tests/` (whole application)

## Files
- `db/views/xxfnd_pending_approvals_v.sql`
- `pages/p00040-my-tasks.apx`
- `pages/p00043-notifications.apx`
- `pages/p00143-information-request.apx`
- `pages/p00144-configuration-change.apx`
