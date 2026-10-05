# Patch 21 – SSO scheme uses the Fusion integration's credential (release 36)

Goes on top of patch 20 (release 35, app ID 134). App only, no database change.

Release 33 referred to the credential by a static ID that did not exist in your workspace, so the import created an
empty copy *APEX_FA_IABWBN-DEV1_DBMS_CRED (2)* and sign-in failed with `invalid_request`. The scheme
**OCI IAM Identity Domain (SSO)** now refers to the integration's credential by its real static ID
`apex-fa-iabwbn-dev1-dbms-cred` (client ID / secret from database credential `APEX$FA_IABWBN-DEV1_CRED`). The import
reuses that credential and does not change it.

## Deploy
1. Export app 134 as a backup.
2. **App Builder → Import** `KYC-Compliance-Platform-APEXlang_36.zip` → **Replace Existing Application** 134 →
   **Install Supporting Objects: No**.
3. Shared Components → Authentication Schemes → *OCI IAM Identity Domain (SSO)*: Credential Store shows
   `APEX_FA_IABWBN-DEV1_DBMS_CRED` (without "(2)"). Make it current again if you want SSO (the import makes Oracle
   Database Accounts current).
4. Workspace Utilities → Web Credentials: delete *APEX_FA_IABWBN-DEV1_DBMS_CRED (2)*.

## Tested (local Oracle 26ai + APEX 26.1, app 134)
- `apex validate` passes.
- A workspace credential with static ID `apex-fa-iabwbn-dev1-dbms-cred` (other name, client ID and secret), then the
  import: the scheme points at that credential, no new credential is created, client ID and secret are kept.
