# Request – agreed design

Status: **built in release 23 (patch 08)**. Uses the Party design (`party.md`).

## General rules
- A new counterparty is created as a party **on the fly** when the request is saved (Party Status *Pending*). It
  becomes *Approved* with the request. The requester can edit it while the request is Draft or Information Needed,
  but not once the request is closed, or when the request uses an existing party.
- No RFI on the request screen. *Raise RFI* is removed from page 205; *Request Information* in the approval task
  (workflow) stays.
- Required fields are never hidden on create / edit forms. Lists may hide columns by default.
- Who columns are hidden by default, and users can show them.

## Request screen = 2 parts
1. **Request part** (table `XXCMP_REQUESTS`): the request's own fields, as today for now. More fields may be added later.
2. **Party part**: the **common party form** (the same fields, labels and rules as page 24). It is typed for a new
   counterparty, and read only when an existing party is chosen or after the request is closed.

## Request part fields
| # | Field | Column(s) | Rule |
|---|---|---|---|
| Q1 | Request Number | REQUEST_NUMBER | automatic |
| Q2 | Request Type / Trigger | REQUEST_TYPE, TRIGGER_SOURCE | automatic |
| Q3 | Parent (reviews) | PARENT_REQUEST_ID, PARENT_CASE_ID | automatic |
| Q4 | Party choice | PARTY_SELECTION | Existing / New |
| Q5 | Party | PARTY_ID | the chosen or created party |
| Q7 | Contact person | CONTACT_NAME, CONTACT_EMAIL, CONTACT_PHONE | **kept in the table and on the screen, but hidden** on create / edit / view. Switched on later with the APEX build option (Shared Components → Build Options), with no code change. |
| Q8 | Requesting Department | REQUESTING_DEPARTMENT | default: the requester's department; only Compliance can change it |
| Q9 | Requested By | REQUESTER_USER_NAME | automatic |
| Q10 | Justification | JUSTIFICATION | **required**, on the request screen |
| Q11 | Questionnaire / Score | QUESTIONNAIRE_CODE, INTAKE_* | automatic |
| Q12 | Match decision | MATCH_* | Compliance, in the checklist task |
| Q13 | Status / Dates | REQUEST_STATUS, SUBMITTED_DATE, COMPLETED_DATE | automatic |
| Q14 | Workflow | WORKFLOW_ID | automatic |
| Q15 | Who columns | … | hidden by default |

The counterparty columns on the request (PARTY_TYPE, PARTY_NAME, JURISDICTION, REGISTRATION_NUMBER, ENTITY_TYPE,
INCORPORATION_DATE) follow the Party merge. NATIONALITY, ID_NUMBER, ID_TYPE and DATE_OF_BIRTH are moved and dropped.

## Status and tracking fields
| Field | Column | Rule |
|---|---|---|
| Status | REQUEST_STATUS | **Draft, In Progress, Information Needed, Approved, Rejected, Cancelled**. Existing data is moved: SUBMITTED / IN_PROGRESS → In Progress, COMPLETED → Approved. The separate "Stage" wording is removed. |
| KYC Required | *derived from INTAKE_OUTCOME (no new column)* | **Yes** = the approval workflow runs (Compliance review). **No** = approved automatically (KYC not required, or auto-approved). |
| Pending With | *derived from the open workflow task* | Draft / Information Needed → the requester; In Progress → the Compliance user holding the task, or "Compliance" if unclaimed; closed → empty |
| Action Date | **LAST_ACTION_DATE** (new, DATE) | set on every step: save, submit, information requested / answered, approve, reject, cancel |

Status flow: Draft → In Progress ⇄ Information Needed → Approved / Rejected. **Cancel** is allowed by the requester in
Draft, In Progress and Information Needed; a running workflow and its task are ended.

## List (page 200)
Shown: Request, Counterparty, Status, KYC Required, Pending With, Action Date, Department, Requested By, Case,
Edit (drafts only). Hidden, available: Type, Intake Score, Submitted, Who columns.

## Create Request wizard
| Step | Content |
|---|---|
| 1 · Request & Counterparty (201) | Region *Request*: Department, Justification (required), Contact person (hidden by build option). Region *Counterparty*: Existing / New. Existing → search, then the party card (read only). New → the **common party region** (Global Page, same screen). **Possible matches** are shown as a warning. Buttons: Cancel Request, Save Draft, Next. |
| 2 · Questionnaire (202) | no change |
| 3 · Documents & Submit (203) | no change; mandatory documents are checked on Submit |

The match decision in Compliance's checklist task is replaced by **Merge** (Compliance merges a duplicate party).

## Request page (205)
| Region | Content |
|---|---|
| Request | Status, KYC Required, Pending With, Action Date, counterparty, type, intake result, requested by, Business Justification, party, case |
| Party | the common party card; Edit Party for Compliance |
| Information Needed (requester) | Compliance's question, Your Answer, **Respond** (the request goes back In Progress) |
| Possible Duplicate Parties (Compliance, Pending party) | similar parties with **Merge into this party** (replaces the old match decision) |
| Answers, Document Checklist, Documents, Approval | as before |
| Checklist Decision (Compliance holding the task) | Comment, Approve – Open Case, Reject Request, Request Information (Raise RFI removed) |
| Buttons (requester) | Edit Request (Draft / Information Needed), Cancel Request (Draft / In Progress / Information Needed) |
