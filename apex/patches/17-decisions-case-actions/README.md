# Patch 17 – approval decisions, case actions on top (release 32)

Goes on top of patch 16 (release 31, app ID 134). App only, no database change.

## What changes for users
- **Request approval (206):** Reject, Request Information and Approve sit in one row, in the top bar and again at
  the bottom. Each opens a **Decision** dialog with a comment and a Confirm button (labelled with the decision). The
  comment is **required** (red asterisk) for Reject and Request Information and optional for Approve; Confirm
  without it shows *Enter a comment.* The server checks the same rule.
- **Case (211):** **Assign** and **Withdraw from Approval** moved to the top bar.
- **Case – Risk Assessment:** the Investigation Questionnaire grid has no own Edit / Save toolbar; the page's
  **Save** saves the answers.
- **Case – approver review:** *Suspicious Activity Report Required* shows Yes / No as pills, without the empty
  choice.

## Deploy from the APEX screens
1. Export app 134 as a backup.
2. **App Builder → Import** `KYC-Compliance-Platform-APEXlang_32.zip` → **Replace Existing Application** 134 →
   **Install Supporting Objects: No**.

`app/` holds the changed files: pages 206 and 211, `kyc-app.js`.

## Tested (local Oracle 26ai + APEX 26.1, app 134)
- `request_party_ui.py` 24/24: decision buttons once in the top and once in the bottom bar; Request Information
  opens the dialog with a required comment, refuses an empty comment, then submits; Approve through the dialog.
- `kyc_ui.py` 26/26: approval of the checklist through the dialog, case flow, Assign, read-only pending case with
  Withdraw.
- `apex validate` passes.
