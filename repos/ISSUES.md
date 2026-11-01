# Issue backlog (COMMON and KYC)

The live backlog is the GitHub issues of the repository, on the Projects "KYC Application" (label KYC) and "Common
Application" (label COMMON); release PRs close them with "Fixes #n". This file mirrors them. Each issue has a type (bug / enhancement / task = non-code work: tests, setup, docs)
and a priority (P1 = blocks use or a release, P2 = next releases, P3 = later), as labels on GitHub.

The one list of every issue: reported by the user, found in a review, or a COMMON gap found by an application.
Each issue keeps its number for good. **Status:** Open (reported, no plan yet) - Planned (in an approved plan, being built) -
Agreed later (accepted, waits for its own plan and approval) - Parked (the user put it on hold) - Fixed (release named).
Rules: issues are collected first, then a plan, then approval (CLAUDE.md). Update this file with every release: add the
new issues, move fixed ones to Fixed with the release. COMMON gaps keep their detail in
`repos/common/docs/COMMON-ISSUES.md` (C-numbers); release details are in `repos/<app>/releases/NNN-*/README.md`.
Audit 1-Nov-2026: chat history before 27-Oct-2026 is no longer on disk; this list holds every issue found in the remaining
history, the UI issues list of 18-Oct (`apex/UI-ISSUES.md`, I-2xx), the COMMON review of 25-Oct (`repos/common/docs/COMMON-REVIEW.md`,
I-3xx) and the COMMON gaps (C-numbers). Older releases: see their release READMEs and `apex/CHANGELOG.md`.

## Open and agreed (backlog)
| # | App | Area / screen | Issue | Type | Priority | Status | Source |
|---|---|---|---|---|---|---|---|
| I-001 [#136](https://github.com/mazharr-hussain/KycReport/issues/136) | KYC | Authorization `kyc-user` | Calls `authorized('KYC_USER')`, retired in COMMON 111 - must call `APP_USER`; deploy with COMMON 111+ (until then every KYC user is refused) | bug | P1 | Agreed later (KYC) | C18 |
| I-002 [#137](https://github.com/mazharr-hussain/KycReport/issues/137) | KYC | Approval processes | One approval process for the KYC case and one for the request, rules and approval groups on the COMMON Process page (today many risk-tier rules) | enhancement | P2 | Agreed later (KYC) | User, COMMON 113 |
| I-003 [#138](https://github.com/mazharr-hussain/KycReport/issues/138) | KYC | Home (L1) | L1 KPIs / pipeline view of all stages at a glance (different from the requester KPIs) | enhancement | P2 | Agreed later (KYC) | User |
| I-004 [#139](https://github.com/mazharr-hussain/KycReport/issues/139) | KYC | Request stages - G2 | Cancel a request after it is submitted | enhancement | P2 | Agreed later (KYC) | Stage review |
| I-005 [#140](https://github.com/mazharr-hussain/KycReport/issues/140) | KYC | Request stages - G4 | Return to the contributor | enhancement | P2 | Agreed later (KYC) | Stage review |
| I-006 [#141](https://github.com/mazharr-hussain/KycReport/issues/141) | KYC | Request stages - G5 | Notify the requester (stage changes) | enhancement | P2 | Agreed later (KYC) | Stage review |
| I-007 [#142](https://github.com/mazharr-hussain/KycReport/issues/142) | KYC | Screening questions | Replace with the 5 questions of the staging PDF; score >= 8 = KYC Required, else KYC Not Required | enhancement | P1 | Agreed later (KYC) | User |
| I-008 [#143](https://github.com/mazharr-hussain/KycReport/issues/143) | KYC | Question setup | Display types: drop-down list, radio buttons, check boxes, user entry field | enhancement | P2 | Agreed later (KYC) | User |
| I-009 [#144](https://github.com/mazharr-hussain/KycReport/issues/144) | KYC | Tests | End-to-end tests still expect status IN_PROGRESS (replaced in KYC 105) | bug | P2 | Agreed later (KYC) | KYC 105 |
| I-010 [#145](https://github.com/mazharr-hussain/KycReport/issues/145) | COMMON / KYC | Status badges | `XXFND_UI_PKG.STATUS_TONE` holds KYC statuses; tone should come from the status lookup's tag | enhancement | P3 | Open | C17 |
| I-011 [#146](https://github.com/mazharr-hussain/KycReport/issues/146) | COMMON | Application settings | Settings of another application cannot be changed from COMMON | enhancement | P3 | Open | C7 |
| I-012 [#147](https://github.com/mazharr-hussain/KycReport/issues/147) | COMMON | Delegations | No routine to create / end a delegation (applications and tests write the table) | enhancement | P3 | Open | C13 |
| I-013 [#148](https://github.com/mazharr-hussain/KycReport/issues/148) | COMMON | Approval rules / role grants | Cannot be switched off and on by a routine | enhancement | P3 | Open | C14 |
| I-014 [#149](https://github.com/mazharr-hussain/KycReport/issues/149) | COMMON | Lookups | An application cannot rename its own lookup values | enhancement | P3 | Open | C15 |
| I-015 [#150](https://github.com/mazharr-hussain/KycReport/issues/150) | COMMON | Test users script | Department assignment values must be codes; script fixed, re-run on the server needed | bug | P2 | Open | C16 |
| I-016 [#151](https://github.com/mazharr-hussain/KycReport/issues/151) | COMMON | Live testing | The cloud session's browser cannot open the server (proxy certificate / permission); live checks are done by the user | task | P3 | Open | Session |
| I-017 [#152](https://github.com/mazharr-hussain/KycReport/issues/152) | COMMON | DB tests | r109, r110, r111, r112, r113 tests written but not run on a database | task | P1 | Open | Releases 109-113 |
| I-018 [#153](https://github.com/mazharr-hussain/KycReport/issues/153) | COMMON | FUSION server | After installing 112: link FUSION to Remote Server `apex-fa-iabwbn-dev1-rest-apis`, its credential and catalogs (user action) | task | P1 | Open | COMMON 112 |
| I-019 [#154](https://github.com/mazharr-hussain/KycReport/issues/154) | COMMON | Retention | Two-stage design: review then archive / delete, 30-day minimum review, reminders, flagged-records screen | enhancement | P3 | Parked (placeholder only) | User |
| I-020 [#155](https://github.com/mazharr-hussain/KycReport/issues/155) | COMMON | Integrations - Server (121) | Picking another APEX Remote Server does not refresh the Server name / URL until the server is saved | bug | P3 | Open | Claude (COMMON 112 review) |
| I-021 [#156](https://github.com/mazharr-hussain/KycReport/issues/156) | COMMON | Integrations - Servers (120) | APEX Remote Servers list shows a remote server once per COMMON server linked to it (two servers on one remote server = two rows) | bug | P3 | Open | Claude (COMMON 112 review) |
| I-022 [#157](https://github.com/mazharr-hussain/KycReport/issues/157) | COMMON | Integrations - Purpose (123) | Catalog Service list is empty until the purpose's server has REST Source Catalogs (by design; needs a hint text) | enhancement | P3 | Open | Claude (COMMON 112 review) |
| I-023 [#158](https://github.com/mazharr-hussain/KycReport/issues/158) | COMMON | Fusion Objects clean-up | Script 41c keeps engine tables that hold rows and any replica tables the engine generated - list and drop by hand if not needed | task | P3 | Open | Claude (COMMON 112) |
| I-024 [#159](https://github.com/mazharr-hussain/KycReport/issues/159) | COMMON | Feature docs | `TECHNICAL.md` of integrations, notifications, roles-privileges still name the removed 40z Fusion Objects script (regenerate with `repos/common/tools/feature_docs.py`) | task | P3 | Open | Claude |
| I-025 [#160](https://github.com/mazharr-hussain/KycReport/issues/160) | All | CLAUDE.md | Rules out of date with the user's later instructions: "no push / no merge" (now: push and merge, only no Netlify) and "start the database for changes" (now: no database, offline validation only) | task | P2 | Open | Claude |
| I-026 [#161](https://github.com/mazharr-hussain/KycReport/issues/161) | COMMON | Approval groups | A GROUP level keeps the group code in ROLE_CODE (30 characters); a dedicated column would be clearer | enhancement | P3 | Open | Claude (COMMON 113) |
| I-027 [#169](https://github.com/mazharr-hussain/KycReport/issues/169) | COMMON | Training | Update the 26 videos, the training manual and the user guide for releases 108-113 (servers, purposes, menu groups, processes and approval groups, users; Fusion Objects removed) | task | P2 | Open | User |
| I-028 [#170](https://github.com/mazharr-hussain/KycReport/issues/170) | KYC | Training | Update the 9 videos, the training manual and the user guide (KYC-GUIDE.md) for KYC 105 (after the KYC changes) | task | P2 | Open | User |
| I-029 [#173](https://github.com/mazharr-hussain/KycReport/issues/173) | COMMON | In-app help (every screen) | User guide, training manual and video opened from the same screen as a guided journey; one COMMON component, each application registers its pages' material | enhancement | P2 | Open | User |
| I-038 [#186](https://github.com/mazharr-hussain/KycReport/issues/186) | COMMON | GitHub workflows | W11 training videos as Release assets | task | P2 | Open | User |
| I-039 [#187](https://github.com/mazharr-hussain/KycReport/issues/187) | COMMON | Flexfields / notifications packages | HTML built in PL/SQL (10 lines found by the PR check) - move to APEX components or comment why | bug | P3 | Open | Claude |
| I-040 [#189](https://github.com/mazharr-hussain/KycReport/issues/189) | COMMON | GitHub workflows | Deploy each merged release to the dev server and run its DB tests (needs server secrets) | task | P2 | Open | User + Claude |

| I-3A3 [#162](https://github.com/mazharr-hussain/KycReport/issues/162) | COMMON | Review 25-Oct (A3) | `OUTLOOK_MESSAGES`, `SHAREPOINT_DRIVES`, `UCM_CONTENT` - referenced nowhere (prepared, never wired) | enhancement | P3 | Parked (kept: planned integrations) | COMMON-REVIEW |
| I-3A4 [#163](https://github.com/mazharr-hussain/KycReport/issues/163) | COMMON | Review 25-Oct (A4) | `xxfnd_retention_pkg` - no caller: no automation, job or page runs it, so retention never happens | enhancement | P3 | Parked (retention placeholder) | COMMON-REVIEW |
| I-3A5 [#164](https://github.com/mazharr-hussain/KycReport/issues/164) | COMMON | Review 25-Oct (A5) | `xxfnd_document_versions_v`, `xxfnd_integration_changes_v`, `xxfnd_qa_history_v` - no page or code reads them (only docs / comments) | - | - | Closed - kept (application-facing views) | COMMON-REVIEW |
| I-3A7 [#165](https://github.com/mazharr-hussain/KycReport/issues/165) | COMMON | Review 25-Oct (A7) | `xxfnd_ui_pkg` - not used by COMMON itself, only by KYC (shared UI helper - keep, listed for information) | - | - | Closed - kept (shared UI helper) | COMMON-REVIEW |
| I-3B2 [#166](https://github.com/mazharr-hussain/KycReport/issues/166) | COMMON | Review 25-Oct (B2) | Page LOV queries repeated inline instead of a shared LOV: setup columns (xxfnd_setup_columns_v, 3 variants in 2-5 pages), applications (2 variants, 2 pages each), notification templates (2 pages) - sh | enhancement | P3 | Open (only page 116 moved to shared LOVs) | COMMON-REVIEW |
| I-3C5 [#167](https://github.com/mazharr-hussain/KycReport/issues/167) | COMMON | Review 25-Oct (C5) | every page 2+ privileges (View/Create/Manage) - 10 pages use only *signed-in user*: 1 Home, 40 My Tasks, 43 Notifications, 45 Communications, 46 E-mail, 47 Attachments, 48 Document, 143 Information Re | - | - | Closed - decision: self-service pages stay signed-in user only | COMMON-REVIEW |
## Fixed
| # | App | Area / screen | Issue | Fixed in |
|---|---|---|---|---|
| I-031 [#179](https://github.com/mazharr-hussain/KycReport/issues/179) | COMMON | GitHub workflows | W1-W3 checks.yml on repos/: build each app and validate APEXlang (SQLcl) on every PR | Workflows (1-Nov-2026) |
| I-032 [#180](https://github.com/mazharr-hussain/KycReport/issues/180) | COMMON | GitHub workflows | W4 install-safety checks on every PR | Workflows (1-Nov-2026) |
| I-033 [#181](https://github.com/mazharr-hussain/KycReport/issues/181) | COMMON | GitHub workflows | W5 golden-rule warnings on every PR | Workflows (1-Nov-2026) |
| I-034 [#182](https://github.com/mazharr-hussain/KycReport/issues/182) | COMMON | GitHub workflows | W6 technical docs up to date | Workflows (1-Nov-2026) |
| I-035 [#183](https://github.com/mazharr-hussain/KycReport/issues/183) | COMMON | GitHub workflows | W8 GitHub Release on merge of a release | Workflows (1-Nov-2026) |
| I-036 [#184](https://github.com/mazharr-hussain/KycReport/issues/184) | COMMON | GitHub workflows | W9 ISSUES.md follows closed issues | Workflows (1-Nov-2026) |
| I-037 [#185](https://github.com/mazharr-hussain/KycReport/issues/185) | COMMON | GitHub workflows | W10 weekly backlog summary | Workflows (1-Nov-2026) |
| I-041 [#190](https://github.com/mazharr-hussain/KycReport/issues/190) | COMMON | GitHub workflows | More PR validations: APEX security, PL/SQL risks, install safety, release folder, PMD (warnings) | Workflows (1-Nov-2026) |
| I-030 [#177](https://github.com/mazharr-hussain/KycReport/issues/177) | COMMON | Documentation | Requirements, technical docs and training placeholders per component in git; summaries synced to the Project READMEs; PR docs check (warn) | Docs structure (1-Nov-2026) |
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
| I-201 | COMMON | Home (1) | "Open Tasks" KPI too small | COMMON 91 |
| I-202 | COMMON | Application Journey (165) | Steps only explain; roles, users, notifications, document storage, integrations should be set up in the wizard | COMMON 95 |
| I-203 | COMMON | User (104) | Page error on P104_EMPLOYEE_ID (PLS-00428) | COMMON 91 |
| I-204 | COMMON | Privileges (182), Segregation of Duties (107) | Rows must show / belong to their application | COMMON 91 |
| I-205 | COMMON | Lookup Type (102) | Customization Level not needed on the screen | COMMON 91 |
| I-206 | COMMON | Descriptive Flexfield (153) | Fixed columns read-only; context from a rule (global / attribute / function), not a column | COMMON 92 |
| I-207 | COMMON | Descriptive Flexfield (153), Segments | Column from a list, display name, API name, validation (lookup, value set) | COMMON 92 |
| I-208 | COMMON | Workflow Setup, Process Catalogue (147) | Process with rules, approvers (user level now; position / hierarchy / AOR / query as placeholders), delegation and deadline per step | COMMON 94 |
| I-209 | COMMON | Integrations, Server (121) | Fusion server and credential read from the Fusion Integration app, not hardcoded | COMMON 93 |
| I-210 | KYC | Navigation menu, Administration | Clicking "Administration" (KYC side menu, e.g. on Case 211) does nothing | KYC 95 |
| I-211 | COMMON | My Tasks (40) opened from an application | Breadcrumb "Home" goes to COMMON Home; it should go back to the application the user came from (e.g. KYC Home), and the app name at the top should be that application, not "Common" | COMMON 97 |
| I-212 | COMMON | User (104) | Page cluttered: title, direct data rules, roles without their data access | COMMON 96 |
| I-213 | COMMON | Users, Roles, Privileges, Data Security | Security model: roles combine roles, privileges and data access; data access through roles only, values per dimension with per-object override; no Finance / Procurement roles; users linked to applications; rows owned by an application | COMMON 96 |
| I-214 | COMMON | User (104), view and create | Poor layout: every field on its own narrow row down the left, the rest of the page empty; the screen should use the width and look better - multi-column layout (several fields per row) | COMMON 98 |
| I-215 | COMMON | User (104), Applications region | The user's applications (grant / End) are managed in COMMON only: the region must not show when the User page is opened from another application (an application administrator's scope) | COMMON 98 |
| I-216 | COMMON | User (104), Privileges these roles give | Own tab (Roles / Privileges / Data access); all the user's privileges with the role (and application) that gives each one, filterable by role | COMMON 98 |
| I-217 | COMMON | Fusion / IDCS connection | COMMON must not manage the Fusion and IDCS URLs or credentials: it uses the workspace server and credential made by the Fusion integration prerequisite (remove COMMON's own FUSION server and Fusion Credentials placeholders) | COMMON 100 |
| I-3A1 | COMMON | Review 25-Oct (A1) | `lov-dff-columns` (DFF RESERVED COLUMNS) - referenced by no page or code | COMMON 108 |
| I-3A2 | COMMON | Review 25-Oct (A2) | `admin-app` (Administration - Application in Scope) - referenced by no page or component | COMMON 108 |
| I-3A6 | COMMON | Review 25-Oct (A6) | `xxfnd_transmissions` - used only by tests; no page or package reads or writes it | COMMON 108 |
| I-4C1 | COMMON | COMMON gap C1 | Business users of an application cannot open COMMON's shared user pages (blocking) | COMMON 87 |
| I-4C2 | COMMON | COMMON gap C2 | A cancelled configuration change cannot be submitted again | COMMON 87 |
| I-4C3 | COMMON | COMMON gap C3 | COMMON's script 17 rewrites KYC's lookups on every COMMON upgrade | COMMON 87 |
| I-4C4 | COMMON | COMMON gap C4 | DELEGATED_URL points to KYC page 98, which no longer exists | COMMON 87 |
| I-4C5 | COMMON | COMMON gap C5 | Information Request page 143: no documents, no due dates, no task settings | COMMON 88 |
| I-4C6 | COMMON | COMMON gap C6 | E-mail page 46 has no list of the party's contacts | COMMON 88 |
| I-4C8 | COMMON | COMMON gap C8 | A page registration cannot be removed or retired | COMMON 88 |
| I-4C9 | COMMON | COMMON gap C9 | An application cannot be unregistered, and a registered application cannot be deleted | COMMON 88 |
| I-4C10 | COMMON | COMMON gap C10 | Applications are granted direct write access on every COMMON table | COMMON 88 |
| I-4C11 | COMMON | COMMON gap C11 | The grants to applications depend on script order | COMMON 87 |
| I-4C12 | COMMON | COMMON gap C12 | My Tasks opens another application's task page without a checksum | COMMON 90 |
| I-3B1 | COMMON | Review 25-Oct (B1) | 8 object files (xxfnd_util_pkg, xxfnd_schema_pkg, xxfnd_audit_pkg, xxfnd_approval_pkg spec/body, xxfnd_user_roles_v) - two identical copies made by the one-object-per-file restructure (install and upg | COMMON 108 |
| I-3B3 | COMMON | Review 25-Oct (B3) | xxfnd_util_pkg.create_who_trigger / create_all_who_triggers, xxfnd_audit_pkg.create_audit_trigger, xxfnd_vpd_pkg.apply_policies - thin wrappers of the same routines in xxfnd_schema_pkg - two entry poi | COMMON 108 |
| I-3C1 | COMMON | Review 25-Oct (C1) | COMMON has no KYC dependency - xxfnd_user_pkg.party_details_editable (authorization helper) calls KYC's XXCMP_PARTY_PKG.CAN_EDIT_DETAILS dynamically - KYC logic inside COMMON | COMMON 108 / KYC 101 |
| I-3C2 | COMMON | Review 25-Oct (C2) | same - xxfnd_attach_pkg (line ~934) falls back to application alias 'KYC' when no application is in session | COMMON 108 |
| I-3C3 | COMMON | Review 25-Oct (C3) | same; setup data per application - COMMON's seed script 17 creates 13 KYC lookup types (ENTITY_TYPE, PARTY_TYPE, CONTACT_TYPE, RELATIONSHIP_TYPE ...) and checks for XXCMP_PARTIES - KYC setup should be | COMMON 108 |
| I-3C4 | COMMON | Review 25-Oct (C4) | COMMON tests without KYC - 14 COMMON test scripts use KYC objects (kyc_functions_test, r76_departments_test, r96_security_*, tasks_prep, viewonly_role, common_test_fixture(s), test_users, admin_scope_ | COMMON 108 |
| I-3C6 | COMMON | Review 25-Oct (C6) | no files cut in parts - lists.apx, lovs.apx, authorizations.apx are still built from pieces at fixed offsets (same risk as the old DB scripts; the build now stops if they drift) | COMMON 108 |
| I-3C7 | COMMON | Review 25-Oct (C7) | wording - KYC examples in comments (xxfnd_dff_pkg, xxfnd_approval_pkg, xxfnd_config_tables, xxfnd_rfis) | COMMON 108 |
