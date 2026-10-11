# KYC Compliance Platform – installation

One package: `KYC-Compliance-Platform-APEXlang_<N>.zip` - the application with its database scripts (Supporting
Objects).

## Before you start
The shared objects (security, lookups, flexfields, attachments, workflow: `XXFND_`) live only in **XXFUSION**,
installed by the **COMMON** application. XXCUS keeps the KYC objects (`XXCMP_`) and reaches the shared ones through
synonyms. So **import COMMON first** (same release, parsing schema XXFUSION, Install Supporting Objects: Yes), then KYC.
An existing KYC (installed before release 54) still has its own copy of the shared data in XXCUS. Moving it is a
**one-time ADMIN activity**, not part of the package: run `apex/db/admin/move-kyc-shared-data-to-xxfusion.sql` once
as ADMIN, after the COMMON import and before the KYC import (step 0).

## Where the setup screens are (release 68)
The shared setup screens (users and access, roles, lookups, notifications, flexfields, attachments setup,
integration, workflow setup, audit log, retention) are in the **COMMON** application. KYC's Administration menu opens
them in COMMON for KYC - same sign-in (workspace session sharing), only KYC's data. KYC's own setup screens (KYC
rules, mandatory documents, approval matrix, alert rules, workflow monitor, settings) stay in KYC.

## Steps
0. **Existing KYC only, once:** as **ADMIN** (Database Actions → SQL) run
   `apex/db/admin/move-kyc-shared-data-to-xxfusion.sql`. It first **validates** (XXFUSION ready, every shared table
   and column present in XXFUSION, every object it would drop has its replacement there, foreign-key targets exist)
   and changes nothing if a check fails: it lists every problem (ORA-20904); fix them and run it again. Then it
   moves the data (all IDs kept, row counts compared), drops XXCUS's copy, creates the synonyms, re-creates the
   foreign keys and re-points the data security. A new installation skips this step.
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
   installs nothing else. Do step 0, then come back: **Utilities → Supporting Objects → Install Supporting Objects**
   (or **Upgrade**).
4. If COMMON was not installed first, the install reports **ORA-20902 ACTION NEEDED** (script 03) and installs
   nothing else. Import COMMON, then come back: **Utilities → Supporting Objects → Install Supporting Objects**
   (or **Upgrade**).

## Shared setup (release 72)
The shared setup (lookups, flexfields, attachments, notifications, roles and users, data security...) is maintained by IT
in the COMMON application, which only IT can open. IT switches on which common functions KYC may use (COMMON >
Administration > Applications > KYC); a function switched off disappears from KYC. KYC's Administration keeps only
KYC's own setup screens.

## Install or upgrade from SQL Developer Web (release 74)
Instead of the import step: after the COMMON script of the same release, as **ADMIN**, Database Actions → SQL → open
`KYC-Compliance-Platform-SQL-Install_<N>.sql` → **Run Script (F5)**. The script sets the workspace (XXCUS), the
application ID (134) and the parsing schema (XXCUS), runs the supporting objects (install scripts on a new database,
upgrade scripts on an existing one; data kept) and installs the application. Release 74 needs no new database
privilege.

## Release 75 (KYC only)
COMMON is not changed: keep COMMON at release 74 and import (or run the SQL install script of) KYC release 75 only.
Wait until the COMMON install has finished before installing KYC (KYC uses COMMON's objects); if KYC was installed
while COMMON was still running, run KYC again - every script is idempotent. Release 75 adds the column
XXCMP_REQUESTS.CASE_ASSIGNEE (checked step 16w) and needs no new database privilege. Open investigation tasks created
before release 75 keep their business administrators (workflow administrators): only they can reassign those cases;
cases opened from release 75 on can be reassigned by Cases managers and the assignee.
