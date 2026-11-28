# KYC 107 - sign-in works on COMMON 111+; cancel a request after it is submitted

On top of KYC 106 (and COMMON 129). Deployed and tested by the COMMON pipeline (job K for the database; no browser test
of KYC yet).

| Issue | Change |
|---|---|
| I-001 (#136) | The authorization scheme `kyc-user` called `authorized('KYC_USER')`, retired in COMMON 111 (COMMON answers false for it), so the application, its application processes and every page that uses the scheme refused every user. It now calls `authorized('APP_USER')`. |
| I-004 (#139) | Cancel after submit (stage gap G2). `XXCMP_REQUEST_PKG.CANCEL_ERROR` lets the requester cancel from Draft, Submitted, Under Review, In Approval, Information Needed (Rejected as before) until the case is decided. `CANCEL` also cancels the open case through the new `XXCMP_CASE_PKG.CANCEL_CASE` (workflow and approval ended, status Cancelled; the request follows through `CASE_CHANGED`). Page 200: a Cancel action with a confirmation on the requester's Submitted, Under Review and In Approval requests. |
| I-009 (#144) | Found already done: KYC 106 moved the end-to-end tests to the KYC 105 statuses (the one remaining `IN_PROGRESS` in `r73_kyc_test.sql` is a "not" check). Linked so it closes with this release. |

## Database
No table, column, constraint or seed change. `XXCMP_CASE_PKG` (spec + body): `CANCEL_CASE`. `XXCMP_REQUEST_PKG` (body +
spec comment): `CANCEL_ERROR`, `CANCEL`. The packages are recompiled by the install / upgrade run (`CREATE OR REPLACE`).

## Tests
- `features/kyc-requests/tests/r105_request_stages_test.sql`: an approved request cannot be cancelled; Under Review and In Approval can; cancel after submit gives Cancelled; not twice.
- `features/kyc-requests/tests/request_party_test.sql`: a Submitted request can be cancelled (it expected "withdraw it first").
- Not covered by a DB test: `CANCEL_CASE` on a real case with a running workflow (the tests simulate case changes).

## Live checks (browser, test users TKYC_*)
1. Any KYC user (for example TKYC_REQ1) opens the application: no "You do not have access" page.
2. TKYC_REQ1 submits a request, then on KYC Requests (200) clicks Cancel and confirms: status Cancelled.
3. Submit, have L1 Assign (Under Review), then Cancel as the requester: request and its case are Cancelled; the contributor's task is gone.
4. An Approved request shows no Cancel action.

## Not in this release (agreed changes still open)
#137 one approval process per component, #138 L1 pipeline view, #140 return to the contributor, #141 notify the
requester on stage changes, #142 the 5 screening questions (needs the staging PDF), #143 question display types, #170
training material (after the KYC changes).
