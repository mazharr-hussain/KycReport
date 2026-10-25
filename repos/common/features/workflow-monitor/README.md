# Workflow Monitor

COMMON component, module Workflow (feature `WORKFLOW_MONITOR`).

## Purpose
Running workflows and tasks of every application: act on anyone's behalf.

## Usage
Pages 141 / 142: suspend, resume, retry, reassign, delegate.

## Benefit
Business administration of every workflow from one place.

## Depends on (objects of these components are named in its files)
applications, workflow-setup

## Used by (COMMON components)
-

## Installation requirements
COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites check 00a first; 00b stops an install in the wrong schema).

## Application objects
### Pages
- 141 Workflow Monitor (`pages/p00141-workflow-monitor.apx`)
- 142 Workflow (`pages/p00142-workflow.apx`)

### Shared components
-

## Database objects (schema XXFUSION)
- none of its own (it uses the objects of the components above)

## Roles and privileges
Privileges `WORKFLOW_MONITOR.<action>` for VIEW, MANAGE (VIEW opens its pages, CREATE adds, MANAGE changes and deletes); a page opens with the privilege on the feature it is mapped to.
Roles at install: Super Administrator (SUPER_ADMIN); granted from the console only (19c).

## How another application uses it
1. The application is onboarded (Applications, or its own install with the generic script 00c-onboard-with-common.sql). 2. Its schema gets the grants (SELECT, REFERENCES, EXECUTE - no INSERT, UPDATE or DELETE) and creates synonyms for the COMMON objects (script 00c does both). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type "page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles in the COMMON console.

Nothing to register: the workflows of every application appear. `XXFND_WORKFLOW_PKG.BUSINESS_ADMINS` returns the holders.

### Public routines
-

## Tests
- in `../../tests/` (whole application)

## Files
See `docs/TECHNICAL.md` (generated on every build): pages, database objects, shared components, configuration and tests.
