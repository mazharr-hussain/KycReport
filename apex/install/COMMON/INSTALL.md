# COMMON application – installation

One package: `COMMON-Application-APEXlang_<N>.zip` - the application with its database scripts (Supporting
Objects). The ADMIN script, needed only when XXFUSION does not exist yet, is `apex/db/admin/create-xxfusion-schema.sql`
in the repository.

## Steps
1. **App Builder → Import** the application zip into the workspace (XXCUS) → new application (any free ID).
   On the Install step set **Parsing Schema = XXFUSION**. The export already names XXFUSION, so it is preselected
   when XXFUSION is a schema of the workspace. Do not leave it at the workspace default XXCUS.
   Then set **Install Supporting Objects: Yes**.
   - If XXFUSION is not in the list, run `apex/db/admin/create-xxfusion-schema.sql` as ADMIN (it creates XXFUSION if
     needed, grants and adds it to the workspace), then import again.
   - Imported with another parsing schema, the install does nothing except report **ORA-20901 ACTION NEEDED**
     (script 00b). Fix it: **App Builder → COMMON → Edit Application Definition → Security → Database Session →
     Parsing Schema = XXFUSION → Apply Changes**, then **Utilities → Supporting Objects → Install Supporting
     Objects**.
2. The first script, **00a Prerequisites check**, checks the privileges of XXFUSION. If one is missing the
   install reports **ORA-20900 ACTION NEEDED** with the exact statements, for example:
   ```
   grant execute on sys.dbms_rls to XXFUSION;
   grant execute on sys.dbms_crypto to XXFUSION;
   ```
   Run them as **ADMIN** (Database Actions → SQL), then come back:
   **App Builder → COMMON → Utilities → Supporting Objects → Install Supporting Objects**.
   Every script can be re-run; errors in later scripts of the failed run came from the same missing privilege.
3. Sign in to COMMON. The user who installed it is the first Common Administrator.

## Order with the business applications
The shared XXFND_ objects live only in XXFUSION; KYC (XXCUS) reaches them through synonyms and grants. Always
install / upgrade **COMMON first**, then KYC.

## Upgrade
Import the newer zip over the existing COMMON application → **Install Supporting Objects: Yes** (runs the
upgrade scripts; data is kept). The same check runs first.
