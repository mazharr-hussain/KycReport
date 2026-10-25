# Users & Access

COMMON component, module Security (feature `USERS_ACCESS`).

## Purpose
Users, their roles and their data access.

## Usage
Pages 103 / 104 maintain users (local or SSO, mapped to employees); page 183 assigns roles and data access rules. XXFND_USER_PKG is also every application's sign-in (post-authentication) and authorization logic.

## Benefit
One user record and one role assignment for all applications; sign-in and authorization rules in one place.

## Depends on (objects of these components are named in its files)
applications, attachments, audit-log, change-approvals, data-security, flexfields, integrations, lookups, retention, roles-privileges

## Used by (COMMON components)
applications, change-approvals, data-security, home, lookups, notifications, roles-privileges, workflow-setup

## Installation requirements
COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites check 00a first; 00b stops an install in the wrong schema). Single sign-on: the Fusion web credential and FUSION_BASE_URL (Fusion HCM worker sync).

## Application objects
### Pages
- 103 Users and Access (`pages/p00103-users.apx`)
- 104 User (`pages/p00104-user.apx`)
- 183 Assign (`pages/p00183-assign.apx`)
- 184 Data Access Values (`pages/p00184-data-access-values.apx`)

### Shared components
- `shared-components/automations/fusion-hcm-sync.apx`

## Database objects (schema XXFUSION)
- tables: `XXFND_EMPLOYEES`, `XXFND_USERS`, `XXFND_USER_APPLICATIONS`, `XXFND_USER_ROLES`
- views: `XXFND_USER_DATA_ACCESS_V`, `XXFND_USER_ROLES_V`, `XXFND_USER_ROLE_TREE_V`
- packages: `XXFND_AUTH_PKG`, `XXFND_USER_PKG`
- triggers: `XXFND_USER_ROLES_USER`
- seed: `XXFND_USERS`, `XXFND_USER_ROLES`

## Roles and privileges
Privileges `USERS_ACCESS.<action>` for VIEW, CREATE, MANAGE (VIEW opens its pages, CREATE adds, MANAGE changes and deletes); a page opens with the privilege on the feature it is mapped to.
Roles at install: Common Administrator (COMMON_ADMIN) holds every privilege of an admin feature (19c); other roles get them from the COMMON console.

## How another application uses it
1. The application is onboarded (Applications, or its own install with the generic script 00c-onboard-with-common.sql). 2. Its schema gets the grants (SELECT, REFERENCES, EXECUTE - no INSERT, UPDATE or DELETE) and creates synonyms for the COMMON objects (script 00c does both). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type "page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles in the COMMON console.

The application's authentication schemes call `XXFND_USER_PKG.POST_AUTH_LOCAL` / `POST_AUTH_SSO`, and its authorization schemes call `XXFND_USER_PKG.AUTHORIZED(<scheme>)` (KYC subscribes to them). The first administrator: `XXFND_USER_PKG.BOOTSTRAP_ADMIN`.

### Public routines
- `XXFND_USER_PKG`: ASSIGN_ROLE, AUTHORIZED, BOOTSTRAP_ADMIN, CREATE_LOCAL_USER, EMPLOYEE_USER, END_APPLICATION, ENSURE_APEX_ACCOUNT, GRANT_APPLICATION, HOME_APPLICATION, IN_GROUP, IS_LOCAL, LOAD_USER_ROLES, MAP_LOGIN_USER, POST_AUTH_LOCAL, POST_AUTH_SSO, RENAME_USER, RENAMING, RESET_PASSWORD, SAVE_USER, SET_ENABLED, UNASSIGN_ROLE

## Tests
- in `../../tests/` (whole application)

## Files
See `docs/TECHNICAL.md` (generated on every build): pages, database objects, shared components, configuration and tests.
