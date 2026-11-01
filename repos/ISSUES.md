# Issue backlog (COMMON and KYC)

The one list of every issue: reported by the user, found in a review, or a COMMON gap found by an application.
Each issue keeps its number for good. **Status:** Open (reported, no plan yet) - Planned (in an approved plan, being built) -
Agreed later (accepted, waits for its own plan and approval) - Parked (the user put it on hold) - Fixed (release named).
Rules: issues are collected first, then a plan, then approval (CLAUDE.md). Update this file with every release: add the
new issues, move fixed ones to Fixed with the release. COMMON gaps keep their detail in
`repos/common/docs/COMMON-ISSUES.md` (C-numbers); release details are in `repos/<app>/releases/NNN-*/README.md`.
Releases before COMMON 108 / KYC 101 are not itemised here - see their release READMEs.

## Open and agreed (backlog)
| # | App | Area / screen | Issue | Status | Source |
|---|---|---|---|---|---|
| I-001 | KYC | Authorization `kyc-user` | Calls `authorized('KYC_USER')`, retired in COMMON 111 - must call `APP_USER`; deploy with COMMON 111+ (until then every KYC user is refused) | Agreed later (KYC) | C18 |
| I-002 | KYC | Approval processes | One approval process for the KYC case and one for the request, rules and approval groups on the COMMON Process page (today many risk-tier rules) | Agreed later (KYC) | User, COMMON 113 |
| I-003 | KYC | Home (L1) | L1 KPIs / pipeline view of all stages at a glance (different from the requester KPIs) | Agreed later (KYC) | User |
| I-004 | KYC | Request stages - G2 | Cancel a request after it is submitted | Agreed later (KYC) | Stage review |
| I-005 | KYC | Request stages - G4 | Return to the contributor | Agreed later (KYC) | Stage review |
| I-006 | KYC | Request stages - G5 | Notify the requester (stage changes) | Agreed later (KYC) | Stage review |
| I-007 | KYC | Screening questions | Replace with the 5 questions of the staging PDF; score >= 8 = KYC Required, else KYC Not Required | Agreed later (KYC) | User |
| I-008 | KYC | Question setup | Display types: drop-down list, radio buttons, check boxes, user entry field | Agreed later (KYC) | User |
| I-009 | KYC | Tests | End-to-end tests still expect status IN_PROGRESS (replaced in KYC 105) | Agreed later (KYC) | KYC 105 |
| I-010 | COMMON / KYC | Status badges | `XXFND_UI_PKG.STATUS_TONE` holds KYC statuses; tone should come from the status lookup's tag | Open | C17 |
| I-011 | COMMON | Application settings | Settings of another application cannot be changed from COMMON | Open | C7 |
| I-012 | COMMON | Delegations | No routine to create / end a delegation (applications and tests write the table) | Open | C13 |
| I-013 | COMMON | Approval rules / role grants | Cannot be switched off and on by a routine | Open | C14 |
| I-014 | COMMON | Lookups | An application cannot rename its own lookup values | Open | C15 |
| I-015 | COMMON | Test users script | Department assignment values must be codes; script fixed, re-run on the server needed | Open | C16 |
| I-016 | COMMON | Live testing | The cloud session's browser cannot open the server (proxy certificate / permission); live checks are done by the user | Open | Session |
| I-017 | COMMON | DB tests | r109, r110, r111, r112, r113 tests written but not run on a database | Open | Releases 109-113 |
| I-018 | COMMON | FUSION server | After installing 112: link FUSION to Remote Server `apex-fa-iabwbn-dev1-rest-apis`, its credential and catalogs (user action) | Open | COMMON 112 |
| I-019 | COMMON | Retention | Two-stage design: review then archive / delete, 30-day minimum review, reminders, flagged-records screen | Parked (placeholder only) | User |
| I-020 | COMMON | Integrations - Server (121) | Picking another APEX Remote Server does not refresh the Server name / URL until the server is saved | Open | Claude (COMMON 112 review) |
| I-021 | COMMON | Integrations - Servers (120) | APEX Remote Servers list shows a remote server once per COMMON server linked to it (two servers on one remote server = two rows) | Open | Claude (COMMON 112 review) |
| I-022 | COMMON | Integrations - Purpose (123) | Catalog Service list is empty until the purpose's server has REST Source Catalogs (by design; needs a hint text) | Open | Claude (COMMON 112 review) |
| I-023 | COMMON | Fusion Objects clean-up | Script 41c keeps engine tables that hold rows and any replica tables the engine generated - list and drop by hand if not needed | Open | Claude (COMMON 112) |
| I-024 | COMMON | Feature docs | `TECHNICAL.md` of integrations, notifications, roles-privileges still name the removed 40z Fusion Objects script (regenerate with `repos/common/tools/feature_docs.py`) | Open | Claude |
| I-025 | All | CLAUDE.md | Rules out of date with the user's later instructions: "no push / no merge" (now: push and merge, only no Netlify) and "start the database for changes" (now: no database, offline validation only) | Open | Claude |
| I-026 | COMMON | Approval groups | A GROUP level keeps the group code in ROLE_CODE (30 characters); a dedicated column would be clearer | Open | Claude (COMMON 113) |

## Fixed
| # | App | Area / screen | Issue | Fixed in |
|---|---|---|---|---|
| I-101 | COMMON | Integrations - Server form (121) | ORA-00937 opening the form (server name query) | COMMON 113 |
| I-102 | COMMON | Users - User form (104) | "More than supported columns" (Account at grid column 13) | COMMON 113 |
| I-103 | COMMON | Workflow - Process Catalogue (147) | One row per rule and level instead of per process; no place for approval rules and groups | COMMON 113 |
| I-104 | COMMON | Approval Setup | No approval groups (named sets of approvers for a level) | COMMON 113 |
| I-105 | COMMON | Integrations - Servers (120 / 121) | Servers not linked to the APEX Remote Servers; FUSION incomplete; no Add from a remote server | COMMON 112 |
| I-106 | COMMON | Integrations - Server (121) | Name / URL typed instead of read live from the Remote Server; Fusion Integration Application field not needed (column dropped) | COMMON 112 |
| I-107 | COMMON | Integrations | REST Source Catalogs not linked to a server (one server, many catalogs); REST Data Sources of a server not shown | COMMON 112 |
| I-108 | COMMON | Fusion Objects | Not needed (service catalogs used instead) - removed | COMMON 112 |
| I-109 | COMMON | Install | `XXFND_SERVERS_V` failed in SQL Developer (comment ending with `;`) - ORA-00936 / ORA-03048 | COMMON 111 |
| I-110 | COMMON | Navigation menu | Clicking a menu group did nothing - group page (100) | COMMON 111 |
| I-111 | COMMON | RFI | RFI_STATUS / RFI_RECIPIENT_TYPE / RFI_CATEGORY registered only by KYC | COMMON 111 |
| I-112 | COMMON | Security | `KYC_USER` (an application name in COMMON) and leftover `ADMIN_APP` schemes | COMMON 111 |
| I-113 | COMMON | Integrations - Purposes (123) | Endpoint not taken from the REST Source Catalogs | COMMON 110 |
| I-114 | COMMON | Integrations - Servers | URL / region / namespace / token URL typed in COMMON instead of read from APEX | COMMON 109 |
| I-115 | COMMON | Users (103 / 104) | Locked accounts not visible; no unlock / lock | COMMON 109 |
| I-116 | COMMON | Clean-up | Unused LOV, authorization, table, wrappers; KYC names inside COMMON | COMMON 108 |
| I-117 | KYC | Request stages | Request stages and statuses (Draft > Submitted > Under Review > In Approval > Approved; Info Needed, Not Required, Rejected, Cancelled); request is the parent of the case | KYC 105 |
| I-118 | KYC | Home | Requester KPIs (Department / My x Total, Pending Info, Open, Closed); L1 New Requests tile | KYC 105 |
| I-119 | KYC | Create Request (201 / 203 / 205) | Two columns, Requesting Country, no duplicate check, review with request / party / questions / documents, submit popup (KYC required / not required) | KYC 105 |
| I-120 | KYC | Assign (206) / New Requests (200) | Assign one or many requests to a contributor (creates the case); Approve / Add Approver hidden | KYC 105 |
| I-121 | KYC | Header card | Requester sees KYC Required / Not Required, not the score (score for case viewers) | KYC 105 |
| I-122 | KYC | Create Request | Steps: request + party (201), questions on one page without Check button (204), review and submit (203) | KYC 104 |
| I-123 | KYC | Global page | P0_PARTY_TYPE LOV error (LOV starting with a comment) | KYC 102 |
| I-124 | KYC | Party details | Access rule moved from COMMON to the KYC party package | KYC 101 |
