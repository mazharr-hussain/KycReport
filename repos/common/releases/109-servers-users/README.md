# COMMON 109 - Servers from APEX, user account lock

Build: `releases/COMMON-Application-APEXlang_109.zip` (application version "Release 109"), on top of COMMON 108.
Built with `repos/common/build.sh --release 109`; checked with the APEXlang validation ("Validation successful"). No
database was run: the DB test `features/integrations/tests/r109_servers_users_test.sql` is for the test database.

## What changes
| Page | Change |
|---|---|
| 120 Servers | Read-only lists of the workspace's APEX Remote Servers and Web Credentials (created in Workspace Utilities; COMMON only maps them). |
| 121 Server | Remote Server and Web Credential picked from APEX (as before). OCI Region and Namespace are read from the Remote Server URL (`https://objectstorage.<region>.oraclecloud.com/n/<namespace>`), no longer typed. SharePoint / Outlook: the OAuth token URL comes from an APEX Remote Server of type Authentication (new select list), no longer typed. |
| 103 Users | New columns Account (Active / Locked / SSO) and Failed Sign-ins. |
| 104 User | Account (with failed sign-ins); Unlock Account (when locked) and Lock Account (when active) - the user stays enabled. Users & Access - Manage. |

## Database
- `XXFND_SERVERS.AUTH_SERVER_CODE` (checked add, script 05b step 7).
- `XXFND_SERVERS_V`: token URL from the Authentication Remote Server, region / namespace from the Remote Server URL;
  the values typed on older servers stay as the fallback.
- `XXFND_INTEGRATION_PKG.SAVE_SERVER`: P_AUTH_SERVER_CODE; a value not given keeps the stored one.
- `XXFND_ATTACH_PKG`: an Object Storage URL that already ends with /n/<namespace> is not given the namespace twice.
- `XXFND_USER_PKG`: ACCOUNT_STATUS, FAILED_SIGN_INS, LOCK_ACCOUNT.
- Endpoints stay the REST Data Sources of COMMON (built from the REST Source Catalogs). Reading the catalogs directly
  can be added once the catalog dictionary view of APEX 26.1 is confirmed on the server (`select view_name from
  all_views where view_name like 'APEX%CATALOG%'`).

## Deploy
App Builder > Import `COMMON-Application-APEXlang_109.zip` over COMMON (135), Install Supporting Objects = Yes; or run
`run-release.sql` as XXFUSION, then import the application. A re-run changes nothing.

## Live checks
1. Servers: the two APEX lists show your Remote Servers and Web Credentials; the FUSION server shows the URL of the
   Remote Server created by the Fusion setup.
2. Users: a locked user shows Locked; Unlock Account opens it.
