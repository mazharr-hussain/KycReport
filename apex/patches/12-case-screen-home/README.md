# Patch 12 – Case screen with sections, home KPI tiles (release 27)

Goes on top of patch 11 (release 26, app ID 134). Items 13–18 of the latest review.

## What changes for users

### Case screen (Cases → a case)
- **Section list on the left** (one section at a time, no long scrolling). Each section shows its state: ✔ done, ● current, ○ to do, ⚠ open RFI. The progress (for example 5 / 8) is shown under the list:
  1. **Summary:** case, party, status, SLA, request, officer.
  2. **Party:** the **same Global Page regions** as the party and request screens (party details, additional information).
  3. **Contacts and Ownership:** the shared Contact Persons and Owners and Officers regions, plus the case's beneficial owner determinations.
  4. **Screening**
  5. **Documents:** the shared Party Documents, plus the case's Document Verification.
  6. **Risk Assessment:** risk tier, Enhanced KYC, PEP, next review, conditions, and the investigation questionnaire.
  7. **Notes and RFIs:** one timeline of notes and requests for information (filter: all / notes / RFIs / open RFIs), with Add Note and Raise RFI.
  8. **Review and Submit:** every section read only, plus the **Approval History** table. **Submit for Approval is only here.**
- **Buttons:** **Save** and **Next Section** in every section. Compliance edits the party regions in place while the case is under investigation.
- **Removed:** the Workflow diagram region and the party card with Edit Party.
- **Approval History** (on Review):
  - case opened, investigation (claimed / submitted), each approval level with approver, outcome, by, date and comments
  - then the Pending and Waiting levels from the approval matrix (Expected while investigating)
- **Approvers:**
  - The CASE_APPROVAL task opens the **same case screen in review mode**: all sections read only, the Approval History, and the Decision (SAR determination, conditions, next review, comment).
  - **Reject on the left and Approve on the right, at the top and the bottom.**
  - The Case Decision drawer (212) is no longer used.

### Home
- **My Work** tiles, each a link to the matching list filtered:
  - **My Open Requests** → KYC Requests, mine
  - **Information Needed** → KYC Requests, Information Needed
  - **Pending My Approval** → My Tasks
  - **My Open Cases** → Cases, assigned to me
  - **Overdue Cases** → Cases, Overdue
  - **Open RFIs** → Requests for Information
- **Visibility:** a tile shows only with the privilege of the screen it opens; requesters do not see the case tiles. Counts follow data security.

## Deploy from the APEX screens
1. Export app 134 as a backup.
2. **SQL Workshop → SQL Scripts → Upload** `12-db-case-screen.sql` → **Run**. At the end:
   - *no rows* invalid objects
   - the 8 CASE_SECTION rows

   The script is idempotent.
3. **App Builder → Import** `KYC-Compliance-Platform-APEXlang_27.zip` → **Replace Existing Application** 134 → **Install Supporting Objects: No**.

`app/` holds the changed files:
- pages 0, 1 and 211
- the CASE_APPROVAL task definition, which now opens 211
- the stylesheet
- the supporting objects

## Tested (local Oracle 26ai + APEX 26.1, app 134)
- `kyc_ui.py` 24/24, which covers:
  - the case screen: section list, the shared Party regions, Risk saved in its section, Submit only on Review
  - the Approval History, the refused submit, the screening drawer, the section state, Notes and RFIs
  - the approver review mode with Approve / Reject at the top and the bottom
  - the home tiles
- `request_party_ui.py` 24/24 and `party_ui.py` 22/22, run again after the Global Page change
- `apex validate` passes.

## Notes
- **Case approvals have no Request Information.** The officer raises RFIs on the case (Notes and RFIs). An APEX information request would go to the task's initiator, not to the officer.
- **Page 212 (Case Decision)** stays in the app but is no longer linked. It can be removed in a later clean-up.
