# Data Model

COMMON component, module Platform (feature `DATA_MODEL`).

## Purpose
The database objects of every registered application, read live from the database dictionary: the object catalogue and the entity-relationship diagram (release 89).

## Usage
Page 175 lists an application's objects (tables, views, packages, types, sequences, triggers) and sets its object prefix; page 176 shows one object (columns, constraints, indexes, triggers, routines with parameters, grants, uses / used by); page 177 draws the diagram of the application, a group of tables or one table with its neighbours.

## Benefit
Always current documentation of every application's data model, without exports or diagram tools.

## Depends on (objects of these components are named in its files)
applications, data-security, roles-privileges

## Used by (COMMON components)
applications

## Installation requirements
COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites check 00a first; 00b stops an install in the wrong schema). To read other applications' schemas, ADMIN runs `db/admin/grant-dictionary-to-xxfusion.sql` once (SELECT on the DBA_ dictionary views), then the supporting objects again; without it only COMMON's objects (and what COMMON may already read) are listed. The diagram uses the Mermaid library (a COMMON static file).

## Application objects
### Pages
- 175 Data Model (`pages/p00175-data-model.apx`)
- 176 Database Object (`pages/p00176-database-object.apx`)
- 177 Data Model Diagram (`pages/p00177-data-model-diagram.apx`)

### Shared components
-

## Database objects (schema XXFUSION)
- tables: `XXFND_DM_APP_SCOPES`
- views: `XXFND_DM_APPS_V`, `XXFND_DM_OBJECTS_V`
- packages: `XXFND_DATA_MODEL_PKG`

## Roles and privileges
Privileges `DATA_MODEL.<action>` for VIEW, MANAGE (VIEW opens its pages, CREATE adds, MANAGE changes and deletes); a page opens with the privilege on the feature it is mapped to.
Roles at install: Common Administrator (COMMON_ADMIN) holds every privilege of an admin feature (19c); other roles get them from the COMMON console.

## How another application uses it
1. The application is onboarded (Applications, or its own install with the generic script 00c-onboard-with-common.sql). 2. Its schema gets the grants (SELECT, REFERENCES, EXECUTE - no INSERT, UPDATE or DELETE) and creates synonyms for the COMMON objects (script 00c does both). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type "page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles in the COMMON console.

Nothing to install in the application. IT may set its object prefix (page 175) and the application may group its tables for the diagram (`XXFND_DATA_MODEL_PKG.REGISTER_TABLE_GROUP`). Its administrators open it from the application's menu once IT lets the application manage Data Model (managed in the application): they see their own application only.

### Public routines
- `XXFND_DATA_MODEL_PKG`: APP_VISIBLE, ERD_SOURCE, FULL_DICTIONARY, INDEX_COLUMNS, REGISTER_TABLE_GROUP, SET_OBJECT_PREFIX, UNREGISTER_APPLICATION, UNREGISTER_TABLE_GROUP (registration: REGISTER_TABLE_GROUP)

## Tests
- in `../../tests/` (whole application)

## Files
- `db/packages/xxfnd_data_model_pkg.sql`
- `db/tables/xxfnd_dm_app_scopes.sql`
- `db/views/xxfnd_dm_apps_v.sql`
- `db/views/xxfnd_dm_objects_v.sql`
- `pages/p00175-data-model.apx`
- `pages/p00176-database-object.apx`
- `pages/p00177-data-model-diagram.apx`
