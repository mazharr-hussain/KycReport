# Patch 115 - COMMON 100: Fusion / IDCS from the workspace prerequisite; APEX accounts first, SSO on the login page (issue 17)

Build: `COMMON-Application-APEXlang_100.zip` (application version "Release 100"). COMMON only. Install COMMON 99 (patch 114)
first.

## Prerequisite (not managed by COMMON)
The Fusion integration of the workspace (identity domain, Fusion server and credential) is set up with the Fusion app
installation: remote server `APEX_FA_IABWBN-DEV1_REST_APIS` (https://iabwbn-dev1.fa.ocs.oraclecloud.com/) and credential
`APEX_FA_IABWBN-DEV1_DBMS_CRED` (OAuth2 client credentials). COMMON uses them as they are: the IDCS and Fusion URLs and
secrets are owned by that setup, not by COMMON. In another environment whose prerequisite uses other names, the
administrator picks the workspace's Fusion credential once in App Builder (authentication scheme
APEX_FA_IABWBN-DEV1_OAUTH and REST Data Source Fusion HCM Workers); no URL or secret is entered in COMMON.

## What changes
- **Sign-in:** the current scheme is **Oracle APEX Accounts** again, so COMMON works even when the company account
  (SSO) does not; the login page keeps **Sign in with company account** (scheme APEX_FA_IABWBN-DEV1_OAUTH, Switch in
  Session, the workspace credential APEX_FA_IABWBN-DEV1_DBMS_CRED). The shared login page and the return to the calling
  application (P9999_APP) stay as in COMMON 99.
- **No COMMON Fusion placeholders:** the remote server FUSION and the credential Fusion Credentials
  (your-fusion-host.oraclecloud.com) are removed from the application. The REST Data Source Fusion HCM Workers uses the
  workspace's server APEX_FA_IABWBN-DEV1_REST_APIS and credential APEX_FA_IABWBN-DEV1_DBMS_CRED.
- **Servers (script 29):** COMMON's server FUSION uses the workspace credential; an existing FUSION server still on
  FUSION_CREDENTIALS is moved to it.
- The old workspace server FUSION and credential Fusion Credentials stay in the workspace (an import does not delete
  workspace components); remove them in Workspace Utilities > Remote Servers / Web Credentials when nothing uses them.

## Files
- `app/application.apx` (Release 100, current scheme Oracle APEX Accounts)
- `app/shared-components/rest-data-sources/fusion-hcm-workers.apx`
- `app/workspace-components/rest-data-source-servers/apex-fa-iabwbn-dev1-rest-apis.apx` (the prerequisite's server, as
  it is); removed from the application: `workspace-components/rest-data-source-servers/fusion.apx`,
  `workspace-components/credentials/fusion-credentials.apx`
- `db/29-servers.sql`

## Deploy
App Builder > Import `COMMON-Application-APEXlang_100.zip` over COMMON (135), Install Supporting Objects: Yes.

## Tests
APEXlang validation passed. Not run (as agreed).
