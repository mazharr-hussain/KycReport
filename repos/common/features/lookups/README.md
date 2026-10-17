# Lookups

COMMON component, module Reference Data (feature `LOOKUPS`).

## Purpose
Lists of values used across the application.

## Usage
Pages 101 / 102: lookup types and their values.

## Benefit
Lists of values are data, maintained from the console, with translations and levels.

## Depends on (objects of these components are named in its files)
applications, attachments, audit-log, communications, information-requests, integrations, notifications, roles-privileges, users-access

## Used by (COMMON components)
applications, approval-setup, attachments, change-approvals, flexfields, information-requests, integrations, retention, roles-privileges, users-access, workflow-setup

## Installation requirements
COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites check 00a first; 00b stops an install in the wrong schema).

## Application objects
### Pages
- 101 Lookups (`pages/p00101-lookups.apx`)
- 102 Lookup Type (`pages/p00102-lookup-type.apx`)

### Shared components
- `shared-components/lovs.apx`

## Database objects (schema XXFUSION)
- tables: `XXFND_LOOKUP_TYPES`, `XXFND_LOOKUP_VALUES`
- views: `XXFND_LOOKUP_VALUES_VL`
- packages: `XXFND_LOOKUP_PKG`
- triggers: `XXFND_LOOKUP_VALUES_LVL`

## Roles and privileges
Privileges `LOOKUPS.<action>` for VIEW, CREATE, MANAGE (VIEW opens its pages, CREATE adds, MANAGE changes and deletes); a page opens with the privilege on the feature it is mapped to.
Roles at install: Common Administrator (COMMON_ADMIN) holds every privilege of an admin feature (19c); other roles get them from the COMMON console.

## How another application uses it
1. The application is onboarded (Applications). 2. Its schema gets the grants and creates synonyms for the COMMON objects (as KYC script 03 does). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type "page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles in the COMMON console.

The application registers its lookup types and values with `XXFND_LOOKUP_PKG.REGISTER_LOOKUP_TYPE` / `REGISTER_LOOKUP_VALUE` (KYC: 18h) and reads them with `LOOKUP_MEANING`, `IS_VALID_LOOKUP` or the lookup views. COMMON issue C3: script 17 rewrites KYC lookups on upgrade.

### Public routines
- `XXFND_LOOKUP_PKG`: ASSERT_LOOKUP, IS_VALID_LOOKUP, LOOKUP_MEANING, REGISTER_LOOKUP_TYPE, REGISTER_LOOKUP_VALUE (registration: REGISTER_LOOKUP_TYPE, REGISTER_LOOKUP_VALUE)

## Tests
- in `../../tests/` (whole application)

## Files
- `db/packages/xxfnd_lookup_pkg.sql`
- `db/tables/xxfnd_lookup_types.sql`
- `db/tables/xxfnd_lookup_values.sql`
- `db/triggers/xxfnd_lookup_values_lvl.sql`
- `db/views/xxfnd_lookup_values_vl.sql`
- `pages/p00101-lookups.apx`
- `pages/p00102-lookup-type.apx`
- `shared-components/lovs.apx`
