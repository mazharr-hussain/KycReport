# COMMON 111 - Menu group page, RFI lookups, install fix

Build: `releases/COMMON-Application-APEXlang_111.zip` (application version "Release 111"), on top of COMMON 110.
Built with `repos/common/build.sh --release 111`; checked with the APEXlang validation ("Validation successful"). No
database was run: the DB test `tests/r111_common_pending_test.sql` is for the test database.

## What changes
| Item | Change |
|---|---|
| Install fix (109) | `XXFND_SERVERS_V`: a comment line ended with `;`, which SQL Developer took as the end of the statement (ORA-00936 / ORA-03048). Every script checked: no other such comment inside a SQL statement. |
| Menu groups | Clicking a group in the side menu (Platform, Security, ... and any application's group) opens page 100 for that group: the entries the user may open, as cards (a page opens it, a group opens its own group page). The breadcrumb's module level opens the same page. Page 100 without a group still shows the COMMON modules with their state. Page 100 access: Application User (each entry is shown only by its own privilege). |
| RFI lookups | `RFI_STATUS`, `RFI_RECIPIENT_TYPE`, `RFI_CATEGORY` are shared COMMON lookups (script 41b), so COMMON's RFI shows their names on its own. A type an application registered before becomes COMMON's; its values stay. |
| Scheme names | `XXFND_USER_PKG.AUTHORIZED`: `KYC_USER` (an application name in COMMON) and the leftover `ADMIN_APP` removed; `APP_USER` serves every application. |
| Retention | Unchanged (placeholder). |

## Database
- `XXFND_APPLICATION_PKG.MENU_URL`: P_ENTRY_CODE (default null) - a folder links to page 100 (P100_GROUP).
- `XXFND_NAV_MENU_V`: passes the entry code; new columns ENTRY_CODE, PARENT_CODE, TARGET_TYPE, DESCRIPTION; the group
  shown on page 100 is the current menu entry.
- Script `41b-rfi-lookups` (install / upgrade 254).

## KYC impact
KYC's `kyc-user` authorization calls `authorized('KYC_USER')`, which is now false (COMMON-ISSUES C18). Switch it to
`APP_USER` and deploy that KYC change together with COMMON 111.

## Deploy
App Builder > Import `COMMON-Application-APEXlang_111.zip` over COMMON (135), Install Supporting Objects = Yes; or run
`run-release.sql` as XXFUSION, then import the application. A re-run changes nothing.

## Live checks
1. Click Platform in the menu: page 100 shows Platform's screens as cards; the group stays open in the menu.
2. Breadcrumb Home > Platform > a screen: Platform opens the same page.
3. An RFI in COMMON shows its status name.
