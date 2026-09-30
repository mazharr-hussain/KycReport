# Request – agreed design (in progress)

Status: **being agreed**. Nothing below is built yet. Uses the Party design (`party.md`).

## General rules
- A request creates the party if none exists. The requester can't change the party once the request is closed,
  or when the request uses an existing party.
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

## Open
- Stage wording (today Draft / Processing / In Progress / Completed – KYC not required / Completed – approved /
  Rejected).
- List (page 200) columns.
- Wizard steps (201–203) and the Request page (205).
