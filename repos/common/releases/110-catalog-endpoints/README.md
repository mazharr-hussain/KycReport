# COMMON 110 - Endpoints from REST Source Catalogs

Build: `releases/COMMON-Application-APEXlang_110.zip` (application version "Release 110"), on top of COMMON 109.
Built with `repos/common/build.sh --release 110`; checked with the APEXlang validation ("Validation successful"). No
database was run: the DB test `features/integrations/tests/r110_catalog_service_test.sql` is for the test database.

An API call = Remote Server (URL) + Web Credential + REST Source Catalog service (endpoint), all kept in APEX
Workspace Utilities; COMMON only maps them on the purpose.

## What changes
| Page | Change |
|---|---|
| 123 Integration Purpose | New Catalog Service select list (catalog - service (endpoint)) from `APEX_REST_CATALOG_SERVICES`. |

## Database
- `XXFND_INTEGRATION_PURPOSES.CATALOG_SERVICE_ID` (checked add, script 05b step 9).
- `XXFND_INTEGRATION_PKG.SAVE_PURPOSE`: P_CATALOG_SERVICE_ID (default null).
- `XXFND_INTEGRATION_PKG.CALL`: with a catalog service, URL = the purpose's server URL + the service endpoint path (the
  endpoint's own host is replaced, so each environment uses its own Remote Server; no server = endpoint as is);
  credential = the server's Web Credential, else the catalog's `CREDENTIAL_STATIC_ID`. Without a catalog service the
  REST Data Source is used as before. ORA-20312 when the purpose has neither.

## Deploy
App Builder > Import `COMMON-Application-APEXlang_110.zip` over COMMON (135), Install Supporting Objects = Yes; or run
`run-release.sql` as XXFUSION, then import the application. A re-run changes nothing.

## Live checks
1. Purposes > a purpose: Catalog Service lists the services of your REST Source Catalogs; pick one with the Fusion
   server and save.
2. The purpose's call goes to `<Fusion Remote Server URL>/<service endpoint path>` (Integration Calls log).
