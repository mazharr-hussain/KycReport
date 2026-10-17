# Roles & Privileges

COMMON component, module Security (feature `ROLES_PRIVILEGES`).

## Purpose
Roles, the privileges they grant and segregation of duties.

## Usage
Pages 105-108 and 182: roles, their privileges (feature x VIEW / CREATE / MANAGE), SoD rules.

## Benefit
Page access is data driven: every page is mapped to a feature and opened with the privilege on it; SoD is enforced once for all applications.

## Depends on (objects of these components are named in its files)
applications, attachments, audit-log, communications, data-security, information-requests, lookups, notifications, users-access

## Used by (COMMON components)
app-settings, applications, approval-setup, change-approvals, data-security, information-requests, integrations, lookups, notifications, users-access, workflow-setup

## Installation requirements
COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites check 00a first; 00b stops an install in the wrong schema).

## Application objects
### Pages
- 105 Roles (`pages/p00105-roles.apx`)
- 106 Role (`pages/p00106-role.apx`)
- 107 Segregation of Duties (`pages/p00107-segregation-of-duties.apx`)
- 108 Segregation of Duties Rule (`pages/p00108-segregation-of-duties-rule.apx`)
- 182 Privileges (`pages/p00182-privileges.apx`)

### Shared components
- `shared-components/lovs.apx`

## Database objects (schema XXFUSION)
- tables: `XXFND_FEATURES`, `XXFND_FEATURE_PAGES`, `XXFND_PRIVILEGES`, `XXFND_ROLES`, `XXFND_ROLE_PRIVILEGES`, `XXFND_SOD_RULES`
- views: `XXFND_EFFECTIVE_ACCESS_V`
- packages: `XXFND_PRIVILEGE_PKG`
- triggers: `XXFND_ROLES_EVERY_ROLE`, `XXFND_SOD_RULES_ORDER`
- seed: `XXFND_ROLES`

## Roles and privileges
Privileges `ROLES_PRIVILEGES.<action>` for VIEW, CREATE, MANAGE (VIEW opens its pages, CREATE adds, MANAGE changes and deletes); a page opens with the privilege on the feature it is mapped to.
Roles at install: Common Administrator (COMMON_ADMIN) holds every privilege of an admin feature (19c); other roles get them from the COMMON console.

## How another application uses it
1. The application is onboarded (Applications). 2. Its schema gets the grants and creates synonyms for the COMMON objects (as KYC script 03 does). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type "page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles in the COMMON console.

The application registers its features, privileges, pages, roles and SoD rules with `REGISTER_FEATURE`, `REGISTER_PRIVILEGE`, `REGISTER_FEATURE_PAGE`, `REGISTER_ROLE`, `ADD_ROLE_PRIVILEGE`, `REGISTER_SOD_RULE` (KYC: 18h), and checks access with `HAS_PRIVILEGE`, `HAS_PAGE_PRIVILEGE`, `HAS_ROLE`. A registration never overrides what an administrator changed. Removing a registration: COMMON issues C8 / C9.

### Public routines
- `XXFND_PRIVILEGE_PKG`: ADD_ROLE_PRIVILEGE, CAN_VIEW_SENSITIVE, CURRENT_APPLICATION_ID, GIVE_EVERY_ROLE_PRIVILEGES, HAS_ANY_ADMIN_PRIVILEGE, HAS_ANY_PRIVILEGE, HAS_ANY_ROLE, HAS_ANY_ROLE_YN, HAS_PAGE_PRIVILEGE, HAS_PAGE_REQUEST_PRIVILEGE, HAS_PRIVILEGE, HAS_PRIVILEGE_YN, HAS_ROLE, HAS_ROLE_YN, REGISTER_FEATURE, REGISTER_FEATURE_PAGE, REGISTER_PRIVILEGE, REGISTER_ROLE, REGISTER_SOD_RULE, ROLE_PRIVILEGE_LIST, SET_ROLE_PRIVILEGES, SOD_CONFLICT, SYNC_CURRENT_APPLICATION (registration: REGISTER_FEATURE, REGISTER_FEATURE_PAGE, REGISTER_PRIVILEGE, REGISTER_ROLE, REGISTER_SOD_RULE)

## Tests
- in `../../tests/` (whole application)

## Files
- `db/packages/xxfnd_privilege_pkg.sql`
- `db/seed/xxfnd_roles.sql`
- `db/tables/xxfnd_feature_pages.sql`
- `db/tables/xxfnd_features.sql`
- `db/tables/xxfnd_privileges.sql`
- `db/tables/xxfnd_role_privileges.sql`
- `db/tables/xxfnd_roles.sql`
- `db/tables/xxfnd_sod_rules.sql`
- `db/triggers/xxfnd_roles_every_role.sql`
- `db/triggers/xxfnd_sod_rules_order.sql`
- `db/views/xxfnd_effective_access_v.sql`
- `pages/p00105-roles.apx`
- `pages/p00106-role.apx`
- `pages/p00107-segregation-of-duties.apx`
- `pages/p00108-segregation-of-duties-rule.apx`
- `pages/p00182-privileges.apx`
- `shared-components/lovs.apx`
