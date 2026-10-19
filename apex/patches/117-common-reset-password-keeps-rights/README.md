# Patch 117 - COMMON 101: Reset Password keeps the user's APEX rights (issue 18)

Build: `COMMON-Application-APEXlang_101.zip` (application version "Release 101"). COMMON only. Install COMMON 100
(patch 115) first.

## What changes
- XXFND_USER_PKG (Reset Password on the User page, and every script that calls it): APEX_UTIL.EDIT_USER sets every
  attribute it is given and clears the others, so a reset removed a workspace administrator's or developer's rights
  (and could clear the e-mail and name). The account is now read first (APEX_UTIL.FETCH_USER: name, e-mail, dates,
  schemas, groups, developer / administrator rights, description, expiry, lock) and given back unchanged; only the
  password changes, and the user changes it at the next sign-in.
- Lock / Unlock (Disable / Enable) already used APEX_UTIL.LOCK_ACCOUNT / UNLOCK_ACCOUNT, which change nothing else.

## Files
- `db/16j-user-pkg.sql`, `app/application.apx` (Release 101)

## Deploy
App Builder > Import `COMMON-Application-APEXlang_101.zip` over COMMON (135), Install Supporting Objects: Yes.

## Tests
XXFND_USER_PKG compiles (local database, compile only); not run (as agreed).
