# Patch 111 - COMMON 96: security model (roles, privileges, data access) and its screens

Build: `COMMON-Application-APEXlang_96.zip` (application version "Release 96"). COMMON only; KYC's pages and packages
are not changed (its data access is moved by the migration script). Install COMMON 95 (patch 110) first.

## What changes
- **Roles** are any mix of roles inside them (XXFND_ROLE_MEMBERS, loops refused), privileges and data access.
- **Privileges** (View / Create / Manage per feature) control screens and actions, as before - now through the role tree.
- **Data access** controls which records only, and is given **through roles only**:
  - a data object (a table) has a dimension column (e.g. Department) and / or an owner column;
  - a role reaches a data object with ALL records, given VALUES, or OWN records (XXFND_ROLE_DATA_ACCESS);
  - the values sit on the user's role assignment per dimension (default, every object of the dimension) with an
    override per data object (XXFND_ASSIGNMENT_VALUES) - e.g. many departments for requests, one for cases.
- **Organizations** (departments, ...) are the dimension values (XXFND_ORGANIZATIONS: few columns now, filled later by the
  HCM API).
- **Users are linked to applications** (XXFND_USER_APPLICATIONS; one user, several applications). Where an application
  manages its users itself, only that application's roles are read-only in COMMON.
- **Every row belongs to an application:** the COMMON administrator sees and manages all; an application
  administrator acts only on their application's rows.
- **Migration (script 35, runs once):** today's data access rules become data objects, role data access and assignment
  values; the release 76 roles REQUESTING_FINANCE / REQUESTING_PROCUREMENT are removed; users get their applications.
  The old rule tables stay, read only. The row policy (XXFND_DATA_SECURITY) uses the model for every data object.

## Screens
- User (104): title and breadcrumb name the user; Applications (End); roles with their data access values, Managed,
  Values (opens 184) and Remove; effective data access from the model. The direct rules region is removed.
- Role (106): tab "Roles inside" (add / remove); Data access (object, level; add / remove) replaces the rules.
- Data Security (180): Data Objects and Dimensions; Organizations button. Data Object (181): its columns and the roles
  reaching it, Give Access. Data Access Values (184, new drawer): default and per-object values, Change in the same
  drawer. Organizations (186, new).

## Files
- `db/`: 09a-security-model.sql (new), 09b-security-framework-objects.sql, 09d-application-pkg.sql, 16j-user-pkg.sql,
  19c-share-with-applications.sql, 21c-setup-types.sql, 35-security-model-migration.sql (new), manifest.json
- `app/`: application.apx, pages 104, 106, 180, 181, 184 (new), 186 (new), shared-components/breadcrumbs.apx
- `tests/`: r96_security_test.sql, r96_security_ui_setup.sql, r96_security_ui.py, r96_security_ui_cleanup.sql

## Deploy
App Builder > Import `COMMON-Application-APEXlang_96.zip` over COMMON (135), Install Supporting Objects: Yes
(upgrade: 09a, 09b, 09d, 16j, 19c, 21, 21c, 35 run; a re-run changes nothing).

## Tests (local database, COMMON 96)
- `r96_security_test.sql` (XXFUSION, rolled back): 13/13 pass - default and override values, roles inside roles, loop
  refused, access lost with the role, another application's role refused, department roles removed.
- Migration check: effective access before and after the migration compared - no difference.
- KYC flow test (kyc_flow_test.sql): 23/23 pass on the migrated data; XXCUS recompiles clean.
- Browser, as ADMIN (`r96_security_ui_setup.sql`, then `r96_security_ui.py`, then `r96_security_ui_cleanup.sql`):
  10/10 pass - User page, breadcrumb, Applications, Values drawer, default and override saved, Data Security, Data
  Object roles, Role tabs, Organizations.

## Later (KYC changes, done in one go after COMMON)
- KYC registers its data objects on the Department dimension; cases have no department column yet.
- KYC messages still mention the "Requesting Entity role".
