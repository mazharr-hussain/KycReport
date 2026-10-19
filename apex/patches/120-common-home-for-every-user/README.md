# Patch 120 - COMMON 103: Home for every user

Build: `COMMON-Application-APEXlang_103.zip` (application version "Release 103"). COMMON only. Install COMMON 102
(patch 118) first.

## What changes
- A user who may not open COMMON Home (e.g. a KYC requester on My Tasks) clicked the logo or Home and got
  "Access denied by Page security check". Their Home is now their own application:
  - XXFND_USER_PKG.HOME_APPLICATION: the APEX alias of the user's first active application other than COMMON.
  - Application process USER_HOME (once per session): G_USER_HOME_URL = COMMON Home for a user with the Common Home
    privilege, else the home page of the user's application, else My Tasks; G_USER_APP_NAME = that application's name.
  - The name at the top (G_APP_TITLE) shows the user's application for such a user; My Tasks opened from an
    application still shows that application.
  - Page 1 (Home) is open to every signed-in user, but only a user with the Common Home privilege sees it: anyone else
    is sent to their Home. This also fixes the shared login page for KYC-only users (page 1 sends them on to KYC).
  - My Tasks' Home breadcrumb falls back to the user's Home.
- COMMON users (Common Home privilege) see no change.

## Files
- `db/16j-user-pkg.sql`; `app/`: application.apx, pages 1 and 40, app items, app processes, app computations.

## Deploy
App Builder > Import `COMMON-Application-APEXlang_103.zip` over COMMON (135), Install Supporting Objects: Yes.

## Tests
APEXlang validation (offline). Not run on a database, as agreed.
