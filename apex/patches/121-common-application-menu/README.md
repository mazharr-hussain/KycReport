# Patch 121 - COMMON 104: the menu of every application, kept in COMMON

Build: `COMMON-Application-APEXlang_104.zip` (application version "Release 104"). COMMON only. Install COMMON 103
(patch 120) first; KYC 97 (patch 122) follows.

## What changes
- **Menu registry (as in EBS / Fusion).** Each application's menu is kept in COMMON (`XXFND_APP_MENU_ENTRIES`):
  folders (new type FOLDER) and the pages they open (APP_PAGE, ADMIN_PAGE - a page for the application's
  administrators, COMMON_PAGE, MANAGED, SHARED_SETUP), in order. Entries come from COMMON (onboarding), the
  application's install (`REGISTER_MENU_ENTRY`, only missing ones) or an administrator (new: ADMIN).
- **Application Menu screen** (pages 167 list + 168 entry; Applications View / Manage; also "Edit Menu" on the
  application's Menu section): add folders and entries, move them into folders, rename, reorder, change the icon,
  show / hide. Routines `XXFND_APPLICATION_PKG.MAINTAIN_MENU_ENTRY` / `DELETE_MENU_ENTRY` (only administrator
  entries are deleted; the others are hidden).
- **Who sees an entry = privileges.** `ENTRY_VISIBLE`: the entry's privilege (View), else the privilege of the page it
  opens (View; a page of no privilege: every user), ADMIN_PAGE: any administrator; a folder shows when one of its
  entries shows, a hidden folder hides its entries.
- **One navigation list for every application.** COMMON's "Navigation Menu" list (master) reads
  `XXFND_NAV_PKG.NAV_MENU` (view `XXFND_NAV_MENU_V`); applications subscribe to it. COMMON's "Administration" list
  is the master of the applications' Administration page.
- **COMMON pages used from an application keep its menu.** Process WORK_APP (all pages, replaces My Tasks' own) keeps
  the application the user came from (`G_WORK_APP`) until COMMON Home: its menu, name and Home stay on every COMMON
  page. Breadcrumb Home of Notifications, Communications, Attachments and Feedback goes to it as on My Tasks.

## Deploy
App Builder > Import `COMMON-Application-APEXlang_104.zip` over COMMON (135), Install Supporting Objects: Yes. Then
KYC 97.

## Tests
APEXlang validation (offline). Not run on a database, as agreed.
