# Patch 26 – due diligence type (release 41)

Goes on top of patch 25 (release 40, app ID 134).

## What changes
- **Case → Risk Assessment:** *Enhanced KYC* (switch) is replaced by **Due Diligence Type**, a list from the lookup
  **DUE_DILIGENCE_TYPE**: Simplified KYC, Standard KYC, Enhanced KYC (required).
- A confirmed screening match or a PEP flag still makes the case **Enhanced**; Enhanced still means two approval
  levels and the source of funds / wealth questions (the Enhanced KYC flag now follows the type).
- Shown as *Due Diligence Type* on the case summary, the Cases list (column was *KYC Level*), the approval decision
  and the compliance report.
- Existing cases: Enhanced where the flag was set, otherwise Standard.

DB: column `XXCMP_CASES.DUE_DILIGENCE_TYPE varchar2(30)`; trigger `XXCMP_CASES_DD` keeps `ENHANCED_KYC_FLAG` = Y
exactly when the type is ENHANCED; `XXCMP_CASES_LOCK` lets the one-time fill through on closed cases; lookup
DUE_DILIGENCE_TYPE (system); `xxcmp_request_ui_pkg.case_summary_html`.

## Deploy
1. Export app 134 as a backup.
2. **SQL Workshop → SQL Scripts → Upload** `26-db-due-diligence-type.sql` → **Run**. At the end: *no rows* invalid
   objects. Idempotent.
3. **App Builder → Import** `KYC-Compliance-Platform-APEXlang_41.zip` → **Replace Existing Application** 134 →
   **Install Supporting Objects: No**. Make the SSO scheme current again if you use it.

`app/` holds the changed files: pages 210, 211, 217; supporting objects 16b, 16i, 17.

## Tested (local Oracle 26ai + APEX 26.1, app 134)
- DB script clean, no invalid objects; existing cases filled (19 Enhanced, 68 Standard); `apex validate` passes.
- Browser: Risk Assessment list shows the three types; Simplified saved → flag N, no EDD questions; Enhanced →
  flag Y, EDD questions shown. `kyc_ui.py` 26/26.
