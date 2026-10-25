# KYC 103 - Create Request in 3 steps

Build: `releases/KYC-Compliance-Platform-APEXlang_103.zip` (application version "Release 103"), on top of KYC 102
(and COMMON 108). Built with `repos/kyc/build.sh --release 103`; checked with the APEXlang validation ("Validation
successful"). No database was run: the DB test `features/kyc-requests/tests/r103_request_steps_test.sql` is for the
test database.

## What changes
| Step | Page | Content |
|---|---|---|
| 1 Request | 201 | Requesting Department, Party Type (Legal Person / Natural Person - it decides the screening questions), the risk screening questions with Check, and the Business Relationship Type when a KYC report is required |
| 2 Counterparty | 204 | Business Justification first, then the counterparty's basic information (the same party form as before, party type from step 1; Use the Existing Party Yes / No for a duplicate), additional information and the counterparty documents (Save to add them once the counterparty is entered) |
| 3 Review and Submit | 203 | The summary, the request documents (the evidence when no KYC report is required) and Submit |

- Contact persons and owners / officers are no longer on the request pages (201-206); they stay on the party and
  case screens (21, 25, 211).
- Step 1 saves a Draft request without a counterparty (shown as "New counterparty" in the request list until step 2).
- Database (request package only): `XXCMP_REQUEST_PKG.SAVE_INTAKE` / `INTAKE_ERROR` (step 1), `SAVE_COUNTERPARTY` /
  `BUSINESS_RELATIONSHIP` (step 2, through `SAVE_REQUEST`); the shared checks (locked request, rejected request back
  to Draft, department rules) are private routines used by both steps. No table change.

## Files
- `app/pages/` p00000 (Global Page), p00201, p00203, p00204; `app/shared-components/lists/request-wizard.apx`
- `db/` + `run-release.sql`: `XXCMP_REQUEST_PKG` spec and body

## Deploy
App Builder > Import `KYC-Compliance-Platform-APEXlang_103.zip` over KYC (134), Install Supporting Objects = Yes; or
run `run-release.sql` as XXCUS, then import the application. A re-run changes nothing.

## Live checks (TKYC_REQ1)
1. Create Request: department, party type, answer the questions, Check, relationship (when required), Next.
2. Step 2: justification, counterparty, Save, add a document, Next.
3. Step 3: attach a request document, Submit. No contact person or owner regions on any step.
