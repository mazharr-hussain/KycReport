# Audit Log

COMMON component, module Security (feature `AUDIT_LOG`).

## Purpose
Who changed what and when.

## Usage
Page 111.

## Benefit
One audit trail for every application.

## Depends on (objects of these components are named in its files)
-

## Used by (COMMON components)
attachments, change-approvals, integrations, lookups, roles-privileges, users-access, workflow-setup

## Installation requirements
COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites check 00a first; 00b stops an install in the wrong schema).

## Application objects
### Pages
- 111 Audit Log (`pages/p00111-audit-log.apx`)

### Shared components
-

## Database objects (schema XXFUSION)
- tables: `XXFND_AUDIT_LOG`
- packages: `XXFND_AUDIT_PKG`

## Roles and privileges
Privileges `AUDIT_LOG.<action>` for VIEW (VIEW opens its pages, CREATE adds, MANAGE changes and deletes); a page opens with the privilege on the feature it is mapped to.
Roles at install: Common Administrator (COMMON_ADMIN) holds every privilege of an admin feature (19c); other roles get them from the COMMON console.

## How another application uses it
1. The application is onboarded (Applications, or its own install with the generic script 00c-onboard-with-common.sql). 2. Its schema gets the grants (SELECT, REFERENCES, EXECUTE - no INSERT, UPDATE or DELETE) and creates synonyms for the COMMON objects (script 00c does both). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type "page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles in the COMMON console.

The application creates audit triggers on its tables with `XXFND_AUDIT_PKG.CREATE_AUDIT_TRIGGER` and may set a change reason (`SET_CHANGE_REASON`).

### Public routines
- `XXFND_AUDIT_PKG`: CLEAR_CHANGE_REASON, CREATE_AUDIT_TRIGGER, CREATE_CONFIG_AUDIT_TRIGGERS, GET_CHANGE_REASON, LOG_CHANGE, SET_CHANGE_REASON

## Tests
- in `../../tests/` (whole application)

## Files
- `db/packages/xxfnd_audit_pkg.sql`
- `db/tables/xxfnd_audit_log.sql`
- `pages/p00111-audit-log.apx`
