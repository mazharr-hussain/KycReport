# Data Security

COMMON component, module Security (feature `DATA_SECURITY`).

## Purpose
Data access rules: which rows each user and role can see.

## Usage
Pages 180 / 181: data access rules (table, column, allowed values), assigned to users and roles.

## Benefit
Row-level security (VPD) for every application from one set of rules.

## Depends on (objects of these components are named in its files)
applications, roles-privileges, users-access, workflow-setup

## Used by (COMMON components)
applications, approval-setup, attachments, change-approvals, information-requests, notifications, roles-privileges, users-access, workflow-setup

## Installation requirements
COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites check 00a first; 00b stops an install in the wrong schema).

## Application objects
### Pages
- 180 Data Security (`pages/p00180-data-security.apx`)
- 181 Data Access Rule (`pages/p00181-data-security-rule.apx`)

### Shared components
-

## Database objects (schema XXFUSION)
- tables: `XXFND_DATA_RULE_ASSIGNMENTS`, `XXFND_DATA_SECURITY_RULES`
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
- `XXFND_VPD_PKG`: ALLOWED_VALUES, APPLY_POLICIES, ASSIGN_RULE, BEGIN_TRUSTED, CLEAR_CACHE, END_TRUSTED, IS_TRUSTED, POLICY, REGISTER_DATA_RULE, UNASSIGN_RULE (registration: REGISTER_DATA_RULE)

## Tests
- in `../../tests/` (whole application)

## Files
- `db/packages/xxfnd_vpd_pkg.sql`
- `db/seed/xxfnd_data_rule_assignments.sql`
- `db/tables/xxfnd_data_rule_assignments.sql`
- `db/tables/xxfnd_data_security_rules.sql`
- `db/triggers/xxfnd_data_rules_assign.sql`
- `pages/p00180-data-security.apx`
- `pages/p00181-data-security-rule.apx`
