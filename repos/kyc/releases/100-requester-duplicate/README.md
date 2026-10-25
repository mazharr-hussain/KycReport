# KYC 100 - Requester area: no duplicate counterparty

Build: `releases/KYC-Compliance-Platform-APEXlang_100.zip` (application version "Release 100"). KYC only, on top of KYC 99
and COMMON 107. Built with `repos/kyc/build.sh --release 100`; checked with the APEXlang validation ("Validation
successful"). No database was run: the PL/SQL is checked by review, and the DB test
`features/kyc-requests/tests/r100_duplicate_party_test.sql` is for the test database.

## What changes (Create Request step 1, page 201)
| Item | Change | Where |
|---|---|---|
| Duplicate rule | Unchanged: same party type, registration type, registration number (spaces and punctuation ignored) and country, among enabled parties that are not rejected or cancelled (`XXCMP_PARTY_PKG.EXACT_PARTY_ID`, new; `EXACT_PARTY_NUMBER` uses it) | 16e0/16e |
| Blocked | A new counterparty that duplicates a party is not created (Next, Check and Save as Draft): "Party P-... - name already has this registration type, registration number and country. Use the existing party?" (`XXCMP_REQUEST_PKG.DUPLICATE_PARTY_ID` / `REQUEST_ERROR`; replaces the release 99 "a duplicate does not stop the request form") | 16b/16r |
| Use the Existing Party | Yes / No under the counterparty, shown only when a duplicate is found. Yes: the request links the existing party (any status but rejected / cancelled, Pending included), the draft's own Pending party is cancelled, the party card shows it. No: "Change the registration type, registration number or country" until the details are changed | p00201, 16r |
| Registration type | Required on the request form for a legal person (document type: CR, trade licence ...; ID type for an individual as before), shown again on step 1 and on the request party card | p00000, 16e |
| Existing party | A request may link any enabled party that is not rejected or cancelled (was: approved only) | 16r |

## Files
- `app/pages/` p00000 (Global Page), p00201
- `db/` 16b + 16r (XXCMP_REQUEST_PKG), 16e0 + 16e (XXCMP_PARTY_PKG) - packages only, no table change, no new script

## Deploy
1. App Builder > Import `KYC-Compliance-Platform-APEXlang_100.zip` over KYC (134), Install Supporting Objects = Yes
   (the upgrade recreates the two packages; a re-run changes nothing).

## Live checks
As TKYC_REQ1: Create Request with the registration type, number and country of an existing party -> the message and
Use the Existing Party; No -> change the details; Yes -> Next links the party (card shown, no new party).
