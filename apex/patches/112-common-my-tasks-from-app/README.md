# Patch 112 - COMMON 97: My Tasks follows the application it was opened from (UI issue 11)

Build: `COMMON-Application-APEXlang_97.zip` (application version "Release 97"). COMMON only, app files only: no database
change; KYC is not changed. Install COMMON 96 (patch 111) first.

## What changes
- My Tasks (40) reads the page it was opened from. Opened from another application (e.g. KYC), the name at the top is that
  application's name and the breadcrumb **Home** goes to that application's home page. Opened from a COMMON page, both are
  COMMON's (as before). A refresh of My Tasks keeps them.
- Every other COMMON page is unchanged: the name at the top is COMMON's name (now from the app item G_APP_TITLE).

## Files (app/)
- `application.apx` (Release 97; logo text `&G_APP_TITLE.`)
- `pages/p00040-my-tasks.apx` (process "Application the user came from")
- `shared-components/app-items.apx` (G_APP_TITLE, G_FROM_APP_NAME, G_HOME_URL), `app-computations.apx` (app-title),
  `breadcrumbs.apx` (entry home-from-app as the parent of My Tasks)

## Deploy
App Builder > Import `COMMON-Application-APEXlang_97.zip` over COMMON (135). Install Supporting Objects may be Yes or No.

## Tests
APEXlang validation passed. Not run in the browser (as agreed).
