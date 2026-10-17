# kyc-requests

Feature of KYC Compliance Platform. Copied as it is from the current application (no change).

## Uses (objects of these features are named in its files)
cases, common:approval-setup, common:attachments, common:data-security, common:information-requests, common:lookups, common:roles-privileges, common:users-access, common:workflow-setup, kyc-rules, parties

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
- `tests/request_party_test.sql`
- `tests/request_party_ui.py`
