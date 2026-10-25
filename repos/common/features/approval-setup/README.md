# Approval Setup

COMMON component, module Workflow (feature `APPROVAL_SETUP`).

## Purpose
Approval rules: who approves which record, step by step.

## Usage
Pages 148 / 149: approval types and rules (conditions, steps, approvers).

## Benefit
Approval chains are data (AME style), not code.

## Depends on (objects of these components are named in its files)
applications, data-security, lookups, roles-privileges, workflow-setup

## Used by (COMMON components)
applications, information-requests, my-tasks, workflow-setup

## Installation requirements
COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites check 00a first; 00b stops an install in the wrong schema).

## Application objects
### Pages
- 148 Approval Setup (`pages/p00148-approval-setup.apx`)
- 149 Approval Rule (`pages/p00149-approval-rule.apx`)

### Shared components
-

## Database objects (schema XXFUSION)
- tables: `XXFND_APPROVAL_TYPES`
- packages: `XXFND_APPROVAL_RULE_PKG`
- types: `XXFND_APPROVAL_STEP_ROW`, `XXFND_APPROVAL_STEP_TAB`
- triggers: `XXFND_APPROVAL_RULES_BI`, `XXFND_APPROVAL_RULE_STEPS_TYPE`

## Roles and privileges
Privileges `APPROVAL_SETUP.<action>` for VIEW, CREATE, MANAGE (VIEW opens its pages, CREATE adds, MANAGE changes and deletes); a page opens with the privilege on the feature it is mapped to.
Roles at install: Common Administrator (COMMON_ADMIN) holds every privilege of an admin feature (19c); other roles get them from the COMMON console.

## How another application uses it
1. The application is onboarded (Applications, or its own install with the generic script 00c-onboard-with-common.sql). 2. Its schema gets the grants (SELECT, REFERENCES, EXECUTE - no INSERT, UPDATE or DELETE) and creates synonyms for the COMMON objects (script 00c does both). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type "page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles in the COMMON console.

The application registers its approval types and default rule (`XXFND_APPROVAL_RULE_PKG.REGISTER_TYPE`, `REGISTER_DEFAULT_RULE`), starts an approval with `START_APPROVAL`, reads `CURRENT_APPROVERS` / `NEXT_STEP` and decides with `DECIDE_TASK`. Several rules per type: `REGISTER_RULE` (release 88); `UNREGISTER_RULE` / `UNREGISTER_TYPE` remove them.

### Public routines
- `XXFND_APPROVAL_RULE_PKG`: ADD_APPROVER, APPROVAL_ERROR, APPROVER_LABEL, APPROVER_TYPE_AVAILABLE, CANCEL, CURRENT_APPROVERS, CURRENT_POSITION, CURRENT_ROLE, CURRENT_STEP_NAME, DECIDE_TASK, IS_STARTED, MATCHING_RULE, NEXT_STEP, OPEN_COUNT, REGISTER_DEFAULT_RULE, REGISTER_RULE, REGISTER_TYPE, START_APPROVAL, STEPS, STEP_COUNT, STEP_DUE_DATE, UNREGISTER_APPLICATION, UNREGISTER_RULE, UNREGISTER_TYPE (registration: REGISTER_DEFAULT_RULE, REGISTER_RULE, REGISTER_TYPE)

## Tests
- in `../../tests/` (whole application)

## Files
See `docs/TECHNICAL.md` (generated on every build): pages, database objects, shared components, configuration and tests.
