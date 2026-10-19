# Patch 122 - KYC 97: KYC's menu from COMMON

Build: `KYC-Compliance-Platform-APEXlang_97.zip` (application version "Release 97"). Install COMMON 104 (patch 121)
first - script 03 stops with ORA-20904 otherwise.

## What changes
- KYC's menu entries are registered in COMMON (18i): Home, KYC Requests, Parties, Cases, Monitoring Watchlist,
  Executive Dashboard, Administration (administrators); My Tasks is COMMON's default entry. COMMON's other default
  entries (Notifications, Feedback, Shared Setup, managed setup) are hidden once - KYC shows them in the navigation
  bar and on the Administration page; an administrator may show them again on COMMON's Application Menu screen.
- KYC's lists "Navigation Menu" and "Administration" are subscribed from COMMON (no own copy). The menu shows by
  privileges as before, and stays the same on COMMON's pages used from KYC (My Tasks, Notifications, ...).

## Deploy
App Builder > Import `KYC-Compliance-Platform-APEXlang_97.zip` over KYC (134), Install Supporting Objects: Yes.
Changes to the menu: COMMON > Applications > KYC > Edit Menu (no deployment).

## Tests
APEXlang validation (offline). Not run on a database, as agreed.
