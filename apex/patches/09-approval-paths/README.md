# Patch 09 – Approval paths, request summary, party edit (release 24)

Goes on top of patch 08 (release 23, app ID 134).

## What changes for users

### Look
- **Redwood Light** theme style only. Users can no longer switch styles.

### Party (pages 21, 23, 24 and the common party form)
- **Hidden read-only fields:** Party Number, Party Status, Next KYC Date and Last Verified are hidden when a party is created or edited. They show only when the form is read only.
- **Duplicate check on every create and edit** (Create Request, Party dialog, new owner / officer, Party page):
  - The same number and country as another party is still refused.
  - When similar parties exist, **Possible Matches** lists them under the form. The user must switch on **None of the Possible Matches is this party** before saving.
  - On a request, this choice is stored in MATCH_ACK_FLAG. A draft can still be saved without it.
- **Party page (21):**
  - **Edit** (the button, or the Edit link on Parties) opens the form ready to edit in **one click**. *Edit Details* is gone.
  - **Save** stays in edit mode, **Done** leaves it.
  - **Edit / Save / Done / Cancel** are at the top (title bar) and at the bottom.

### Request
- **Create Request step 1:** choosing an existing party shows its summary on the same screen.
- **Common summary regions** are defined once on the Global Page:
  - **Party:** a summary line with **Show details**, and **Edit Party** for Compliance on 205.
  - **Approval Path**
  - **History**

  They are shown on 201, 203 (review: party and the expected path, with each step's role or user) and 205 (party, the path with each step's state, and the history of who did what, when, and with which comments).
- **Approval paths come from setup:** *Administration → Workflow Setup → Request Approval Paths* (page 166).
  - Each row is one step. The rows with the same Path Name make one path.
  - Criteria: Department, Party Type, Country, Request Type. An empty criterion means any.
  - The path that matches the most criteria wins, then the lowest Priority.
  - Each step is approved by a **role** or a **named user**.
  - A *Default* path (one step, Compliance Officer role) is seeded.
- **Workflow KYC_REQUEST 1.3:**
  - It runs one approval task per step. The task subject starts with the step name.
  - The approver has the same screen as the review (205), plus Approve / Reject / Request Information with a comment, and Merge for a duplicate party.
  - The **case is created only when the last step approves**.
  - KYC Required = No: the request is Approved with no case.
  - Rejected or cancelled: no case.
  - Requests already running stay on workflow 1.2.
- **Rights are role based, not person based.** A user who holds both the requester and the Compliance roles can approve their own request (task definitions: *initiator can complete*). Only the Segregation of Duties rules restrict.

## Deploy from the APEX screens
1. Export app 134 as a backup.
2. **SQL Workshop → SQL Scripts → Upload** `09-db-approval-paths.sql` → **Run**. At the end:
   - *no rows* invalid objects
   - APPROVAL_PATH_NAME and CURRENT_STEP listed, and at least 1 approval path row

   The script is idempotent.
3. **App Builder → Import** `KYC-Compliance-Platform-APEXlang_24.zip` → **Replace Existing Application** 134 → **Install Supporting Objects: No**.
4. Optional: add your paths on page 166.

`app/` holds the changed application files: pages 0, 21, 23, 24, 166, 201, 203 and 205; application; theme; breadcrumbs; the task definitions; the KYC_REQUEST workflow; and the supporting objects.

## Tested (local Oracle 26ai + APEX 26.1, app 134)
- `request_party_test.sql` 38/38. It now includes:
  - choosing the path
  - the expected path
  - role and user approvers
  - a live 2-step path where the requester approves step 2 and the case opens only after the last step
- `party_test.sql` and `kyc_flow_test.sql`: all pass.
- Browser tests:
  - `request_party_ui.py` 18/18: the summary and expected path on 203; the path and history on 205; Possible Matches while typing; Next refused until confirmed.
  - `party_ui.py` 19/19: one-click Edit, Save at the top and bottom, read-only fields hidden, the confirmation when similar parties exist.
- `apex validate` passes.

## Known limits
- When a path has more than one step, the checklist task opens for each step. The Request Information response goes back to the current step.
- The expected path shown before submit uses the request's current values. It is fixed at submit.
