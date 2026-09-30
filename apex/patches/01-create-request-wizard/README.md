# Patch 01 – Request module (Create Request wizard, KYC Requests, request page)

Cumulative on top of release 15 (`KYC-Compliance-Platform-APEXlang_15.zip`): everything below is in this one patch.

## What changes

**Create Request, step 1 – Counterparty (page 201)**
- Counterparty Type without an empty choice.
- **Existing counterparty**: search the party list (name, party number, country) and pick it; its details are
  copied to the request. **New counterparty**: enter the details.
- New organisation: name, registration number, entity type, date of incorporation, country.
  New individual: name, date of birth (not in the future), nationality, identity document type and number, country.
  Only the fields of the chosen type are shown, required and saved.
- While a new counterparty is typed, **existing parties that may be the same** are listed, with the reasons:
  same registration / identity document number, name similarity, same date of incorporation / birth, same country.
  The requester can *Use this party*, or confirm that none of them is the counterparty. The requester never merges
  or creates parties.
- **Save as Draft**; changing the type of a draft replaces its questionnaire.

**Step 2 – Questionnaire (page 202)**: a question-and-answer form grouped by section (no grid); Next checks the
required questions; Previous and **Save as Draft** save without checking. Starter sections are set for the
Organization / Person questions where none is set.

**Step 3 – Review and Submit (page 203)**: **Save as Draft**.

**KYC Requests (page 200)**: **Edit** link on the requester's own drafts.

**Compliance decides the counterparty (page 205, workflow, task)**
- A new counterparty that resembles existing parties is held (*Possible match – Compliance to decide*) and always
  goes to Compliance, whatever the intake score.
- The KYC_REQUEST workflow (new version 1.1) first creates a **Counterparty Match** task for Compliance (holders of
  Parties – Manage). On the request page, Compliance **merges** it into an existing party (the request is linked to
  it; the party's empty fields are completed from the request) or **confirms it as a new party**, with a note.
  The decision completes the task and the workflow moves on to the document checklist.
- Version 1.0 of the workflow stays for requests started before this patch.
- The request page shows the linked party and the match status.

## Files

| Patch path | Where it goes |
|---|---|
| `01-db-request-module.sql` | run in SQLcl as the parsing schema (columns, indexes, `XXCMP_REQUEST_PKG`, lookups, sections, task setting) |
| `app/...` | same paths in the release 15 application source (`pages/`, `shared-components/...`, `supporting-objects/...`) |
| `diag-request-workflow.sql` | not part of the patch: shows why a submitted request stays "Processing" |

## Deploy from the APEX screens (no SQLcl)
1. **SQL Workshop > SQL Scripts > Upload** `01-db-request-module.sql` > **Run**. The results at the end must show
   `XXCMP_REQUEST_PKG` VALID and the new lookups (ID_DOCUMENT_TYPE, REQUEST_MATCH_STATUS).
2. **App Builder > Import** the full application zip `KYC-Compliance-Platform-APEXlang_16.zip` (release 15 +
   this patch): choose **Replace existing application** with the same application ID; install supporting objects:
   Yes (safe to re-run) or No (step 1 already did it).
3. Check in SQL Commands:
   `select workflow_static_id, workflow_version, state from apex_appl_workflow_versions where application_id = <app id>;`
   KYC_REQUEST 1.1 Active, 1.0 Inactive.

## Deploy with SQLcl
1. `@01-db-request-module.sql` – the last queries must show `XXCMP_REQUEST_PKG` VALID and the new lookups.
2. Copy the `app/` files over the release 15 source (same relative paths) and import:
   `apex import -input <source folder> -id <app id>`
3. Check: `select workflow_static_id, workflow_version, state from apex_appl_workflow_versions where application_id = <app id>;`
   KYC_REQUEST 1.1 Active, 1.0 Inactive.

The supporting objects in `app/supporting-objects` carry the same database changes, so a later fresh install or
upgrade of the application gets them too.
