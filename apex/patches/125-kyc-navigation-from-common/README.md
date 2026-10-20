# Patch 125 - KYC 98: navigation from COMMON's registry

Build: `KYC-Compliance-Platform-APEXlang_98.zip` (version "Release 98"). Install COMMON 106 (patch 124) first.

## What changes
- **Navigation Bar:** now subscribes to COMMON's master (`XXFND_NAV_PKG.NAV_MENU('TOP_BAR')`). KYC's own static bar
  is gone.
- **18j-kyc-top-bar.sql (new, install 194 / upgrade 154):** registers KYC's top bar in COMMON's registry through
  `REGISTER_MENU_ENTRY` (missing entries only): Feedback, plus the user menu with About, a separator and Sign Out.
  The theme Customize entry is dropped (Redwood Light only); Help is dropped (COMMON has no page 174).
- **Administration list:** refreshed from COMMON 106's master. The shared setup screens now link straight to the
  COMMON page, by privilege; no page 99 any more.
- KYC's side menu, top bar and administration are now all managed on COMMON > Reference Data > Application Menu.

## Deploy
App Builder > Import `KYC-Compliance-Platform-APEXlang_98.zip` over KYC (134), with Install Supporting Objects set
to Yes.

## Tests
APEXlang validation (offline). Not run on a database, as agreed.
