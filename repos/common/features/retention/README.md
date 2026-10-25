# Retention

COMMON component, module Documents and Records (feature `RETENTION`).

## Purpose
How long records and documents are kept.

## Usage
Pages 112 / 113: retention policies.

## Benefit
One retention rule set for every application.

## Depends on (objects of these components are named in its files)
applications, lookups

## Used by (COMMON components)
applications, change-approvals, flexfields, users-access

## Installation requirements
COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites check 00a first; 00b stops an install in the wrong schema).

## Application objects
### Pages
- 112 Retention (`pages/p00112-retention-policies.apx`)
- 113 Retention Policy (`pages/p00113-retention-policy.apx`)

### Shared components
- `shared-components/lovs.apx`

## Database objects (schema XXFUSION)
- tables: `XXFND_RETENTION_POLICIES`
- packages: `XXFND_RETENTION_PKG`
- seed: `XXFND_RETENTION_POLICIES`

## Roles and privileges
Privileges `RETENTION.<action>` for VIEW, CREATE, MANAGE (VIEW opens its pages, CREATE adds, MANAGE changes and deletes); a page opens with the privilege on the feature it is mapped to.
Roles at install: Common Administrator (COMMON_ADMIN) holds every privilege of an admin feature (19c); other roles get them from the COMMON console.

## How another application uses it
1. The application is onboarded (Applications, or its own install with the generic script 00c-onboard-with-common.sql). 2. Its schema gets the grants (SELECT, REFERENCES, EXECUTE - no INSERT, UPDATE or DELETE) and creates synonyms for the COMMON objects (script 00c does both). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type "page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles in the COMMON console.

The application reads the policy that applies with `XXFND_RETENTION_PKG.POLICY_FOR` / `IS_ACTIVE`.

### Public routines
- `XXFND_RETENTION_PKG`: IS_ACTIVE, POLICY_FOR, RUN

## Tests
- in `../../tests/` (whole application)

## Files
See `docs/TECHNICAL.md` (generated on every build): pages, database objects, shared components, configuration and tests.
