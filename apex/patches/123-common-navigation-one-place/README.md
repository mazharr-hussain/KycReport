# Patch 123 - COMMON 105: all navigation in one place

Build: `COMMON-Application-APEXlang_105.zip` (application version "Release 105"). COMMON only. Install COMMON 104
(patch 121) first. KYC follows later, in one go, on the finished COMMON.

## What changes
- **One registry for every navigation, COMMON included.** `XXFND_APP_MENU_ENTRIES.MENU_CODE` (new): SIDE (navigation
  menu), TOP_BAR (navigation bar), ADMIN (reserved for administration). New entry types for the top bar: USER_MENU
  (the user's name, holds other entries), SIGN_OUT, SEPARATOR. `REGISTER_MENU_ENTRY` / `MAINTAIN_MENU_ENTRY` take
  `P_MENU_CODE` (default SIDE); a parent must be a folder or the user menu of the same menu.
- **COMMON's own menu and top bar are registry rows** (`XXFND_APPLICATION_PKG.SYNC_MENU('COMMON')`, run by 31c,
  adds only what is missing): side menu - Home, My Tasks, one folder per module with its features; top bar -
  Notifications (with the unread badge), Give Feedback, the user menu with Sign Out. The automatic COMMON branch of
  `XXFND_NAV_MENU_V` is gone: every application's navigation comes from the registry, by privileges.
- **Navigation Bar list (master) reads the registry**: `table(xxfnd_nav_pkg.nav_menu('TOP_BAR'))` (A01 = badge,
  A02 = class), like the Navigation Menu list (`nav_menu`, SIDE). The static navigation bar entries are removed.
- **Application Menu screen (167 / 168)**: new Menu selector (Side menu / Top bar); COMMON can be chosen as the
  application; the entry types User menu, Sign out and Separator; the Folder list shows the folders of that menu.
- **Navigation no longer used is removed:**
  - The second menu editor on the application pages ("Menu in the Application" with Show / Hide on 166 and the review
    step of 165, release 87) and its JOURNEY_ACTIONS requests JRN_MENU_ON / JRN_MENU_OFF. Page 166 has a Menu
    button that opens the Application Menu screen instead.
  - The view `XXFND_APP_MENU_V` (release 87 navigation list, used by no application): no longer created by 31;
    31c drops it.
- DB: 09d (column MENU_CODE + CK10, SYNC_MENU, new types), 31b (view and XXFND_NAV_PKG per menu), 31c (new,
  install 228 / upgrade 188: CK5 / CK7 replaced by CK8 / CK9, drop XXFND_APP_MENU_V, SYNC_MENU('COMMON')).

## Deploy
App Builder > Import `COMMON-Application-APEXlang_105.zip` over COMMON (135), Install Supporting Objects: Yes.

## Not changed (noted)
- COMMON's "Administration" list is used only as the master of KYC's Administration page; it stays until KYC moves
  to registry ADMIN entries (KYC, later).

## Tests
APEXlang validation (offline). Not run on a database, as agreed.
