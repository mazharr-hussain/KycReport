# Flexfields

COMMON component, module Reference Data (feature `FLEXFIELDS`).

## Purpose
Descriptive flexfields and their value sets.

## Usage
Pages 150-153: value sets, flexfields, contexts, segments.

## Benefit
Extra fields on a record without a database change.

## Depends on (objects of these components are named in its files)
applications, attachments, integrations, lookups, retention

## Used by (COMMON components)
applications, change-approvals

## Installation requirements
COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites check 00a first; 00b stops an install in the wrong schema).

## Application objects
### Pages
- 150 Value Sets (`pages/p00150-value-sets.apx`)
- 151 Value Set (`pages/p00151-value-set.apx`)
- 152 Descriptive Flexfields (`pages/p00152-descriptive-flexfields.apx`)
- 153 Descriptive Flexfield (`pages/p00153-descriptive-flexfield.apx`)

### Shared components
- `shared-components/lovs.apx`

## Database objects (schema XXFUSION)
- tables: `XXFND_DF_CONTEXTS`, `XXFND_DF_FLEXFIELDS`, `XXFND_DF_SEGMENTS`, `XXFND_VALUE_SETS`
- views: `XXFND_DF_CONTEXTS_VL`, `XXFND_DF_SEGMENTS_VL`
- packages: `XXFND_DFF_PKG`, `XXFND_DFF_SETUP_PKG`
- triggers: `XXFND_DF_CONTEXTS_PROTECT`, `XXFND_DF_FLEXFIELDS_CHK`, `XXFND_DF_SEGMENTS_CHK`

## Roles and privileges
Privileges `FLEXFIELDS.<action>` for VIEW, CREATE, MANAGE (VIEW opens its pages, CREATE adds, MANAGE changes and deletes); a page opens with the privilege on the feature it is mapped to.
Roles at install: Common Administrator (COMMON_ADMIN) holds every privilege of an admin feature (19c); other roles get them from the COMMON console.

## How another application uses it
1. The application is onboarded (Applications, or its own install with the generic script 00c-onboard-with-common.sql). 2. Its schema gets the grants (SELECT, REFERENCES, EXECUTE - no INSERT, UPDATE or DELETE) and creates synonyms for the COMMON objects (script 00c does both). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type "page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles in the COMMON console.

The application registers its value sets, flexfields and contexts (`XXFND_DFF_PKG.REGISTER_VALUE_SET`, `REGISTER_FLEXFIELD`, `REGISTER_CONTEXT`), shows them with `RENDER`, checks with `VALIDATE` and saves with `SAVE`.

### Public routines
- `XXFND_DFF_PKG`: ADMIN_SQL_ERROR, CHECK_FLEXFIELD, CHECK_SEGMENT, DERIVE_CONTEXT, FLEXFIELD_FOR_TABLE, GENERATE_ALL_DFV_VIEWS, GENERATE_DFV_VIEW, REGISTER_CONTEXT, REGISTER_FLEXFIELD, REGISTER_VALUE_SET, RENDER, SAVE, SAVE_FLEXFIELD_NAME, UNREGISTER_APPLICATION, UNREGISTER_CONTEXT, UNREGISTER_FLEXFIELD, UNREGISTER_VALUE_SET, VALIDATE, VALUE_LIST (registration: REGISTER_CONTEXT, REGISTER_FLEXFIELD, REGISTER_VALUE_SET)

## Tests
- in `../../tests/` (whole application)

## Files
- `db/packages/xxfnd_dff_pkg.sql`
- `db/packages/xxfnd_dff_setup_pkg.sql`
- `db/tables/xxfnd_df_contexts.sql`
- `db/tables/xxfnd_df_flexfields.sql`
- `db/tables/xxfnd_df_segments.sql`
- `db/tables/xxfnd_value_sets.sql`
- `db/triggers/xxfnd_df_contexts_protect.sql`
- `db/triggers/xxfnd_df_flexfields_chk.sql`
- `db/triggers/xxfnd_df_segments_chk.sql`
- `db/views/xxfnd_df_contexts_vl.sql`
- `db/views/xxfnd_df_segments_vl.sql`
- `pages/p00150-value-sets.apx`
- `pages/p00151-value-set.apx`
- `pages/p00152-descriptive-flexfields.apx`
- `pages/p00153-descriptive-flexfield.apx`
- `shared-components/lovs.apx`
