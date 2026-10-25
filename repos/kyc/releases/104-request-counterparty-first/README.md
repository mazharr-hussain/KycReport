# KYC 104 - Create Request: counterparty first, questions, review

Build: `releases/KYC-Compliance-Platform-APEXlang_104.zip` (application version "Release 104"), on top of KYC 103.
Built with `repos/kyc/build.sh --release 104`; checked with the APEXlang validation ("Validation successful"). No
database was run: the DB test `features/kyc-requests/tests/r104_request_rules_test.sql` is for the test database.

## What changes
| Step | Page | Content |
|---|---|---|
| 1 Counterparty | 201 | Requesting Department, Business Relationship Type (required), Business Justification (optional), the counterparty's basic information (party form, Use the Existing Party Yes / No for a duplicate) |
| 2 Questions | 204 | All the risk screening questions of the counterparty's type on one page (no paging, no Check button); Next saves the answers |
| 3 Review and Submit | 203 | Summary only (request, counterparty, business relationship, KYC report required - with the evidence note when not required -, ready to submit), the counterparty documents (Party Documents, add / attach here), Previous / Save as Draft / Submit |

- Removed from Review and Submit: the request header card, the party card and additional information, the
  questionnaire, the request documents, the approval history and the next steps (the last one is removed from the
  application). Compliance still sees them on 205 / 206. Respond (Information Needed) stays.
- Contact persons and owners / officers stay off the request pages (release 103).
- Rules (`XXCMP_REQUEST_PKG.REQUEST_ERROR`): the business relationship is required whatever the risk screening finds;
  the business justification is optional. The KYC 103 step routines (`SAVE_INTAKE`, `INTAKE_ERROR`,
  `SAVE_COUNTERPARTY`, `BUSINESS_RELATIONSHIP`) are removed; step 1 uses `SAVE_REQUEST` again.
- Script 18h registers Party Documents on page 203 in COMMON (`XXFND_ATTACH_PKG.REGISTER_ATTACHMENT_PAGE`).

## Files
- `app/pages/` p00000 (Global Page), p00201, p00203, p00204; `app/shared-components/lists/request-wizard.apx`
- `db/` + `run-release.sql`: `XXCMP_REQUEST_PKG` spec and body, script 18h

## Deploy
App Builder > Import `KYC-Compliance-Platform-APEXlang_104.zip` over KYC (134), Install Supporting Objects = Yes; or
run `run-release.sql` as XXCUS, then import the application. A re-run changes nothing.

## Live checks (TKYC_REQ1)
1. Step 1: department, relationship, optional justification, counterparty; Next (relationship missing -> message).
2. Step 2: every question on one page, no Check; Next.
3. Step 3: only the summary, Party Documents (attach a document) and the buttons; Submit.
