# KYC Compliance Platform – installation

One package: `KYC-Compliance-Platform-APEXlang_<N>.zip` - the application with its database scripts (Supporting
Objects).

## Before you start
The shared objects (security, lookups, flexfields, attachments, workflow: `XXFND_`) live only in **XXFUSION**,
installed by the **COMMON** application. XXCUS keeps the KYC objects (`XXCMP_`) and reaches the shared ones through
synonyms. So **import COMMON first** (same release, parsing schema XXFUSION, Install Supporting Objects: Yes), then KYC.
On the first KYC import of release 54 or later, KYC's own copy of the shared data moves to XXFUSION once (all IDs
kept). The import checks that every column exists and that the row counts match; only then does it drop XXCUS's copy
and create the synonyms.

## Steps
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
3. If COMMON was not installed first, the install reports **ORA-20902 ACTION NEEDED** (script 03) and installs
   nothing else. Import COMMON, then come back: **Utilities → Supporting Objects → Install Supporting Objects**
   (or **Upgrade**).
