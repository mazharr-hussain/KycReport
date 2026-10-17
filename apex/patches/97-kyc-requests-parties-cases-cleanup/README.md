# Patch 97 - KYC requests, parties and cases cleanup (release 90, KYC only)

One package per component, one copy per routine, no HTML in PL/SQL.
- XXCMP_APPROVAL_PKG merged into XXCMP_REQUEST_PKG and dropped (16g, checked DROP_OBJECT); 16g0 holds only the types.
- XXCMP_PARTY_PKG.GET_PARTY / PARTY_STATUS serve the request package; XXCMP_CASE_PKG.CLOSE_CASE replaces
  APPROVE_CASE / REJECT_CASE; routines only used inside their package are private.
- Page 206 checks are package functions (CAN_DECIDE, CAN_ADD_APPROVER, REQUEST_CASE); Global Page regions Request and
  Document Checklist are shared by 205 / 206.
- QUESTIONNAIRE_HTML removed: page 202 uses the template component KYC Question, fed by SQL (one root element per
  question group, so every answer option shows).

## Files
- `db/`: 16b-kyc-requests-cases.sql, 16e-party-pkg.sql, 16e0-party-pkg-spec.sql, 16g-approval-paths.sql, 16g0-approval-pkg-spec.sql, 16r-request-pkg.sql, 16s-case-pkg.sql
- `app/`: 11 files (see the folder)

## Deploy (KYC only)
1. COMMON 86 is installed (application 135) and KYC is at release 87 or later.
2. Import `KYC-Compliance-Platform-APEXlang_91.zip` over KYC (App Builder import); the supporting objects run the
   upgrade scripts. Data is kept; a re-run changes nothing. Releases 88-91 ship together in this one import; this patch
   describes the part of release 90.

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
