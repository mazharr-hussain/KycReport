# Patch 30 – one package for authentication and authorization (release 45)

Goes on top of any earlier release of app 134.

## What changes
- **XXFND_AUTH_PKG** (new, script 16j) holds all the sign-in and access logic; the application only calls it:
  - `post_auth_local` – post-authentication of Oracle APEX Accounts and Oracle Database Accounts (the e-mail login
    becomes the employee's user name).
  - `post_auth_sso` – post-authentication of the identity-domain scheme: the same mapping, then
    `load_user_roles` (your `fa_get_user_roles`): the user's Fusion roles (REST Data Source
    `common-features-user-roles`) and identity-domain groups into the collection `FA_USER_ROLES` and APEX dynamic
    groups.
  - `authorized('<SCHEME>')` – the rule of every authorization scheme (KYC User, Page View / Create / Manage /
    Submit, Workflow Administer, Admin Area, Party Details View / Create / Manage / Submit); each scheme is now
    `return xxfnd_auth_pkg.authorized('...');`. `in_group(<group>)` for Fusion roles / identity-domain groups.
- **Identity-domain scheme aligned with application 132:** name and static ID **APEX_FA_IABWBN-DEV1_OAUTH** /
  `apex-fa-iabwbn-dev1-oauth` (was *OCI IAM Identity Domain (SSO)*), Convert Username To Upper Case **No**,
  Additional User Attributes mapped to **G_GIVEN_NAME, G_MIDDLE_NAME, G_FAMILY_NAME, G_LOCALE, G_ZONEINFO,
  G_EMAIL** (new application items), Switch in Session **Disabled**, post-authentication `xxfnd_auth_pkg.post_auth_sso`
  (no PL/SQL in the scheme). Same credential, discovery URL, scope and username `#sub#`.

## Open point
The REST Data Source **common-features-user-roles** exists in application 132, not in 134. Until it is added to
134, `load_user_roles` skips the Fusion roles (debug warning) and uses the identity-domain groups only. Send its
definition (URL / endpoint, credential, parameters, columns) and it will be added to the application.

## Deploy – application import only
1. **App Builder → Import** `KYC-Compliance-Platform-APEXlang_45.zip` → **Replace Existing Application** 134 →
   **Install Supporting Objects: Yes**.
2. If you sign in with the identity domain: Shared Components → Authentication Schemes →
   **APEX_FA_IABWBN-DEV1_OAUTH** → **Make Current Scheme** (the old *OCI IAM Identity Domain (SSO)* is replaced).

## Tested (local Oracle 26ai + APEX 26.1, app 134)
- Package compiles; `apex validate` passes.
- `load_user_roles` in an APEX session: no error without the REST source (0 roles, warning logged).
- Sign-in through `post_auth_local` and every authorization scheme through the package: `kyc_ui.py` 26/26,
  `party_ui.py` 23/23 (party detail dialogs), `request_party_ui.py` 24/24.
- Identity-domain sign-in itself needs the real identity domain; not testable locally.
