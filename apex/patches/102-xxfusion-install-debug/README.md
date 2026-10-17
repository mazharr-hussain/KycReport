# Patch 102 - Why App Builder cannot install COMMON in XXFUSION (test application 301 and debug script)

No change to COMMON or KYC. This patch adds a test application and a read-only debug script.

## The cause (found and reproduced locally)
Choosing **Parsing Schema = XXFUSION** in App Builder > Import fails: the page goes blank and ORDS answers
`400 Not allowed to install in workspace <id> or schema XXFUSION.`

- App Builder's APEXlang import does not run in the builder's own database session. It calls ORDS:
  `PUT /ords/xxcus/_/apexlang/import` with `{"parsing_schema": "XXFUSION", ...}`.
  The path is the workspace's first schema (XXCUS), and ORDS connects as XXCUS.
- Before it installs anything, ORDS checks
  `select count(*) from apex_workspace_schemas where schema = 'XXFUSION' and workspace_id = <id>`.
- Outside an APEX session, that view shows a schema only its own row, unless the schema has the role
  **APEX_ADMINISTRATOR_READ_ROLE** (or APEX_ADMINISTRATOR_ROLE). Connected as XXCUS, the count for XXFUSION is
  therefore 0, and ORDS refuses.
- XXFUSION being assigned to the workspace, REST-enabled and reachable through ORDS_PUBLIC_USER is necessary, but
  it is not enough. A call through `/ords/xxfusion/` is refused too (401), because the builder session belongs to
  the XXCUS path.

**Fix:** one read-only grant, run by ADMIN:
```sql
grant apex_administrator_read_role to xxcus;
```
It lets XXCUS read the APEX metadata (applications, workspaces, schemas) of the instance. It gives XXCUS no right
to change anything. If you would rather not grant it, keep the current route: import as XXCUS, then switch the
parsing schema.

## Files
- `app/f301/`: APEXlang source of the test application **301 XXFTEST "XXFUSION Install Test"**.
  - Parsing schema XXFUSION, Redwood Light.
  - One page: Home, a classic report of the installs.
  - One database object: table `XXFTEST_PING`. The supporting objects create it only when it is missing, and every
    install adds one row recording the schema it ran in. The deinstall script drops the table.
  - Package to import: `apex/XXFTEST-Application-APEXlang_1.zip`.
  - The standard login page of the Oracle APEX Accounts scheme is part of the application too.
- `db/admin/debug-xxfusion-install.sql`: read-only, run as ADMIN. It prints a report (and spools
  `debug-xxfusion-install.txt`) and marks each check OK or DIFFERENT, with the fix statement for each difference.
  It checks:
  - the versions;
  - the users;
  - the workspace, its first schema and its assigned schemas;
  - the ORDS REST-enabled schemas and proxy grants;
  - **the ORDS import check** (whether the first schema has an APEX administrator role);
  - the applications per parsing schema;
  - the privileges and quota XXFUSION needs for COMMON.

## Steps on your server
1. As **ADMIN**, run `db/admin/debug-xxfusion-install.sql` and keep the report. It should show **DIFFERENT** at
   "XXCUS has APEX_ADMINISTRATOR_READ_ROLE".
2. *(Optional: see the error first.)* App Builder > Import `XXFTEST-Application-APEXlang_1.zip`, Parsing Schema =
   **XXFUSION**, Reuse Application ID 301. The page goes blank and nothing is installed.
3. As **ADMIN**: `grant apex_administrator_read_role to xxcus;`
4. App Builder > Import `XXFTEST-Application-APEXlang_1.zip` again with Parsing Schema = **XXFUSION** and Install
   Supporting Objects. Run application 301: the report shows one install with **Installed in schema = XXFUSION**.
5. Run the debug script again: "No difference found".
6. From then on, COMMON can be imported directly with **Parsing Schema = XXFUSION** and **Install Supporting Objects:
   Yes** (no switch of the parsing schema afterwards).
7. Remove application 301: App Builder > 301 > Remove Application, with its supporting objects (this drops
   XXFTEST_PING).

If step 1 shows other differences (for example XXFUSION not assigned to the workspace, or not REST-enabled), run
their fix statements first. If step 4 still fails after the grant, send the report and the wizard's error.

## Tests (local database: Oracle AI Database 26ai Free, APEX 26.1.0, ORDS 26.2.3)
- App 301 validates with the APEXlang compiler (`apex validate`).
- Without the grant, the import with XXFUSION reproduces the error. The captured call was
  `PUT /ords/xxcus/_/apexlang/import` → 400 "Not allowed to install in workspace 5998844972319208 or schema
  XXFUSION.", and nothing was installed. Run as XXCUS, the ORDS check query returns 0.
- With the grant, the same query returns 1. App 301 then imports with owner XXFUSION and its supporting objects run:
  XXFTEST_PING is created in XXFUSION, and its row says installed in XXFUSION.
- With the grant, COMMON 89 imports over application 135 directly with Parsing Schema = XXFUSION. The wizard runs
  the upgrade of the supporting objects ("Installed. You are the first Common Administrator."), application 135
  is owned by XXFUSION, and no XXFUSION or XXCUS object is invalid.
- After the grant is revoked, the debug script reports one difference, the missing role, with its fix.
- The debug script runs read-only and reports each check.
