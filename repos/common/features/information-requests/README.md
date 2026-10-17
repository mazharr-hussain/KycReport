# Information Requests (RFI)

COMMON component, module Workflow.

## Purpose
Asking someone (a colleague or an outside person) for information on a record, with the answer loop (RFI workflow).

## Usage
The RFI is created by the application; the answer is given on COMMON page 143 (from My Tasks) or, by an outside person, on the public page 50 with a one-time link.

## Benefit
One RFI process, with e-mail and an answer page, for every application.

## Depends on (objects of these components are named in its files)
applications, approval-setup, data-security, lookups, notifications, roles-privileges, workflow-setup

## Used by (COMMON components)
lookups, my-tasks, notifications, roles-privileges, workflow-setup

## Installation requirements
COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites check 00a first; 00b stops an install in the wrong schema). The RFI process switched on for the application (Workflow Setup > Process Catalogue); e-mail for outside people.

## Application objects
### Pages
- 50 Provide Information (`pages/p00050-provide-information.apx`)

### Shared components
- `shared-components/task-definitions/RFI-RESPONSE.apx`
- `shared-components/task-definitions/RFI-REVIEW.apx`
- `shared-components/workflows/RFI.apx`

## Database objects (schema XXFUSION)
- tables: `XXFND_RFIS`
- views: `XXFND_QA_HISTORY_V`
- packages: `XXFND_RFI_PKG`
- types: `XXFND_QA_ROW`, `XXFND_QA_TAB`
- triggers: `XXFND_RFIS_BI`

## Roles and privileges
No feature of its own.
Roles at install: No feature of its own: answering uses My Tasks; the public page 50 needs no sign-in (a one-time token).

## How another application uses it
1. The application is onboarded (Applications). 2. Its schema gets the grants and creates synonyms for the COMMON objects (as KYC script 03 does). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type "page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles in the COMMON console.

The application creates an RFI with `XXFND_RFI_PKG.CREATE_RFI` (entity, key, recipient), sends the link with `SEND_EMAIL`, and reads `OPEN_COUNT` / `IS_WAITING`. COMMON issue C5: no documents or due dates on RFIs.

### Public routines
- `XXFND_RFI_PKG`: ANSWER_WAIT, ASK_AGAIN, CREATE_RFI, IS_EXTERNAL, IS_WAITING, OPEN_COUNT, QUESTION_BY_TOKEN, RECIPIENT, RESOLVE, RESPOND, RESPOND_BY_TOKEN, REVIEWERS, SEND_EMAIL, SYNC_SEQUENCES, TASK_CREATED, TASK_MESSAGES, TASK_VALUES

## Tests
- in `../../tests/` (whole application)

## Files
- `db/packages/xxfnd_rfi_pkg.sql`
- `db/tables/xxfnd_rfis.sql`
- `db/triggers/xxfnd_rfis_bi.sql`
- `db/types/xxfnd_qa_row.sql`
- `db/types/xxfnd_qa_tab.sql`
- `db/views/xxfnd_qa_history_v.sql`
- `pages/p00050-provide-information.apx`
- `shared-components/task-definitions/RFI-RESPONSE.apx`
- `shared-components/task-definitions/RFI-REVIEW.apx`
- `shared-components/workflows/RFI.apx`
