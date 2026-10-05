# Patch 15 – OCI IAM Identity Domain sign-in (release 30)

Goes on top of patch 14 (release 29, app ID 134). It adds an authentication scheme that signs users in with the
same OCI IAM identity domain as Oracle Fusion, so one identity (and single sign-on) works for both. **It is not made
the current scheme:** the app keeps *Oracle Database Accounts* until you switch it.

## What it adds
- Authentication scheme **OCI IAM Identity Domain (SSO)**: Social Sign-In, OpenID Connect, discovery URL of the
  identity domain, scope `openid,email,profile`, user name = `#sub#` (the identity domain user name, the same as in
  Fusion), converted to upper case. It must match `XXFND_EMPLOYEES.USER_NAME`, which the HCM sync fills from Fusion.
- Web credential **OCI IAM Identity Domain** (OAuth2 client credentials): holds the client ID and secret.
- No database change.

## Set up (once)
1. **OCI Console → Identity & Security → Domains →** the domain used by Fusion **→ Integrated applications → Add →
   Confidential Application**.
   - Grant types: **Authorization Code**.
   - Redirect URL: `https://<your-apex-host>/ords/apex_authentication.callback`
   - Post-logout redirect URL (optional): the app's home URL.
   - Activate it, then copy the **Client ID** and **Client Secret**.
   - Note the domain URL (`https://idcs-<id>.identity.oraclecloud.com`).
2. Import `KYC-Compliance-Platform-APEXlang_30.zip` → **Replace Existing Application** 134 →
   **Install Supporting Objects: No**.
3. **Workspace Utilities → Web Credentials → OCI IAM Identity Domain**: enter the Client ID and Client Secret.
4. **Shared Components → Authentication Schemes → OCI IAM Identity Domain (SSO)**: set **Discovery URL** to
   `https://idcs-<id>.identity.oraclecloud.com/.well-known/openid-configuration` (it ships with `idcs-REPLACE`).
5. Test before switching: on the scheme page use **Make Current Scheme** only when ready; to roll back, make
   *Oracle Database Accounts* current again.

## Tested (local Oracle 26ai + APEX 26.1, app 134)
- `apex validate` passes; the import creates the scheme (settings stored: provider OpenID Connect, discovery URL,
  scope, user name `#sub#`, upper case, credential) and the web credential; the current scheme is unchanged.
- The sign-in itself needs a real identity domain; it cannot be tested locally.
