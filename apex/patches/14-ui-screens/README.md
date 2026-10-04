# Patch 14 – UI/UX screens (release 29)

Goes on top of patch 13 (release 28, app ID 134). It applies `apex/UIUX-STANDARD.md` to the screens: backlog items
UX-1 to UX-15.

## What changes for users

### Home (UX-1, defect 19)
- KPI cards replace the tiles; the whole card is the link.
- One **My Tasks** list with a type badge, party and due/overdue date; the RFIs addressed to you are rows of it.
  *View all* opens My Tasks. The welcome and separate RFI regions are gone.
- Task links carry a checksum (defect 19 *No checksum was provided*).

### Lists (UX-2, UX-9): KYC Requests, Cases, Parties, RFIs
- Statuses as coloured badges; people as the employee name, with a small card on hover (name, employee no.,
  department, user name).
- Case number is a link on KYC Requests; fewer default columns.

### Request pages (UX-3, UX-6, UX-8, UX-10): 203, 205, 206
- Header card with number, status and party; a left **section menu** links to each region on the page.
- Request details in a label-above grid (merge note included); questionnaire answers as Q&A pairs with risky and
  critical answers flagged and the score.
- 206: one sticky action bar with the comment and Approve / Reject / Request Information (no duplicates at the top).
- No *Back* button; the page no longer jumps to the comment box on open.

### Party (UX-4, UX-5)
- Party card: name as title, number, relationship badges, groups Identity · Contact · KYC.
- *Additional Information* hidden when empty; contacts and owners as compact lists.

### Create Request wizard (UX-7)
- Counterparty choice first, as large pills; buttons in a sticky footer.
- **Fixed:** a double click on Next could create the request (or party) twice.

### Case (UX-11 to UX-15)
- Header card: status, risk, Enhanced / PEP / SLA badges, assignee.
- *Party* and *Contacts and Ownership* are one *Party* section.
- **Assigned To** is text with an **Assign** button (dialog: user + comment; a case note records it). The default
  assignee is the approver of the request's first approval step; open cases are back-filled.
- Notes: pill filter (All · Notes · RFIs · Open RFIs) works; *Add Note* opens a dialog.
- Review and Submit: a summary grid instead of empty disabled boxes and codes.
- After *Submit for Approval* the case is **read only** with **Withdraw from Approval** (reason required): the
  approval stops and the case goes back to Investigation.

### Not in this patch (still open)
Saved report tabs on KYC Requests, row actions menu, approval history as a timeline, decision dialogs on 206,
badges in the section menu, sentence case.

## Deploy from the APEX screens
1. Export app 134 as a backup.
2. **SQL Workshop → SQL Scripts → Upload** `14-db-ui-screens.sql` → **Run**. At the end: *no rows* invalid objects.
   The script is idempotent.
3. **App Builder → Import** `KYC-Compliance-Platform-APEXlang_29.zip` → **Replace Existing Application** 134 →
   **Install Supporting Objects: No**.

`app/` holds the changed files: pages 0, 1, 20, 30, 200-206, 210, 211; app processes (PERSON_CARD);
`kyc-app.css`, `kyc-app.js`; supporting objects (16b, 16e, 16h, 16i, 18e).

DB objects: `xxcmp_request_ui_pkg` (new, 16i); `xxfnd_ui_pkg` (person_tag, kpi_card); `xxcmp_party_pkg.card_html`;
`xxcmp_case_pkg` (sections, first_approver, assign, withdraw); check constraint `xxcmp_case_decisions_ck1` allows
WITHDRAWN; lookup CASE_SECTION without OWNERSHIP.

## Tested (local Oracle 26ai + APEX 26.1, app 134)
- `14-db-ui-screens.sql` runs clean, no invalid objects; `apex validate` passes.
- `kyc_ui.py`: full run 25/26; the remaining check (pending case opened from the Cases list is read only
  with Withdraw, no error) failed only because the test counted buttons in hidden dialogs. The test now counts
  visible buttons; it was re-checked on its own and passes.
- Single submit on Create Request checked 4/4 (no duplicate request or party).
- `request_party_ui.py` and `party_ui.py`: updated for the new 206 action bar; to be re-run on this release.
