# COMMON application – installation

One package: `COMMON-Application-APEXlang_<N>.zip` - the application with its database scripts (Supporting
Objects). The ADMIN script, needed only when XXFUSION does not exist yet, is `apex/db/admin/create-xxfusion-schema.sql`
in the repository.

## Steps
1. **App Builder → Import** the application zip into the workspace → **Parsing Schema = XXCUS** (App Builder's
   APEXlang install runs as the REST-enabled schema XXCUS; choosing XXFUSION there fails with ORDS
   "Not allowed to install in workspace ... or schema XXFUSION" and the page goes blank) →
   **Install Supporting Objects: No**.
   Then: **App Builder → COMMON → Edit Application Definition → Security → Database Session → Parsing Schema =
   XXFUSION → Apply Changes**, then **Utilities → Supporting Objects → Install Supporting Objects**.
   - If XXFUSION is not in the list, run `apex/db/admin/create-xxfusion-schema.sql` as ADMIN (it creates XXFUSION if
     needed, grants and adds it to the workspace).
   - Installed while the parsing schema is still XXCUS, the scripts do nothing except report **ORA-20901 ACTION
     NEEDED** (script 00b); switch the parsing schema as above and install again.
2. The first script, **00a Prerequisites check**, checks the privileges of XXFUSION. If one is missing the
   install reports **ORA-20900 ACTION NEEDED** with the exact statements, for example:
   ```
   grant execute on sys.dbms_rls to XXFUSION;
   grant execute on sys.dbms_crypto to XXFUSION;
   ```
   Run them as **ADMIN** (Database Actions → SQL), then come back:
   **App Builder → COMMON → Utilities → Supporting Objects → Install Supporting Objects**.
   Every script can be re-run; errors in later scripts of the failed run came from the same missing privilege.
3. Sign in to COMMON. The user who installed it is the first Common Administrator. COMMON is for IT only (release 71):
   only users with the role Common Administrator (COMMON_ADMIN) can sign in; give it to the IT administrators.

## Order with the business applications
Order: COMMON → (once) the ADMIN move script → KYC. Since release 68 KYC opens the shared setup screens in COMMON.

The shared XXFND_ objects live only in XXFUSION; KYC (XXCUS) reaches them through synonyms and grants. Always
install / upgrade **COMMON first**, then KYC.

## Upgrade
Import the newer zip over the existing COMMON application the same way as step 1: **Parsing Schema = XXCUS**,
**Install Supporting Objects: No**; then **Edit Application Definition → Security → Parsing Schema = XXFUSION →
Apply Changes**, then **Utilities → Supporting Objects → Install Supporting Objects** (runs the upgrade scripts;
data is kept). The same prerequisites check runs first.

Delegated administration (release 73): IT can let an application's administrators maintain a common function for
their application (COMMON → Applications → the application → Managed in the Application). They open it from their
own application's Administration menu, in a dialog, signed in through the shared session - not by signing in to
COMMON.

## Install or upgrade from SQL Developer Web (release 74)
Instead of the import steps above: as **ADMIN**, Database Actions → SQL → open
`COMMON-Application-SQL-Install_<N>.sql` → **Run Script (F5)**. The script sets the workspace (XXCUS), the application
ID (135) and the parsing schema (**XXFUSION** - no manual switch), runs the supporting objects (install scripts on a
new database, upgrade scripts on an existing one; data kept) and installs the application. Then run the KYC script of
the same release. Release 74 needs no new database privilege.


## Release 76 (COMMON + KYC)
Install COMMON 76 first and wait until it has finished, then KYC 76 (KYC stops with ORA-20904, changing nothing, when COMMON 76 is not there yet). From this release the delivery is the APEXlang zip of each application (App Builder import) - no SQL Developer Web install script. QD only, once after both: run `apex/db/admin/qd-users-and-roles.sql` connected as XXFUSION (users and roles; first password Welcome#2026, changed at first sign-in). Upgrades no longer give back a privilege removed from a role in the console.


## Release 78 (COMMON)
Release 78 (COMMON only, patch 85): COMMON is organised into six modules (Platform, Security, Reference Data,
Documents and Records, Workflow, Integrations). The menu is Home and the six modules; a module opens its page with its
components; Home shows the modules with their state; Approval Setup and Optional Features have their own menu entries
(rights copied from Workflow Setup / Application Settings); new page Subscriptions under Platform > Applications.
Upgrade as usual (Install Supporting Objects, upgrade scripts). KYC is not changed.

## Release 77 (COMMON)
Release 77 (COMMON only): removes the unchanged release 76 error-log retention policy; no retention policy is seeded any more. Independent of KYC 77.
