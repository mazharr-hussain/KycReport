# Data Security

COMMON component, module Security (feature `DATA_SECURITY`).

## Purpose
Data access rules: which rows each user and role can see.

## Usage
Pages 180 / 181: data access rules (table, column, allowed values), assigned to users and roles.

## Benefit
Row-level security (VPD) for every application from one set of rules.

## Depends on (objects of these components are named in its files)
applications, lookups, roles-privileges, users-access, workflow-setup

## Used by (COMMON components)
applications, approval-setup, attachments, change-approvals, data-model, information-requests, notifications, roles-privileges, users-access, workflow-setup

## Installation requirements
COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites check 00a first; 00b stops an install in the wrong schema).

## Application objects
### Pages
- 180 Data Security (`pages/p00180-data-security.apx`)
- 181 Data Object (`pages/p00181-data-security-rule.apx`)
- 186 Organizations (`pages/p00186-organizations.apx`)

### Shared components
-

## Database objects (schema XXFUSION)
- tables: `XXFND_DATA_DIMENSIONS`, `XXFND_DATA_RULE_ASSIGNMENTS`, `XXFND_DATA_SECURITY_RULES`
- packages: `XXFND_VPD_PKG`
- triggers: `XXFND_DATA_RULES_ASSIGN`
- seed: `XXFND_DATA_RULE_ASSIGNMENTS`

## Roles and privileges
Privileges `DATA_SECURITY.<action>` for VIEW, CREATE, MANAGE (VIEW opens its pages, CREATE adds, MANAGE changes and deletes); a page opens with the privilege on the feature it is mapped to.
Roles at install: Common Administrator (COMMON_ADMIN) holds every privilege of an admin feature (19c); other roles get them from the COMMON console.

## How another application uses it
1. The application is onboarded (Applications, or its own install with the generic script 00c-onboard-with-common.sql). 2. Its schema gets the grants (SELECT, REFERENCES, EXECUTE - no INSERT, UPDATE or DELETE) and creates synonyms for the COMMON objects (script 00c does both). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type "page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles in the COMMON console.

The application registers its rules with `XXFND_VPD_PKG.REGISTER_DATA_RULE`, applies the policies (`APPLY_POLICIES`, KYC script 03), reads `ALLOWED_VALUES` for its lists, and uses `BEGIN_TRUSTED` / `END_TRUSTED` around internal reads.

### Public routines
- `XXFND_VPD_PKG`: ALLOWED_VALUES, APPLY_POLICIES, ASSIGNMENT_VALUES, ASSIGN_RULE, BEGIN_TRUSTED, CLEAR_CACHE, END_TRUSTED, GRANT_DATA_ACCESS, IS_TRUSTED, POLICY, REGISTER_DATA_OBJECT, REGISTER_DATA_RULE, REGISTER_DIMENSION, REVOKE_DATA_ACCESS, SAVE_ORGANIZATION, SET_ASSIGNMENT_VALUES, UNASSIGN_RULE, UNREGISTER_APPLICATION (registration: REGISTER_DATA_OBJECT, REGISTER_DATA_RULE, REGISTER_DIMENSION)

## Tests
- in `../../tests/` (whole application)

## Files
See `repos/common/docs/components/data-security/technical.md` (generated on every build): pages, database objects, shared components, configuration and tests.
