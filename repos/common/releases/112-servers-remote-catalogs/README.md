# COMMON 112 - Servers linked to APEX Remote Servers, REST Source Catalogs, Fusion Objects removed

Build: `releases/COMMON-Application-APEXlang_112.zip` (application version "Release 112"), on top of COMMON 111.
Built with `repos/common/build.sh --release 112`; checked with the APEXlang validation ("Validation successful"). No
database was run: the DB test `features/integrations/tests/r112_server_link_test.sql` is for the test database.

## What changes
| Screen | Change |
|---|---|
| 121 Server | Static ID (typed once, read-only after) + **APEX Remote Server** (the link). Server name and URL are read live from the Remote Server (a change in Workspace Utilities shows at once). Web Credential picked from the workspace's credentials. New **REST Source Catalogs** (shuttle) and **Last Call**. New list **REST Data Sources on this Server** (COMMON and every other application of the workspace). Removed: Fusion Integration Application and Web Credential (from the application). Type, Description, Enabled, State, Last Test, Last Error as before. |
| 120 Servers | New column APEX Remote Server. APEX Remote Servers list: new column **COMMON Server** - opens the linked server, or **Add** opens the Server form filled in from the Remote Server. |
| 123 Purpose | Catalog Service lists only the services of the server's catalogs. |
| Fusion Objects | Removed (pages 190-194, automation, REST Data Source FUSION_ROOT, menu entry, feature, purpose, template, messages, packages). Endpoints now come from the REST Source Catalogs. |

## Database
- `XXFND_SERVERS.REMOTE_SERVER_CODE` (checked add, 05b step 10); empty = the Remote Server of its own static ID.
- `XXFND_SERVERS.SOURCE_APPLICATION_ID` dropped (checked, 05b step 11).
- New table `XXFND_SERVER_CATALOGS` (server - catalog), kept by `XXFND_INTEGRATION_PKG.SET_SERVER_CATALOGS`.
- `XXFND_SERVERS_V`: name and URL from the linked Remote Server; Last Call / Last Error / Last Test under the server code or
  its Remote Server's static ID; new columns REMOTE_SERVER_CODE, REMOTE_SERVER_NAME; the Fusion application route is gone.
- `XXFND_INTEGRATION_PKG.SAVE_SERVER`: P_REMOTE_SERVER_CODE (P_SOURCE_APPLICATION_ID removed); the stored name is only the
  fallback of a Remote Server that is gone.
- Script `41c-fusion-objects-removal`: takes back what 40z registered, drops the engine packages, and drops each engine
  table only while it is empty (a table with rows, and any generated replica, is kept). The old 40a-40z scripts are no
  longer part of the install.

## Deploy
App Builder > Import `COMMON-Application-APEXlang_112.zip` over COMMON (135), Install Supporting Objects = Yes; or run
`run-release.sql` as XXFUSION, then import the application. A re-run changes nothing.

## After install
Open the FUSION server, pick the APEX Remote Server `apex-fa-iabwbn-dev1-rest-apis` and your Fusion Web Credential, add its
REST Source Catalogs, and save: the URL shows and the state becomes OK.
