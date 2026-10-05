# Patch 18 – SSO through the Fusion integration's identity domain settings (release 33)

Goes on top of patch 17 (release 32, app ID 134). App only, no database change.

The scheme **OCI IAM Identity Domain (SSO)** (patch 15) now uses what the Fusion Applications integration already
created in the workspace (seen in app 132, scheme `APEX_FA_IABWBN-DEV1_OAUTH`), so nothing has to be typed in:

| Setting | Value |
|---|---|
| Credential Store | `APEX_FA_IABWBN-DEV1_DBMS_CRED` (the integration's web credential: client ID and secret) |
| Discovery URL | `#FA_IABWBN-DEV1_DISCOVERY_URL#` |
| Scope | `profile,email,offline_access,groups,#FA_IABWBN-DEV1_OAUTH_SCOPE#` |
| Username | `#sub#`, **converted to upper case** (the KYC app compares user names in upper case) |
| Additional User Attributes | `given_name,middle_name,family_name,locale,zoneinfo,email` |

It is still **not the current scheme**: Oracle Database Accounts stays current until you switch.
The empty web credential *OCI IAM Identity Domain* from patch 15 is no longer used; delete it in Workspace
Utilities → Web Credentials if you like.

## Before importing: check one name
Workspace Utilities → Web Credentials → `APEX_FA_IABWBN-DEV1_DBMS_CRED` → **Static Identifier** must be
`APEX_FA_IABWBN-DEV1_DBMS_CRED`. The import matches the credential by that identifier and keeps its client ID and
secret. If it differs, tell me the identifier before importing.
Other environments (TEST, PROD) get their own integration names (not `DEV1`): the scheme is then pointed at theirs.

## Deploy
1. Export app 134 as a backup.
2. **App Builder → Import** `KYC-Compliance-Platform-APEXlang_33.zip` → **Replace Existing Application** 134 →
   **Install Supporting Objects: No**.
3. Test: private browser window → app 134 with the scheme made current in a copy, or open the scheme and use
   **Make Current Scheme** when ready; sign in with a Fusion user. Roll back by making *Oracle Database Accounts*
   current again.

## Tested (local Oracle 26ai + APEX 26.1, app 134)
- `apex validate` passes.
- A workspace credential `APEX_FA_IABWBN-DEV1_DBMS_CRED` with a client ID and secret, then the import twice: the
  scheme points at that credential (same ID), the client ID and secret are kept, no second credential is created;
  the scheme stores the discovery URL, scope, `#sub#`, upper case and attributes; Oracle Database Accounts / current
  scheme unchanged.
- The sign-in itself needs the real identity domain.
