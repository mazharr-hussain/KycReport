# Patch 118 - COMMON 102: HR tables carry the XXHR_ prefix, departments by ID

Build: `COMMON-Application-APEXlang_102.zip` (application version "Release 102"). COMMON only. Install COMMON 101
(patch 117) first. KYC 96 (patch 119) follows right after: until it is installed, KYC still points at the old names.

## What changes
- Renamed (data, grants, policies and foreign keys stay with the tables):
  - `XXFND_EMPLOYEES` -> `XXHR_EMPLOYEES`
  - `XXFND_ORGANIZATIONS` -> `XXHR_ORGANIZATIONS`
  - their own constraints, indexes and triggers (`XXFND_EMPLOYEES_PK` -> `XXHR_EMPLOYEES_PK`, `..._SRC`, `..._RENAME`, ...)
  - the setup rows that name the tables (audited tables, Data Model groups, data objects, ...); the audit log keeps
    the name it had.
- New checked step `XXFND_DDL_PKG.RENAME_TABLE` (00): renames only while the old table exists and the new one does
  not; a re-run does nothing. Script `00d` runs it on install and upgrade, before the base table scripts; a fresh
  install creates the XXHR_ tables directly (01, 09a).
- Every reference uses the new names (packages, views, pages 103, 104, 149, 180, 184, 186, LOVs, admin script).
- COMMON owns two prefixes, `XXFND_` and `XXHR_`: the applications get SELECT and REFERENCES on XXHR_ tables too
  (19c), their synonyms follow (00c / KYC 03 drop the old ones and create the new ones), the Data Model shows them
  (COMMON prefix `XXFND_,XXHR_`), who triggers, user rename, application removal and data objects include them.
- Data security: a data object's dimension column can hold the organization ID instead of the code
  (`XXFND_DATA_OBJECTS.DIMENSION_VALUE_TYPE` CODE / ID; `REGISTER_DATA_OBJECT(..., p_dimension_value_type => 'ID')`).
  Access is still assigned by department code; the row policy and ALLOWED_VALUES use the IDs for ID columns.

## Fix (same release 102)
The first upgrade stopped in 00d (ORA-28110, policy function XXFND_APPLICATION_PKG) and 04b (ORA-04098, trigger
XXFND_USER_ROLES_USER): after the rename, the code of the installed release still named the old tables and could
not recompile before its own script recreated it. 00d now keeps synonyms with the old names
(XXFND_EMPLOYEES -> XXHR_EMPLOYEES, XXFND_ORGANIZATIONS -> XXHR_ORGANIZATIONS) while the upgrade runs; the new last
script 99z drops them. A database where the tables were already renamed gets the synonyms on the re-run.

## Deploy
App Builder > Import `COMMON-Application-APEXlang_102.zip` over COMMON (135), Install Supporting Objects: Yes
(upgrade). Then install KYC 96 (patch 119).

## Tests
APEXlang validation of the application (offline). Not run on a database, as agreed.
