# Patch 124 - COMMON 106: page access by privilege, Application Menu in one place

Build: `COMMON-Application-APEXlang_106.zip` (application version "Release 106"). COMMON only. Install COMMON 105
(patch 123) first. KYC follows later, in one go.

## What changes
- **Install fixes:** a re-run no longer fails on the menu entry checks (31b creates the current checks directly);
  COMMON's menu is filled after every screen is registered (31c runs after 35 and 31d).
- **Access to a COMMON page = the privilege a role gives**, from any application. The "managed in the application"
  access (release 73) is retired:
  - no switch on the application's Shared Functions step;
  - no entry page 99;
  - no MANAGED menu type: existing MANAGED entries become COMMON page entries, hidden unless the function was
    managed, so nobody sees an entry they didn't see before;
  - users are no longer "managed in the application" (pages 104, 184).
- **Data on COMMON setup screens:**
  - IT sees every row.
  - Anyone else sees and changes the rows of the applications whose roles give the page's privilege, and reads the
    shared rows. A COMMON page used from an application works for that application's rows (`G_WORK_APP`).
  - Transaction pages stay per user.
- **Application Menu is its own feature under Reference Data** (next to Lookups and Flexfields), with View / Create /
  Manage privileges. Roles with Applications privileges get the same rights.
  - **All Pages (169, new):** every page of every registered application, once, under its owner, with the privilege
    that opens it and who uses it:
    - In Own Menu;
    - In Menus Of (other applications whose menus have the COMMON page);
    - Linked From (buttons, branches, report and list links in the APEX definitions);
    - Opened From (recorded when a COMMON page is opened from another application's page, with count and last date).
  - **Menu by Application (167)** is its second tab, also opened by the Menu button on an application (166). The page
    list on an entry (168) shows each page's privilege.
- DB: 09d (FEATURE_APPS, scope predicate, retired functions; IS_DELEGATED kept as an always-N stub), 16j, 33, 31b
  (table XXFND_PAGE_OPENS, views XXFND_PAGE_LINKS_V / XXFND_PAGE_CATALOGUE_V, XXFND_NAV_PKG.RECORD_OPEN), 31d (new),
  31c resequenced.

## Deploy
App Builder > Import `COMMON-Application-APEXlang_106.zip` over COMMON (135), with Install Supporting Objects set to
Yes.

## KYC later (noted)
KYC's Administration page uses an old copy of COMMON's Administration list. Its "shared setup" links stop showing
until KYC refreshes the subscription. Nothing fails: `IS_DELEGATED` is kept and returns N.

## Tests
APEXlang validation (offline). Not run on a database, as agreed.
