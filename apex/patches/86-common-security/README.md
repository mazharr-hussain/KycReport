# Patch 86 - COMMON: Security module (release 79, COMMON only - C2 Security)

## What changes
- **One package per component.** `XXFND_SECURITY_PKG` and `XXFND_AUTH_PKG` are dropped (checked
  `XXFND_DDL_PKG.DROP_OBJECT`: their DDL and dependents are recorded in `XXFND_DROPPED_OBJECTS`). Their code now lives in
  `XXFND_USER_PKG` (users, sign-in, rename, first administrator, post-authentication, the authorization-scheme entry),
  `XXFND_PRIVILEGE_PKG` (roles, segregation of duties) and the new `XXFND_INTEGRATION_PKG` (Fusion HCM worker sync).
  **The KYC application stops working until its own release uses the new names** (decided: no wrappers).
- **Data access rules are assigned to users and to roles** (`XXFND_DATA_RULE_ASSIGNMENTS`). Every existing rule keeps
  its role as its first assignment. A user sees the rows of any rule assigned to them or to one of their active roles
  (access adds up). A create list offers the "column in list" values even when the user also has own records.
- **Three linked screens, one Assign dialog.** User (record on top; tabs Roles and privileges / Data access with the
  Effective access), Role (tabs Users / Data access) and Data access rule (tabs Users / Roles; the rule no longer has a
  single role field). Every Assign opens the same picker (page 183: search, select several, assign); Remove ends a
  grant or an assignment. The Users list shows each user's roles, data access tables and language.
- **Language preference** on every user (`XXFND_USERS.LANGUAGE_CODE`, default English).
- **Super Administrator** role (`SUPER_ADMIN`, holds Workflow Monitor - Manage, so it is the business administrator of
  every task); nobody holds it until it is granted from the console.
- New checked DDL step `XXFND_DDL_PKG.SET_NULLABLE`; the unique index of the rules now includes the values
  (`XXFND_DATA_SECURITY_RULES_U2` replaces `_U1`).

## Files
- `db/`: 00, 01 (comment), 04b, 05 and 05 upgrade, 05b (new), 08, 09b, 09c, 16j (renamed `16j-user-pkg.sql`), 17
  (comment), 19c, 23 (new), `manifest.json`, `admin/qd-users-and-roles.sql`
- `app/`: `application.apx` (Release 79), pages 103 (Users and Access), 104 (User), 106, 180, 181, 183 (new),
  shared components `authentications.apx`, `authorizations.apx`, `breadcrumbs.apx`

## Deploy (COMMON only)
Import `COMMON-Application-APEXlang_79.zip` over COMMON with **Parsing Schema = XXCUS** and
**Install Supporting Objects: No**; then Edit Application Definition > Security > **Parsing Schema = XXFUSION** >
Apply Changes; then Utilities > Supporting Objects > **Install Supporting Objects** (upgrade scripts; data kept).
Then run `apex/db/admin/qd-users-and-roles.sql` as XXFUSION (QD users: Requester + department rules per user; the
release 76 department roles are disabled). A re-run changes nothing.

## Tests
`apex/tests/r79_security_test.sql` (as XXFUSION) and `apex/tests/r79_security_ui.py`.
