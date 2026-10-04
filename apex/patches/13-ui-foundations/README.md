# Patch 13 – UI/UX foundations (release 28)

Goes on top of patch 12 (release 27, app ID 134). It is chunk 1 of `apex/UIUX-STANDARD.md`: the app-wide look and the
shared helpers that the next chunks use page by page. It also fixes defect 20.

## What changes for users

### Every page
- **Plain title bar:** the Redwood pattern strip under the page title is gone, replaced by a thin line. The page title is
  26px bold and the breadcrumb is smaller above it.
- **Section titles:** 20px bold on a shaded strip with a dark bar on the left, so each section stands apart.
- **Labels above the fields**, not floating inside them: 13px bold dark grey, with a red asterisk on required fields.
  The small "Required" text under each field is gone. Fields fill their column up to a readable width.
- **Read-only values:** 15px bold, shown as text (no grey bars).
- **Tables:** column headers 14px bold on a darker row; data 14px with more room per row.

### Defects
- **#20 – opening a case from the Cases screen** no longer fails with *Task Not Found*. The Approve / Reject buttons on
  the case screen now check that the case was opened from a task before asking APEX about it.
- **#19 – "No checksum was provided" from the Home tiles:** not reproduced locally. The tile links carry a checksum here,
  also for a user name with `@`. Open item: send the tile's link (right-click → Copy link) from your environment.

### Shared helpers (for the next chunks; no screen uses them yet)
- `xxfnd_ui_pkg.status_badge(object, code)`: status badge with one colour map (request, party, case, match,
  screening, document, risk).
- `xxfnd_ui_pkg.person_html(user_name)`: the employee name, with a hover card showing name, employee no., department and
  user name. `person_name` gives the plain name.

## Deploy from the APEX screens
1. Export app 134 as a backup.
2. **SQL Workshop → SQL Scripts → Upload** `13-db-ui-foundations.sql` → **Run**. At the end: *no rows* invalid objects.
   The script is idempotent.
3. **App Builder → Import** `KYC-Compliance-Platform-APEXlang_28.zip` → **Replace Existing Application** 134 →
   **Install Supporting Objects: No**.

`app/` holds the changed files:
- every page with form items (label template Optional/Required – Above)
- page 211 (defect 20)
- the theme defaults, the stylesheet
- the supporting objects

## Tested (local Oracle 26ai + APEX 26.1, app 134)
- `request_party_ui.py` 24/24, `party_ui.py` 22/22, `kyc_ui.py` 24/24 with the labels above on every form
- screenshots of Home, KYC Requests, a request, Create Request, Cases and a case opened from the Cases list (no error)
- `xxfnd_ui_pkg`: badge colours and the employee hover card checked in SQL
- `apex validate` passes
