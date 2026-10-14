# Release 86 - part C: application management as a guided journey (COMMON only)

For the integrator: ARCHITECTURE / CHANGELOG / install guide text, and what C depends on from A and B.

## What changed

| Where | Change |
|---|---|
| Page 160 Applications | A row opens **166** (`P166_APPLICATION_CODE`, with checksum); **Register Application** opens **165** (`P165_STEP=1`, cache cleared). Help text updated. |
| Page 161 Application | **Removed** (page file, breadcrumb entry, every link). Its DML (form auto row processing, IG save of the function switches, `register_application`) now goes through `XXFND_APPLICATION_PKG.ONBOARD` / `SAVE_APPLICATION` / `SAVE_FUNCTIONS` (part A). |
| Page 165 Application Journey (new) | Universal Theme wizard: Wizard Progress list + Previous / Next (sticky buttons container). Steps 1 Application, 2 Roles, 3 Users, 4 Shared functions, 5 Setup types, 6 Processes, 7 Notifications, 8 Document storage, 9 Integrations, 10 Review. **Create** (no code in the URL, needs Applications - Create): only step-1 values + the choices of steps 3 (administrator), 4 (shared functions) and 6 (processes to switch on) are kept in session state; steps 2, 5, 7, 8, 9 say in one sentence what happens after registering; nothing is saved before **Register** (step 10), which calls `ONBOARD`, then `SET_ENABLED` (when Enabled is off), `SAVE_FUNCTIONS`, `XXFND_WORKFLOW_PKG.SET_PROCESS_ENABLED` per chosen process, and opens 166. **Edit** (`P165_APPLICATION_CODE` + `P165_STEP`, needs Applications - Manage): opens at any step; steps 2-3 and 5-9 show the shared section (its dialogs save at once); **Save** on step 1 (`SAVE_APPLICATION`), step 4 (`SAVE_FUNCTIONS`) and step 10 (both, then 166). Code and APEX application are read only on edit. |
| Page 166 Application (new) | Record page as KYC 205 / 211: page template Left Side Column, header card (Content Row template component: name (code), APEX application / alias / schema / e-mail, description, status badge), actions bar (**Edit** -> 165 step 1, **Disable** / **Enable** -> `SET_ENABLED`, **Delete** only when `DELETE_BLOCKER` is null -> `DELETE_APPLICATION` -> 160; otherwise the display item *Delete* shows the reason), section menu (left column, Links List with icon + badge = section state), then the nine sections. |
| Global Page (page 0) | Defined **once**, conditioned on 165 / 166 (like KYC's party regions): context region with `P0_JRN_APP` (application) and `P0_JRN_KEY` (row of a section action); sections `jrn-application`, `jrn-roles` (Add Role / edit -> 106), `jrn-users` (per role: Assign users -> 183, Remove; Create User -> 104), `jrn-functions` (Edit -> 165 step 4), `jrn-setup-types` (edit -> 163), `jrn-processes` (Switch on / off), `jrn-notifications` (application's own rules: Switch on / off; rules of every application shown read only), `jrn-storage` (`XXFND_APP_STORAGE_V`; Edit Storage -> 137 with `P137_APPLICATION_CODE`), `jrn-integrations` (purposes; Add Purpose / edit -> 123 with `P123_APPLICATION_CODE` / `P123_PURPOSE_CODE`) with sub-region `jrn-servers` (`XXFND_SERVERS_V`). On 166 every section shows; on 165 (edit) the section of the current step and all of them on Review. Two dynamic actions (dialog closed / cancelled) resubmit the page (request `JRN_REFRESH`) so sections and states show the dialog's change (the Role dialog stays open after Create for its tabs, hence also on Cancel). |
| Shared components | List **application-journey** (dynamic, one SQL for both pages: Wizard Progress on 165, section menu with states on 166). Application process **JOURNEY_ACTIONS** (processing point, pages 165 / 166 only, requests `JRN_REMOVE_USER`, `JRN_PROCESS_ON/OFF`, `JRN_RULE_ON/OFF`): checks the feature's Manage privilege and that the row belongs to `P0_JRN_APP`, then calls `XXFND_USER_PKG.UNASSIGN_ROLE`, `XXFND_WORKFLOW_PKG.SET_PROCESS_ENABLED`, `XXFND_NOTIFY_PKG.SET_RULE_ENABLED` (no DML). Breadcrumb: entry 161 replaced by 166 (`&P166_APPLICATION_CODE.`) and 165 (`&P165_TITLE.`), both under Applications. |
| `apex/db/30-application-journey.sql` (new; manifest install 223 / upgrade 183, apps COMMON) | Pages 165 and 166 added to feature APPLICATIONS (guarded MERGE as 27-shared-screens.sql; `XXFND_PRIVILEGE_PKG.REGISTER_FEATURE_PAGE` of part A was not available in this worktree - the integrator may switch to it). The 161 feature-page row is **left as it is** (no data deleted): a feature page the application does not have is never shown (menus, tabs and module lists join `APEX_APPLICATION_PAGES`) and grants nothing. Note: 19c `SEED_ADMIN` still seeds `161` for a fresh install (outside part C; harmless, could be dropped from the seed list). |

## Privileges and data security
- 166: Page - View (APPLICATIONS.VIEW); Edit / Disable / Enable / Delete: Page - Manage; processes Page - Submit.
- 165: Page - View, plus a before-header check with the same schemes (`apex_authorization.is_authorized`): create needs
  Page - Create, edit Page - Manage; Register button Page - Create, Save Page - Manage.
- Section actions check their own feature: Roles - ROLES_PRIVILEGES (Create to add, Manage to edit), Users - USERS_ACCESS
  (Create: Create User, Manage: assign / remove), Setup types - APPLICATIONS.MANAGE, Processes - WORKFLOW_SETUP.MANAGE,
  Notifications - NOTIFICATIONS.MANAGE, Storage - ATTACHMENTS.MANAGE, Integrations - INTEGRATIONS (Create / Manage).
  The dialogs keep their own authorization; JOURNEY_ACTIONS checks again on the server.
- Data security: COMMON admin scope (`XXFND_APPLICATION_PKG.PAGE_ALLOWED`: APPLICATIONS is not a delegated function, so
  only Common Administrators open 165 / 166), checksum on every URL argument.

## Depends on part A (calls exactly the contract signatures)
`XXFND_APPLICATION_PKG.ONBOARD`, `SAVE_APPLICATION`, `SET_ENABLED`, `DELETE_BLOCKER`, `DELETE_APPLICATION`,
`SAVE_FUNCTIONS`; `XXFND_WORKFLOW_PKG.SET_PROCESS_ENABLED`; `XXFND_NOTIFY_PKG.SET_RULE_ENABLED`.
Assumptions to confirm at merge: `ONBOARD.p_admin_user` is a user name (`XXFND_USERS.USER_NAME`); `ONBOARD` creates the
application's `XXFND_WORKFLOW_PROCESSES` rows (or `SET_PROCESS_ENABLED` accepts a process of the APEX application not
synced yet) - process code = APEX workflow static ID; the app's own notification rules (if any) carry
`APPLICATION_CODE`. Errors of `SAVE_APPLICATION` (APEX application not in the workspace / registered under another code)
appear at Register (step 10); step 1 does not pre-check them (no page-side copy of the rule).

## Depends on part B
`XXFND_APP_STORAGE_V` (application_code, category_code, server_code, server_type, folder, state), `XXFND_SERVERS_V`
(server_name, server_type_name, usage, status), page 137 accepting `P137_APPLICATION_CODE`, page 123 accepting
`P123_APPLICATION_CODE` / `P123_PURPOSE_CODE`. The section menu's storage state reads the application-default row
(`category_code is null`). The purposes section uses only columns that exist today (no `ENDPOINT_CODE`).

## Tests
- `apex/tests/r88_journey_test.sql` (XXFUSION, read only): pages 165 / 166 exist, 161 gone (page, breadcrumb, links),
  feature pages and privileges, button authorizations, nine sections once on page 0 and on no page, one list / one
  application process, no form / grid region and no automatic row processing or DML on 165 / 166 / JOURNEY_ACTIONS,
  A's eight routines and B's views exist, `DELETE_BLOCKER('KYC')` gives a reason.
- `apex/tests/r88_journey_ui.py` (Playwright): registers an unregistered workspace application through all ten steps
  (imports the Oracle skills' example-0 as application 188 / JRN88 when the workspace has none), checks nothing is
  saved before Register, 166 header / menu / sections, edit at step 4 + Save, Add Role (106), Assign users (183),
  Remove, Disable, Delete (allowed), KYC's delete refused with its reason.
- `apex validate` of f135: no errors (only the warnings that 104, 106, 181 had before).
- **Not run against a database by part C**: the shared database lock was held by dockerd (inherited flock from a
  `dbup.sh` started under the lock), and the DB run was then refused by the session's permission classifier. The
  integrator should run, under the lock, after A and B are deployed: `@apex/db/30-application-journey.sql`, the COMMON
  import, `r88_journey_test.sql`, `r88_journey_ui.py`. No stubs were deployed.

## Open points
- Create User opens page 104 (a normal page, not a dialog): the user returns to the journey from the Applications list.
- `SAVE_APPLICATION` takes the enabled flag as well; Disable / Enable on 166 use `SET_ENABLED`.
