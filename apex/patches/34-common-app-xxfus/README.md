# Patch 34 – COMMON application on the XXFUS schema (release 49)

Step 2 of the common module. A second application, **COMMON** (code and alias COMMON), runs on the new
schema **XXFUS** and installs the shared XXFND_ objects there through its own Supporting Objects. KYC is unchanged
for users; it still uses its own XXFND_ copy in XXCUS until step 3 moves the data and replaces it with synonyms.

## What changes
- **XXFUS schema**: `db/admin/create-xxfus-schema.sql` (one-time DBA step) creates the user, its privileges
  (as XXCUS: tables, views, procedures, triggers, types, jobs, `DBMS_RLS`, `DBMS_CRYPTO`) and adds it to the
  APEX workspace.
- **COMMON application** (`src/database/xxfus/apex_apps/f135`, parsing schema XXFUS, Redwood Light):
  Home (registered applications), Login, the same three authentication schemes as KYC (all calling
  `xxfnd_auth_pkg`), authorization `app-user` / `page-view`. The admin and workflow setup screens move here in
  step 5.
- **Supporting objects of COMMON** (`manifest.json` field `apps`): the 23 shared scripts (00–15, 16h, 16j, 17,
  19) plus `20-common-seed.sql`: role **COMMON_ADMIN**, feature **COMMON_HOME** (page 1), and the installer as
  the first Common Administrator.
- Shared scripts made application-neutral:
  - 17 seeds a KYC lookup only where KYC is installed (XXFUS gets the shared lookups only).
  - `xxfnd_auth_pkg`: the KYC party-details rule is called dynamically; new scheme name `APP_USER`.
  - `xxfnd_security_pkg.bootstrap_admin` takes the role (default SYSTEM_ADMIN).
- `tools/build.py` builds both applications' supporting objects and release zips.

## Deploy – two application imports
1. Once per environment, as ADMIN: run `db/admin/create-xxfus-schema.sql` (it asks for the XXFUS password, the
   tablespace – `DATA` on ATP – and the workspace).
2. **App Builder → Import** `COMMON-Application-APEXlang_49.zip` → new application (any free ID) → parsing schema
   **XXFUS** → **Install Supporting Objects: Yes**.
3. **App Builder → Import** `KYC-Compliance-Platform-APEXlang_49.zip` → **Replace Existing Application** 134 →
   **Install Supporting Objects: Yes**.

## Tested (local Oracle 26ai + APEX 26.1)
- Clean install of the 24 COMMON scripts into an empty XXFUS: no errors, no invalid objects; only the shared
  lookups; COMMON_ADMIN granted to the installer.
- COMMON imported as app 135 (owner XXFUS); `common_ui.py`: ADMIN opens Home and sees COMMON (APEX ID synced
  at sign-in) and KYC; REQ2 (KYC access only) is refused.
- KYC: all upgrade scripts in APEX order with no errors and no invalid objects; `request_party_ui.py` (party-details rule for the requester).
