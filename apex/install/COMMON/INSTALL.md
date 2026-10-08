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
Import the newer zip over the existing COMMON application → **Install Supporting Objects: Yes** (runs the
upgrade scripts; data is kept). The same check runs first.
