# KYC Compliance Platform – installation

This install pack holds everything needed:
- `KYC-Compliance-Platform-APEXlang_<N>.zip` - the application with its database scripts (Supporting Objects).
  **Import this file**, not the pack itself (App Builder accepts only the application zip).
- `migrate/move-kyc-shared-data-to-xxfusion.sql` - one-time move of KYC's shared data to XXFUSION (existing KYC only).
- this INSTALL.md.

## Before you start
The shared objects (security, lookups, flexfields, attachments, workflow: `XXFND_`) live only in **XXFUSION**,
installed by the **COMMON** application. XXCUS keeps the KYC objects (`XXCMP_`) and reaches the shared ones through
synonyms. So **import COMMON first** (same release, parsing schema XXFUSION, Install Supporting Objects: Yes), then KYC.
An existing KYC (installed before release 54) still has its own copy of the shared data in XXCUS. Moving it is a
**separate step**, done once between the two imports (see step 0).

## Steps
0. **Only for an existing KYC, once:** after the COMMON import, run the move script as XXCUS:
   **SQL Workshop → SQL Scripts → Upload** `migrate/move-kyc-shared-data-to-xxfusion.sql` → **Run**.
   It copies the shared data to XXFUSION (keeping all IDs), checks that every column exists and that the row counts
   match, and only then drops the XXCUS copy and creates the synonyms. If it stops with an error, nothing is dropped;
   fix the cause and run it again. A new installation skips this step.
1. **App Builder → Import** the application zip into the workspace (XXCUS) → **Replace Existing Application** (or a new
   application on a first install), parsing schema **XXCUS** → **Install Supporting Objects: Yes**.
2. The first script, **00a Prerequisites check**, checks the privileges of XXCUS. If one is missing the
   install reports **ORA-20900 ACTION NEEDED** with the exact statements to run, for example:
   ```
   grant execute on sys.dbms_rls to XXCUS;
   ```
   Run them as **ADMIN** (Database Actions → SQL), then come back:
   **App Builder → KYC Compliance Platform → Utilities → Supporting Objects → Install Supporting Objects**
   (or **Upgrade**). Every script can be re-run; errors in later scripts of the failed run came from the same
   missing privilege.
3. If step 0 was not done on an existing KYC, the install reports **ORA-20903 ACTION NEEDED** (script 03) and
   installs nothing else. Run the move script (step 0), then come back:
   **Utilities → Supporting Objects → Install Supporting Objects** (or **Upgrade**).
4. If COMMON was not installed first, the install reports **ORA-20902 ACTION NEEDED** (script 03) and installs
   nothing else. Import COMMON, then come back: **Utilities → Supporting Objects → Install Supporting Objects**
   (or **Upgrade**).
