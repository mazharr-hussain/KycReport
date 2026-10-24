# KYC 99 - Requester area

Build: `releases/KYC-Compliance-Platform-APEXlang_99.zip` (application version "Release 99"). KYC only, on top of KYC 98
and COMMON 107. Built with `repos/kyc/build.sh --release 99` (`python3 repos/common/tools/build.py --repo kyc --release 99`);
checked with the APEXlang validation ("Validation successful"). No database was run: the PL/SQL is checked by review,
and the DB test `features/kyc-requests/tests/r99_requester_test.sql` is for the test database.

## What changes (requester screens)
| Item | Change | Where |
|---|---|---|
| A1 | Home tiles "Department open requests" / "Department closed requests" (requests data security lets the user see; users without Cases - View); open page 200 filtered on the new column Open / Closed | p00001, p00200 |
| A3 | "Pending my approval" kept as it is | - |
| A4 | Tile "Open RFIs" renamed "Information requested from me" | p00001 |
| A5 | Create Request button on Home (KYC Requests - Create) | p00001 |
| B1 | Risk Screening on step 1: the requester questionnaire (the questions of page 202) plus the seeded gate question "Business counterparty ownership structure type"; Check saves the draft and the answers and shows "KYC Report Required" from `XXCMP_REQUEST_PKG.SCREENING_OUTCOME` (the rule EVALUATE applies at submit, shared in one private function, without changing the request) | p00201, 16b/16r, 18k |
| B2 | Not required: a note to attach the evidence at Review and Submit (Request Documents) and submit anyway; the submit records Not Required (EVALUATE) | p00201 |
| B3 | Required: Business Relationship Type and Business Justification appear after the outcome; not asked when KYC is not required (REQUEST_ERROR) | p00201, 16r |
| B4 | No Existing party / New counterparty choice (an older request keeps its saved choice, hidden) | p00201 |
| B5 | No Possible Matches on step 1 (the requester is not asked; a duplicate number no longer stops the request form - Compliance merges duplicates) | p00000, 16e |
| C1 | Party types "Legal Person" / "Natural Person (Individual)" on step 1 and the party card of 201 / 204 (COMMON has no routine to rename a lookup value: COMMON-ISSUES C15) | p00000, 16e |
| C2 | Legal person: Registration Type and Incorporation Date hidden on step 1 (kept for an individual as ID Type / Date of Birth) and on the 204 card; the registration type is not required on the request form | p00000, 16e0/16e |
| C3 | Email, Phone, Website, Fax not on step 1 nor on the 204 card; "Enter an email or a phone number" not asked on the request form | p00000, 16e |
| C4 | Headquarters Address / Address: already optional (no change) | - |
| C5, C6 | Labels "Full name as per Official Document (in English)", "Date of Birth as per Official Document", "Name (as per CR / Official Documents)" on step 1 and the 204 card | p00000, 16e |
| D1 | Contact Persons and Owners and Officers hidden on 204 for an individual (kept for an organisation) | p00000 |
| D2 | Attach documentation on 204: the requester may now see the party he created (data rule REQUESTER / XXCMP_PARTIES / own records on CREATED_BY), so COMMON's document dialog opens the record | 18h |
| D3 | Questionnaire step removed from the wizard: list Request Wizard, 204 Next -> 203, 203 Previous -> 204 | lists.apx, p00203, p00204 |
| D4 | 203 for a requester (no Cases - View): no Questionnaire / Questionnaire Score; "Next Steps" with one row "Sent for Risk Management Review" (no Approver, Action / Status) | p00000 |
| E1 | 205 for a requester: no questionnaire, score and answers regions | p00000 |
| E2 | 205 for a requester: History with "Action" ("Request Submitted"...), "Status", no Approver | p00000 |
| Fix | Step 1 kept the entered values after a failed Next / Check / Save (the load process no longer reloads on that re-render) | p00201 |

Approvers and Compliance (Cases - View) see 203 / 205 / 206 as before; page 202 stays (no longer in the wizard).

## Files
- `app/pages/` p00000 (Global Page), p00001 (Home), p00200, p00201, p00203, p00204; `app/shared-components/lists.apx`
- `db/` 16b + 16r (XXCMP_REQUEST_PKG), 16e0 + 16e (XXCMP_PARTY_PKG), 18h (data rule), 18k (new: ownership question,
  install sequence 197 / upgrade 157)

## Deploy
1. App Builder > Import `KYC-Compliance-Platform-APEXlang_99.zip` over KYC (134), Install Supporting Objects = Yes
   (the upgrade runs 16b, 16e0, 16e, 16r, 18h and 18k; a re-run changes nothing).
2. KYC Rules: decide which answers of "Business counterparty ownership structure type" waive KYC (waiver flag,
   maker-checker) - seeded with no waiver and 0 points.
3. Test users: re-run COMMON's `db/admin/test-users.sql` once COMMON-ISSUES C16 is fixed (department codes).

## Live checks
Sign in as the requester (TKYC_REQ1), an approver and Compliance; run `features/kyc-requests/tests/r99_requester_test.sql`
on the test database.
