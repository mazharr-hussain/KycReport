# Patch 45 – COMMON administration foundation (release 61, COMMON only)

## What changes
- **Application scope (script 16i):** every COMMON setup screen works for one application at a time (selector on the
  Administration pages; another application can open a screen for itself with `G_ADMIN_APP=<code>&G_ADMIN_LOCK=Y`).
  - `XXFND_ADMIN_SCOPE_PKG`, `XXFND_ADMIN_APPLICATIONS_V`: the applications the user administers - all for a Common
    Administrator, otherwise those of the user's roles that hold an admin privilege.
  - Data security on the setup tables with an application column (lookup types, notification templates, integration
    purposes and endpoints, document entities and categories, attachment pages, flexfields, value sets, retention
    policies, storage rules): inside COMMON only that application's rows plus the shared rows (read-only); new rows
    belong to the application in scope. Other applications are not affected.
  - Application column added to value sets, retention policies, storage rules, integration endpoints (empty = shared).
- **Admin features for COMMON (script 21):** the admin features (same codes as the business applications), their
  COMMON pages and tabs, and every admin privilege for the Common Administrator.
- **Authorization (16j):** administrators of any application may use COMMON (`APP_USER`, `ADMIN_AREA`); new
  `ADMIN_APP` check.
- **App shell:** Administration page (100) and menu, admin lists (only features with a page in COMMON), feature tabs,
  authorization schemes (view / create / manage / submit / admin area / application in scope), page groups, the
  application selector on the global page, process `SET_ADMIN_APP`.

## Verified locally
clean → import → fresh install: 0 errors, 0 invalid; upgrade: 0 errors. Browser: ADMIN opens Home and Administration
with the selector; a user without an admin role is refused.

## Deploy
Import `COMMON-Application-APEXlang_61.zip` over COMMON (Parsing Schema XXFUSION) → Install Supporting Objects: Yes
(upgrade). On a clean XXFUSION: the steps of patch 44.
