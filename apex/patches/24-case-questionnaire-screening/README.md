# Patch 24 – case questionnaire and screening dialog (release 39)

Goes on top of patch 23 (release 38, app ID 134). No database change.

## What changes
- **Case → Risk Assessment → Investigation Questionnaire (211):** the grid opens ready to type: click an answer and
  write (before, a cell only opened on double-click, so it looked read only). One **Answer** column (was
  *Findings*); the *Choice* column shows only when an officer question has answer options; no row checkboxes.
  The **Enhanced Due Diligence** questions (source of funds, source of wealth) show only when the case is
  Enhanced KYC, the only time *Submit for Approval* asks for them.
- The questions come from **Setup → Questionnaires → Officer Investigation Questionnaire** (they are not fixed in the
  code): add, change or disable questions there; new cases get the enabled ones.
- **Screening dialog (213):** no Party field; the screening is recorded for the case's party.

## Deploy
1. Export app 134 as a backup.
2. **App Builder → Import** `KYC-Compliance-Platform-APEXlang_39.zip` → **Replace Existing Application** 134 →
   **Install Supporting Objects: No**. Make the SSO scheme current again if you use it.

`app/` holds the changed pages 211 and 213.

## Tested (local Oracle 26ai + APEX 26.1, app 134)
- `apex validate` passes.
- Browser: Enhanced KYC case, Risk Assessment: the grid is in edit mode; typed source of funds / wealth saved with
  the section's Save. `kyc_ui.py` 26/26 (incl. adding a screening without the Party field).
