# kyc-requests

Feature of KYC Compliance Platform.

## Release 99 - requester area
- Create Request is 3 steps: Counterparty (201, with the Risk Screening), Party Details (204), Review and Submit (203);
  page 202 is no longer in the wizard.
- Risk Screening (201): the requester questionnaire plus "Business counterparty ownership structure type" (18k);
  Check saves the draft and answers (`SAVE_SCREENING`) and shows the outcome (`SCREENING_OUTCOME`, the same private rule
  `INTAKE_RULE` as `EVALUATE`). Business Relationship Type and Justification only when KYC is required.
- Request form rules: `REQUEST_ERROR` calls `XXCMP_PARTY_PKG.PARTY_ERROR` with `P_REQUEST_FORM = Y` (no registration
  type for an organisation, no email / phone, no stop on a duplicate number).
- A requester (no Cases - View) sees Next Steps on 203 and a History without approvers on 205, no questionnaire regions
  (Global Page regions request-next-steps, request-history-requester). Home: department tiles and Create Request.

## Uses (objects of these features are named in its files)
cases, common:approval-setup, common:attachments, common:data-security, common:information-requests, common:lookups, common:roles-privileges, common:workflow-setup, kyc-rules, parties

## Used by
cases, dashboard, home, kyc-rules, monitoring, parties

## Files
- `db/packages/xxcmp_approval_pkg.sql`
- `db/packages/xxcmp_request_pkg.sql`
- `db/packages/xxcmp_request_ui_pkg.sql`
- `db/sequences/xxcmp_request_number_s.sql`
- `db/tables/xxcmp_approval_paths.sql`
- `db/tables/xxcmp_request_answers.sql`
- `db/tables/xxcmp_requests.sql`
- `db/types/xxcmp_history_row.sql`
- `db/types/xxcmp_history_tab.sql`
- `pages/p00200-kyc-requests.apx`
- `pages/p00201-create-request.apx`
- `pages/p00202-create-request-questionnaire.apx`
- `pages/p00203-create-request-submit.apx`
- `pages/p00204-create-request-party-details.apx`
- `pages/p00205-kyc-request.apx`
- `pages/p00206-kyc-request-approval.apx`
- `shared-components/lists.apx`
- `shared-components/task-definitions/COUNTERPARTY-MATCH.apx`
- `shared-components/task-definitions/DOC-CHECKLIST-REVIEW.apx`
- `shared-components/workflows/KYC-REQUEST.apx`
- `tests/r74_kyc_test.sql`
- `tests/r99_requester_test.sql`
- `tests/request_party_test.sql`
- `tests/request_party_ui.py`
