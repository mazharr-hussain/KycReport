# Patch 95 - KYC shared screens and components from COMMON (release 88, KYC only)

KYC no longer has its own copy of a COMMON screen. Its menu and pages open COMMON's pages in the same session.
- Removed: My Tasks (40), Workflow Monitor (41), Workflows (44, 45), attachment dialogs (90, 91), Setup (98),
  Administration (100), Review Change (172), features and settings (10020-10023), activity reports (10030-10033),
  feedback (10050-10052), task definition CONFIG-CHANGE. No data is deleted.
- Links: My Tasks -> COMMON 40, Feedback -> COMMON 173, Add Document -> COMMON 47, Shared Setup -> COMMON 100,
  delegated functions -> COMMON 99. The four administration lists are one list, `administration`.
- KYC's LOVs and authorizations that COMMON owns subscribe to COMMON (`@/135/...`): COMMON must be application 135.
- 18h registers no page of a COMMON feature.

## Files
- `db/`: 18h-register-with-common.sql
- removed: `app/pages/p00040-my-tasks.apx`
- removed: `app/pages/p00041-workflow-monitor.apx`
- removed: `app/pages/p00044-workflows.apx`
- removed: `app/pages/p00045-workflow-details.apx`
- removed: `app/pages/p00090-add-attachment.apx`
- removed: `app/pages/p00091-attachment-details.apx`
- removed: `app/pages/p00098-setup.apx`
- removed: `app/pages/p00100-administration.apx`
- removed: `app/pages/p00172-review-change.apx`
- removed: `app/pages/p10020-feature-configuration.apx`
- removed: `app/pages/p10021-feature.apx`
- removed: `app/pages/p10022-application-settings.apx`
- removed: `app/pages/p10023-application-setting.apx`
- removed: `app/pages/p10030-activity-reports.apx`
- removed: `app/pages/p10031-top-users.apx`
- removed: `app/pages/p10032-application-errors.apx`
- removed: `app/pages/p10033-page-performance.apx`
- removed: `app/pages/p10050-feedback.apx`
- removed: `app/pages/p10051-manage-feedback.apx`
- removed: `app/pages/p10052-feedback-follow-up.apx`
- removed: `app/shared-components/task-definitions/CONFIG-CHANGE.apx`
- `app/`: 7 files (see the folder)

## Deploy (KYC only)
1. COMMON 86 is installed (application 135) and KYC is at release 87 or later.
2. Import `KYC-Compliance-Platform-APEXlang_91.zip` over KYC (App Builder import); the supporting objects run the
   upgrade scripts. Data is kept; a re-run changes nothing. Releases 88-91 ship together in this one import; this patch
   describes the part of release 88.

## Tests (one cycle for 88-91)
- Fresh install (COMMON 86 + KYC), re-run over the existing objects, upgrade from release 74 (COMMON, then KYC twice):
  0 errors, no invalid object. APEXlang validation passes.
- New tests pass on the fresh and the upgraded database: kyc88_shared_test 22/22, kyc89_rfi_test 22/22,
  kyc90_cleanup_test 28/28, kyc91_unused_test 14/14; kyc87_adapt_test 23/23.
- Earlier KYC DB tests pass: kyc_flow 23, party 21, request_party 48, token, r73_kyc 9, r74_party 14, r74_case 16,
  r74_email 6, r74_perf 7, r75_kyc 9, r76_kyc 14, monitoring 20 (upgraded; on a new database it needs the browser data).
- Browser tests pass: party_ui 23, r74_party_ui 10, r74_case_ui 10; kyc88_shared_ui 27 of 28.
- **Known failures, caused by COMMON** (`apex/COMMON-ISSUES.md`, not fixed in KYC, COMMON not changed):
  - C1: a business user (requester, officer) is refused on COMMON's shared pages: kyc88_shared_ui (REQ1 My Tasks),
    kyc89_rfi_ui, r74_email_ui, r75_ui, kyc_ui and request_party_ui (steps that open My Tasks), r74_risk_ui.
  - C2: r74_risk_test 1 check (faulted CONFIG_CHANGE workflow).
  - workflow_test: 1-2 checks expect a KYC user (HOC1) on COMMON's CONFIG_CHANGE task.
