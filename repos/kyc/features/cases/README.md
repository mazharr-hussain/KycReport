# cases

Feature of KYC Compliance Platform. Copied as it is from the current application (no change).

## Uses (objects of these features are named in its files)
common:applications, common:approval-setup, common:attachments, common:communications, common:data-security, common:information-requests, common:lookups, common:roles-privileges, common:users-access, common:workflow-setup, kyc-requests, kyc-rules, parties

## Used by
dashboard, home, kyc-requests, kyc-rules, monitoring, parties

## Files
- `db/packages/xxcmp_case_pkg.sql`
- `db/seed/xxcmp_cases.sql`
- `db/sequences/xxcmp_case_number_s.sql`
- `db/sequences/xxcmp_rfi_number_s.sql`
- `db/tables/xxcmp_case_decisions.sql`
- `db/tables/xxcmp_case_notes.sql`
- `db/tables/xxcmp_cases.sql`
- `db/tables/xxcmp_doc_verifications.sql`
- `db/tables/xxcmp_rfis.sql`
- `db/tables/xxcmp_screenings.sql`
- `db/tables/xxcmp_ubo_determinations.sql`
- `db/triggers/xxcmp_cases_dd.sql`
- `db/triggers/xxcmp_cases_lock.sql`
- `db/triggers/xxcmp_rfis_num.sql`
- `pages/p00210-cases.apx`
- `pages/p00211-case.apx`
- `pages/p00213-screening.apx`
- `pages/p00215-document-verification.apx`
- `pages/p00216-create-case.apx`
- `pages/p00217-compliance-report.apx`
- `pages/p00218-source-of-funds.apx`
- `pages/p00219-fiu-report.apx`
- `shared-components/lists.apx`
- `shared-components/lovs.apx`
- `shared-components/task-definitions/CASE-APPROVAL.apx`
- `shared-components/task-definitions/CASE-INVESTIGATION.apx`
- `shared-components/workflows/KYC-CASE.apx`
- `tests/r74_case_test.sql`
- `tests/r74_case_ui.py`
