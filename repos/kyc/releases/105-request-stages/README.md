# KYC 105 - Request stages, stage 1 Assign, requester and L1 KPIs

Build: `releases/KYC-Compliance-Platform-APEXlang_105.zip` (application version "Release 105"), on top of KYC 104
(and COMMON 108). Built with `repos/kyc/build.sh --release 105`; checked with the APEXlang validation ("Validation
successful"). No database was run: the DB test `features/kyc-requests/tests/r105_request_stages_test.sql` is for the
test database.

## What changes (by page)
| Page | Change |
|---|---|
| 1 Home | Requester: 8 tiles - Department and My: Total, Pending Information, Open (Draft, Submitted, Under Review, In Approval, Information Needed), Closed (Approved, KYC Not Required, Rejected, Cancelled); each opens KYC Requests filtered. L1 (Case Assignment privilege): New Requests tile. |
| 201 Create Request step 1 | Request section (Requesting Department, Requesting Country - new, required, country list -, Business Relationship, Business Justification optional) and Party section, both in two columns. Duplicate check (Use the Existing Party) removed. |
| 204 Questions | Unchanged. |
| 203 Review and Submit | Request (department, country, relationship, justification, KYC required, ready to submit), Party, Questions and answers (no score / risk flags for the requester), Party Documents (mandatory per Document Rules at Submit). |
| 205 Request | After Submit a pop-up: "KYC is not needed. Kindly proceed." or "The request is submitted for KYC report."; the stage bar (Draft, Submitted, Under Review, In Approval, Approved / KYC Not Required / Rejected / Cancelled). |
| 205 / 206 header card | KYC Required / KYC Not Required for everyone; the score only for Compliance (Cases - View). |
| 206 Approval (L1, stage 1) | Assign (contributor + comment): approves the checklist, opens the case for the contributor, the request becomes Under Review. Approve and Add Approver hidden (build option "Request - Approve / Add Approver", Exclude). Reject and Request Information as before. |
| 200 KYC Requests | New Requests (Content Row, row selection, Select All) + Assign: the selected requests to one contributor. New statuses; Edit only before a case exists, Withdraw while Submitted. |

## Request statuses (the request is the parent of its case)
Draft -> Submitted (submit) -> Under Review (Assign: case opened) -> In Approval (case submitted for approval) ->
Approved (case approved). Any time: Information Needed (request or case question), Rejected, Cancelled; KYC not required
-> KYC Not Required (closed). The case package reports each case change to the request package
(`XXCMP_REQUEST_PKG.CASE_CHANGED`); the request is no longer Approved when its case opens.

## Database
- `16z-request-stages`: XXCMP_REQUESTS.REQUESTING_COUNTRY; status check widened (checked drop / add); existing requests
  moved to their stage from their case. Script 16f no longer resets the statuses once 16z ran.
- `XXCMP_REQUEST_PKG`: CASE_OPENED, CASE_CHANGED, STATUS_TONE, SUBMIT_MESSAGE, ASSIGNABLE_TASK, ASSIGN_REQUEST,
  ASSIGN_REQUESTS; duplicate rule removed; requesting country required. `XXCMP_CASE_PKG`: reports case changes.
- 18h: KYC_REQUEST_STATUS values (Submitted, Under Review, In Approval, KYC Not Required); Party Documents on page 203.
- COMMON-ISSUES C17: `XXFND_UI_PKG.STATUS_TONE` holds KYC statuses (KYC uses its own rule meanwhile).

## Deploy
App Builder > Import `KYC-Compliance-Platform-APEXlang_105.zip` over KYC (134), Install Supporting Objects = Yes; or run
`run-release.sql` as XXCUS, then import the application. A re-run changes nothing.

## Tests
`features/kyc-requests/tests/r105_request_stages_test.sql` (new), `r104_request_rules_test.sql` (country added);
`r100_duplicate_party_test.sql` removed (rule removed). Older end-to-end tests that expect the status In Progress
(`tests/kyc_flow_test.sql`, `r73_kyc_test.sql`, `r76_kyc_test.sql`, `features/kyc-requests/tests/r74_kyc_test.sql`,
`request_party_test.sql`) need Submitted / Under Review instead - not changed in this release.

## Live checks
1. Requester (TKYC_REQ1): Home tiles; Create Request (two columns, country); Submit -> pop-up; request stage bar.
2. L1: Home "New Requests"; KYC Requests -> New Requests: select two, Assign -> both Under Review with a case.
3. L1 on 206: only Assign, Request Information, Reject.
