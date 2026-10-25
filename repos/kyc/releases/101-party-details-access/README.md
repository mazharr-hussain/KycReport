# KYC 101 - Party details access rule in the party package

Build: `releases/KYC-Compliance-Platform-APEXlang_101.zip` (application version "Release 101"), on top of KYC 100.
Built with `repos/kyc/build.sh --release 101`; checked with the APEXlang validation ("Validation successful").
No database was run (offline validation only).

**Order:** deploy KYC 101 before COMMON 108 (COMMON 108 removes the `PARTY_DETAILS_*` rules from `XXFND_USER_PKG`).

## What changes
| Item | Change |
|---|---|
| Party detail dialogs (contact person, owner / officer) | The authorizations `PARTY_DETAILS_VIEW / CREATE / MANAGE / SUBMIT` call `XXCMP_PARTY_PKG.DETAILS_AUTHORIZED` (new): the page privilege (COMMON `XXFND_USER_PKG.AUTHORIZED('PAGE_<level>')`) or the requester working on the party of their request (`CAN_EDIT_DETAILS`). Same rule as before, now in the party package |
| One object per file | `lists.apx`, `lovs.apx`, `authorizations.apx` split into one file per component |
| Tests | The COMMON tests that need KYC moved to `tests/common-usage/` |

## Files
- `app/shared-components/authorizations/` the four party-details authorizations
- `db/` + `run-release.sql`: `XXCMP_PARTY_PKG` spec and body

## Deploy
1. App Builder > Import `KYC-Compliance-Platform-APEXlang_101.zip` over KYC (134), Install Supporting Objects = Yes; or run
   `run-release.sql` as XXCUS. A re-run changes nothing.

## Live checks
As TKYC_REQ1: open the own request's party, add a contact person -> allowed; as a user without the page privilege and
not the requester -> refused.
