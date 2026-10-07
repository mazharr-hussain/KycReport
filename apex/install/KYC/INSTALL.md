# KYC Compliance Platform – installation

This install pack holds everything needed:
- `KYC-Compliance-Platform-APEXlang_<N>.zip` - the application with its database scripts (Supporting Objects).
  **Import this file**, not the pack itself (App Builder accepts only the application zip).
- this INSTALL.md.

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
