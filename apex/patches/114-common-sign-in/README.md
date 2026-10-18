# Patch 114 - COMMON 99: sign-in owned by COMMON - company account (SSO) first, APEX accounts for every user

Build: `COMMON-Application-APEXlang_99.zip` (application version "Release 99"). COMMON only. Install COMMON 98 (patch 113)
first. ADMIN must have run once: `grant apex_administrator_role to xxfusion;`

## What changes
- **Company account (SSO) is the main sign-in** (current scheme `APEX_FA_IABWBN-DEV1_OAUTH`, identity domain): a user
  already signed in to Fusion or any other product of the identity domain opens COMMON without signing in again; without
  an IDCS session the IDCS login page is shown once.
- **Local sign-in (user name and password) is still available** for every user: Oracle APEX Accounts, switched in the
  session (Switch in Session = Yes on both schemes). The local sign-in link (send it to users without a company account):
  `https://<host>/ords/f?p=135:1:0:APEX_AUTHENTICATION=Oracle%20APEX%20Accounts`
  The login page (9999) also has **Sign in with company account**.
- **Linked with SSO:** a user signing in with the company account is the COMMON user whose user name matches the
  identity-domain user name, or whose e-mail matches the identity-domain e-mail (XXFND_USER_PKG.MAP_LOGIN_USER, release 99:
  e-mail of G_EMAIL). Roles, data access and tasks are the same whichever way the user signs in.
- **Every user has an APEX account** (managed in COMMON, roles etc. on the User page):
  - new: `XXFND_USER_PKG.ENSURE_APEX_ACCOUNT(user_id, first password)` - the APEX account of an existing user;
    Reset Password also works for an SSO user that has one.
  - `db/admin/move-users-to-apex-accounts.sql`: every enabled user without an APEX account (e.g. users that signed in
    with a database account, such as SHUSSAIN@QATARIDIAR.COM) gets one; first password `Welcome#2026`, changed at first
    sign-in (database passwords cannot be copied - tell the users).
- **One sign-in for all applications:** sessions are shared in the workspace; the links between applications carry the
  session, so a sign-in in COMMON (SSO or local) is valid in KYC and every other application.

## Files
- `db/16j-user-pkg.sql` (ENSURE_APEX_ACCOUNT, MAP_LOGIN_USER e-mail match, RESET_PASSWORD)
- `db/admin/move-users-to-apex-accounts.sql` (new), `db/admin/qd-users-and-roles.sql` (as patch 113)
- `app/application.apx` (Release 99, current scheme SSO), `app/shared-components/authentications.apx` (Switch in Session),
  `app/pages/p09999-login.apx` (Sign in with company account)

## Deploy
1. ADMIN (once): `grant apex_administrator_role to xxfusion;`
2. App Builder > Import `COMMON-Application-APEXlang_99.zip` over COMMON (135), Install Supporting Objects: Yes.
3. As XXFUSION: `db/admin/move-users-to-apex-accounts.sql`, then `db/admin/qd-users-and-roles.sql`.
4. After the users signed in with their APEX accounts, ADMIN locks (or drops) the old database users, e.g.
   `alter user "SHUSSAIN@QATARIDIAR.COM" account lock;`

## Later (KYC round)
KYC subscribes to COMMON's authentication schemes (no own login page; current scheme SSO); local users of KYC use
COMMON's local sign-in link.

## Tests (local database; no identity domain locally, so the SSO redirect itself is not tested)
- Scheme switch: `f?p=135:1:0:APEX_AUTHENTICATION=Oracle%20APEX%20Accounts` opens the login page; ADMIN signs in; the
  session works in KYC and back in COMMON (both with SSO as current scheme).
- Move script: a user without an APEX account got one; a re-run created none; the user signed in with the first password
  and was asked to change it (test user removed afterwards).
- APEXlang validation passed; XXFND_USER_PKG valid.
