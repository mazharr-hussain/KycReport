# COMMON application – installation

Everything needed is in this zip: the application, its database scripts (Supporting Objects) and the ADMIN
script `admin/create-xxfus-schema.sql`.

## Steps
1. **App Builder → Import** this zip into the workspace (XXCUS) → new application (any free ID) →
   parsing schema **XXFUS** → **Install Supporting Objects: Yes**.
   - XXFUS must be a schema of the workspace. If it is not offered as parsing schema, run
     `admin/create-xxfus-schema.sql` as ADMIN (it creates XXFUS if needed, grants and adds it to the workspace),
     then import again.
2. The first script, **00a Prerequisites check**, checks the privileges of XXFUS. If one is missing the
   install reports **ORA-20900 ACTION NEEDED** with the exact statements, for example:
   ```
   grant execute on sys.dbms_rls to XXFUS;
   grant execute on sys.dbms_crypto to XXFUS;
   ```
   Run them as **ADMIN** (Database Actions → SQL), then come back:
   **App Builder → COMMON → Utilities → Supporting Objects → Install Supporting Objects**.
   Every script can be re-run; errors in later scripts of the failed run came from the same missing privilege.
3. Sign in to COMMON. The user who installed it is the first Common Administrator.

## Upgrade
Import the newer zip over the existing COMMON application → **Install Supporting Objects: Yes** (runs the
upgrade scripts; data is kept). The same check runs first.
