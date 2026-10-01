# Patch 10 – Request and party journey (release 25)

Goes on top of patch 09 (release 24, app ID 134). It covers the issues reported after release 24, items 1–21.

## What changes for users

### Requests
- **List (200):**
  - Sorted by request number, newest first.
  - Each column header sorts and filters (Excel-like), and the list downloads to **Excel** or CSV.
  - The **Action** column follows the status (requester only):
    - **Edit** for Draft and Information Needed. **Cancel Request** is on the edit screen.
    - **Withdraw** while the request waits for approval. It ends the workflow and sets the request back to Draft, where it can be edited or cancelled.
- **Create / edit wizard, now 4 steps:**
  1. **Counterparty**
  2. **Party Details:** additional information, contact persons, owners / officers, documents. They can be changed only when this request created the party (new counterparty). An existing party, even a Pending one, is read only.
  3. **Questionnaire**
  4. **Review and Submit:** everything expanded (party in full, its details, answers, documents, the approval path).
  - When a request is Information Needed, the question and **Respond** are on the review step.
- **Request view (205, the request number on the list):** read only, with **Back** only.
  - No Cancel Request, Add Document or Edit Party.
  - The Merge Note shows only if the party was merged.
- **Approval screen (206, opened from My Tasks):**
  - The same summary as the request view.
  - **Approve / Reject / Request Information** at the top and the bottom. A comment is required for Reject and Request Information.
  - **Merge into this party** opens a popup with a required Merge Note. There is no merge box on the page.
- **Approval history:** one table on review, view and approval. It shows the step, approver, action / status, by, date and comments:
  - before submit, the expected steps
  - after submit, what happened, then the Pending step and the Waiting steps
  - including the withdraw
- **Party region:** the full party details, without a "Show details" link and without the party status.

### Similar parties (every party save: 23, 24, 201)
- The switch is gone. On Next / Create, when similar parties exist, a dialog lists them with two buttons:
  - **Confirmed – none of these is this party:** saves with MATCH_ACK_FLAG = Y on a request.
  - **A possible match exists:** saves with MATCH_ACK_FLAG = N, so Compliance can merge later.
- The same number and country is still refused.

### Parties
- **List (20):** sorted by party number, Excel-like headers, Excel download. **Edit** opens the wizard.
- **Party wizard**, the same journey as a request:
  1. **Party Information** (24, the common party form)
  2. **Party Details** (25)
  3. **Review** (21)

  Create Party and Edit both use it.
- **Party view (21):** the summary, read only, with **Back / Edit** at the top and the bottom.
- **Field order:**
  - Organisation: Entity Type before Name.
  - Individual: ID Type before ID Number.

### Built once
- The party form, Party, Additional Information, Contact Persons, Owners and Officers, Party Documents, Questionnaire Answers, Request Documents and Approval History are regions on the **Global Page**.
- They are used by the party screens, the request wizard, the request view and the approval screen.

### Readability
- An app-wide stylesheet (`css/kyc-app.css`, Redwood Light) adds:
  - larger text
  - clear region and report headers
  - read-only values without input boxes

### Security
- Contact person and owner / officer dialogs (22, 23) are open to Parties users, and to a requester working on the party their own request created (schemes *Party Details – View/Create/Manage/Submit*).
- A new owner added by a requester is a **Pending** party.
- Requesters can download the documents of their request's party.

## Deploy from the APEX screens
1. Export app 134 as a backup.
2. **SQL Workshop → SQL Scripts → Upload** `10-db-request-party-journey.sql` → **Run**. At the end:
   - *no rows* invalid objects
   - XXCMP_HISTORY_ROW and XXCMP_HISTORY_TAB listed

   The script is idempotent.
3. **App Builder → Import** `KYC-Compliance-Platform-APEXlang_25.zip` → **Replace Existing Application** 134 → **Install Supporting Objects: No**.

`app/` holds the changed application files:
- pages 0, 20–25, 200–206
- application (stylesheet)
- authorizations, breadcrumbs, lists (request and party wizards), application processes (similar parties, document download), static files
- task definitions (they now open 206)
- supporting objects

## Tested (local Oracle 26ai + APEX 26.1, app 134)
- **DB tests** (all pass):
  - `request_party_test.sql` 41/41, including withdraw then cancel, and the withdraw in the history
  - `party_test.sql` 21/21
  - `kyc_flow_test.sql` 23/23
- **Browser tests:**
  - `request_party_ui.py` 21/21: the 4 steps; the requester adds a contact person; the review content; the read-only view; history; the list order and Withdraw; the approval screen buttons top / bottom; the RFI comment rule; Respond on the review step; Approve; the similar-parties dialog (N stored); Merge popup; Withdraw → Edit → Cancel.
  - `party_ui.py` 22/22: list order and Excel; view; wizard edit / create; read-only fields hidden; the dialog; contact person; new owner; field order and labels; Done; merge.
  - `kyc_ui.py` 18/18
- `request_approval_ui.py` is retired: the request page no longer carries the decision, and `request_party_ui.py` covers the approval screen.
- `apex validate` passes.

## Open / known limits
- **Registration Type (organisation, item 10):** not built. I need the column name and size on XXCMP_PARTIES (and XXCMP_REQUESTS), its list of values, and whether it is required.
- The detail regions on the Global Page are classic reports, because interactive reports can't sit on the Global Page. So the who columns can't be switched on there.
- A user named in an approval step (USER approver) who has no Compliance role sees only their own requests through data security. Their task opens, but the request data may be hidden. Approving by role is not affected.
- Closing the similar-parties dialog with the X counts as "A possible match exists".
- *Edit Party* on the case page (211) now opens the party wizard and doesn't return to the case.
