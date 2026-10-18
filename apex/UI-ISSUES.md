# UI / UX issues reported by the user (18 Oct 2026)

Approved plan: COMMON 91 (1, 3, 4, 5 - done, patch 105), COMMON 92 (6, 7), COMMON 93 (9), COMMON 94 (8), COMMON 95 (2).
Issues reported after the plan are recorded here only; they get their own plan and approval.

| # | App | Screen | Issue | Status |
|---|---|---|---|---|
| 1 | COMMON | Home (1) | "Open Tasks" KPI too small | Done (COMMON 91, patch 105) |
| 2 | COMMON | Application Journey (165) | Steps only explain; roles, users, notifications, document storage, integrations should be set up in the wizard | Done (COMMON 95, patch 110) |
| 3 | COMMON | User (104) | Page error on P104_EMPLOYEE_ID (PLS-00428) | Done (COMMON 91, patch 105) |
| 4 | COMMON | Privileges (182), Segregation of Duties (107) | Rows must show / belong to their application | Done (COMMON 91, patch 105) |
| 5 | COMMON | Lookup Type (102) | Customization Level not needed on the screen | Done (COMMON 91, patch 105) |
| 6 | COMMON | Descriptive Flexfield (153) | Fixed columns read-only; context from a rule (global / attribute / function), not a column | Done (COMMON 92, patch 107) |
| 7 | COMMON | Descriptive Flexfield (153), Segments | Column from a list, display name, API name, validation (lookup, value set) | Done (COMMON 92, patch 107) |
| 8 | COMMON | Workflow Setup, Process Catalogue (147) | Process with rules, approvers (user level now; position / hierarchy / AOR / query as placeholders), delegation and deadline per step | Done (COMMON 94, patch 109; HCM approver types are placeholders) |
| 9 | COMMON | Integrations, Server (121) | Fusion server and credential read from the Fusion Integration app, not hardcoded | Done (COMMON 93, patch 108) |
| 10 | KYC | Navigation menu, Administration | Clicking "Administration" (KYC side menu, e.g. on Case 211) does nothing | Recorded - not planned yet |
| 11 | COMMON | My Tasks (40) opened from an application | Breadcrumb "Home" goes to COMMON Home; it should go back to the application the user came from (e.g. KYC Home), and the app name at the top should be that application, not "Common" | Done (COMMON 97, patch 112) |
| 12 | COMMON | User (104) | Page cluttered: title, direct data rules, roles without their data access | Done (COMMON 96, patch 111) |
| 13 | COMMON | Users, Roles, Privileges, Data Security | Security model: roles combine roles, privileges and data access; data access through roles only, values per dimension with per-object override; no Finance / Procurement roles; users linked to applications; rows owned by an application | Done (COMMON 96, patch 111) |
