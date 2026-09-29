# KYC Compliance Platform – APEXlang export: change log

Current release: **`KYC-Compliance-Platform-APEXlang_11.zip`** (APEX 26.1, `mmdVersion 26.1.0+3102`).
Source of truth: the APEXlang tree in `apex/src` (the zip is built from it; each chunk is one commit).

## How each release is verified

| Layer | Tool | Result for release 11 |
|---|---|---|
| Compiler | SQLcl 26.2.2 `apex validate` | Validation successful, 0 warnings |
| Oracle APEX skill – live gate | `apexctl runtime validate` against a live APEX 26.1 | `live_check_status = pass`, 0 problems |
| Cross-component rules | `apex/tests/rules.py` (IG ↔ page settings, forms ↔ DML, references, hidden items, links, LOV columns, process points …) | 2,660 checks, 0 FAIL |
| Clean install | SQLcl `apex import` + supporting objects into Oracle AI Database 26ai Free (23.26.3) + APEX 26.1.0 | all 24 scripts run; 364 objects, 0 invalid; releases R09–R11 recorded; seed data + first administrator present |
| Upgrade | release 9 → 10 and 10 → 11 over existing data (`apex import -id 101`) | data kept, each release recorded once, 0 invalid |
| Security | `apex/tests/security_test.sql`, `token_test.sql`, `viewonly_ui.py`, `forced_save.py` | privileges and row filtering per user as designed (table below) |
| Browser | `apex/tests/smoke.py <app> <out.json> <user>` (Playwright, ORDS 26.2.3): login, 40 pages, and the detail/grid page behind each list, as ADMIN, OFFICER1 and REQ1 | 0 APEX errors; each user is denied exactly the pages outside their privileges |
| Save tests | `save21.py` (Party with flexfields, as OFFICER1), `ig_save.py` (editable grid), `admin_ui.py` (console, tabs, Data Security, role privileges, settings) | all saved; validation and duplicate messages shown |

The unfixed release 7 was imported side by side and fails the same browser test on pages 102, 104, 135, 143, 153
(`For an Editable Interactive Grid, the Page attribute 'Reload on Submit' must be set to 'Only for Success'`) and
the save test (`Session state protection violation … P21_DFF_JSON`).

## Release 11 – Chunk 3: admin console (one entry per feature, tabs, security screens)

| # | File | Component | Before | After | Reason |
|---|------|-----------|--------|-------|--------|
| 28 | `pages/p00100-administration.apx`, `shared-components/lists.apx` | Administration console | one static list of 26 entries, conditions per entry | 4 groups (Basic Setup; Workflow and Integration; Security; Application), each a dynamic Media List over view `XXFND_ADMIN_MENU_V` | One entry per feature, grouped; an entry shows when the user holds VIEW on the feature – no page change needed when access changes |
| 29 | `pages/p00000-global-page.apx`, list `feature-tabs` | Feature tabs | – | one Tabs region on the global page, driven by `XXFND_FEATURE_PAGES.TAB_LABEL` | The list pages of a feature (e.g. Attachments: Categories, Mandatory Documents, Storage, Registration, Attachment Pages) are tabs of one screen |
| 30 | `shared-components/lists.apx` | Navigation menu | Administration → Change Approvals, Workflow Monitor, Setup | Administration (single entry) | Everything admin is reached from the console |
| 31 | new `pages/p00180-data-security.apx`, `p00181-data-security-rule.apx` | Data Security (Security group) | rules only in SQL | list + drawer: role, table, rule (All rows / Own records / Column in list), column (cascading LOV), values; validations; applies the VPD policy to a table on its first rule | Rule 2: maintained in the application |
| 32 | new `pages/p00182-privileges.apx` | Roles and Privileges → Privileges tab | – | every privilege and the roles holding it | Overview for administrators and auditors |
| 33 | `pages/p00106-role.apx`, `lovs.apx` (`lov-privileges`) | Role form | no privileges | shuttle "Privileges" (feature – View/Create/Manage), loaded and saved with `XXFND_PRIVILEGE_PKG.ROLE_PRIVILEGE_LIST` / `SET_ROLE_PRIVILEGES` | Grant and revoke privileges per role |
| 34 | new `pages/p10022-application-settings.apx`, `p10023-application-setting.apx` | Application Settings → Settings tab | settings editable only in the App Builder | list + drawer using `APEX_APP_SETTING.SET_VALUE` (values survive upgrades) | Rule 2 |
| 35 | 99 page processes in 37 existing pages | Execution point | `point: afterSubmit` (= *On Submit – Before Computations and Validations*) | `point: processing` | **Defect:** every save ran before the validations, so no validation could stop bad data (found when the Data Security validation was bypassed and the raw ORA-02290 appeared). New rule g11 in `rules.py` guards it |
| 36 | `supporting-objects.apx` script 09b | `XXFND_PRIVILEGE_PKG` | – | `ROLE_PRIVILEGE_LIST`, `SET_ROLE_PRIVILEGES` | used by #33 |
| 37 | new install + upgrade script `18c Admin console` (install seq 187, upgrade seq 147) | Data | – | columns `XXFND_FEATURES.HOME_PAGE_ID`, `ICON_CSS`, `XXFND_FEATURE_PAGES.TAB_LABEL`, `TAB_SEQUENCE`; view `XXFND_ADMIN_MENU_V`; unique index `XXFND_DATA_SECURITY_RULES_U1`; landing pages, icons, descriptions, 23 tabs, new page mappings (only filling empty values); records `R11` | Idempotent chunk script |

Not in this release: the **Alert Rules** entry appears with Chunk 6 (monitoring); **Configuration Change Approvals**
stays in Basic Setup until Chunk 4 replaces it with APEX approval tasks in My Tasks.

## Release 10 – Chunk 2: security framework (privileges + data security)

Access is now **feature → privilege (VIEW / CREATE / MANAGE) → role**, stored in tables and maintained in the
application (not in Workspace Administration). Every page is mapped to one feature; the same four generic
authorization schemes protect every page, so a new or rebuilt screen only needs a row in `XXFND_FEATURE_PAGES`.

| # | File | Component | Before | After | Reason |
|---|------|-----------|--------|-------|--------|
| 15 | `supporting-objects/supporting-objects.apx` | New install + upgrade script `09b Security framework - objects` (install seq 95, upgrade seq 55) | – | tables `XXFND_FEATURES`, `XXFND_PRIVILEGES`, `XXFND_FEATURE_PAGES`, `XXFND_ROLE_PRIVILEGES`, `XXFND_DATA_SECURITY_RULES` (WHO + audit triggers); packages `XXFND_PRIVILEGE_PKG`, `XXFND_VPD_PKG` | Rule 3: at least View + Create/Manage per page, plus data security. Runs before script 16, which uses the VPD package |
| 16 | same | New install + upgrade script `18b Security framework - seed` (install seq 185, upgrade seq 145) | – | 24 features, 59 privileges, 71 page mappings, 96 role grants reproducing the release 9 access, 9 data-security rules; attaches the VPD policy; records `R10` | Runs after the roles exist; only adds missing rows, so admin changes survive re-imports |
| 17 | same, script 16 (install + upgrade) | `XXCMP_KYC_PKG.RESPOND_BY_TOKEN` | – | `XXFND_VPD_PKG.BEGIN_TRUSTED` / `END_TRUSTED` around the body (also on error) | The public response page runs as `nobody`; the one-time token is the authorisation there |
| 18 | same | Prerequisite validation `DBMS_RLS granted` | – | checks `dbms_rls` is executable | VPD policies are attached with `DBMS_RLS` |
| 19 | `shared-components/authorizations.apx` | Authorization schemes | 7 role-based schemes (`compliance-staff`, `rules-admin`, `config-approver`, `audit-viewer`, `administration-rights`, `admin-area`, `kyc-user`) | `page-view`, `page-create`, `page-manage`, `page-submit` (per page view), `workflow-administer`; `kyc-user` = holds any privilege; `admin-area` = holds any admin privilege | One reusable pattern instead of role names in the application |
| 20 | 72 pages (all except 0, 33, 9999) | Page authorization | role-based scheme | `@page-view` (page 100: `@admin-area`) | View privilege of the page's feature |
| 21 | pages 20–23, 32, 101–172, 10020–10052 | Buttons | only list Create buttons had a scheme | Create → `@page-create`; Save, Delete, Activate, Generate, Submit for approval, Sync, Approve, Reject, Send, Raise RFI, Add Contact, Add Owner → `@page-manage` | Create/Manage privileges; buttons are hidden when not allowed |
| 22 | same pages | Form / grid DML and data-changing processes (53) | none | `@page-submit` (request `CREATE` needs CREATE, others MANAGE) | Server-side enforcement; a forced submit is ignored |
| 23 | `pages/p00042-workflow-item.apx` | Suspend / Resume / Move / Cancel buttons, `admin-action` process, admin items | `administration-rights`, `has_role('SYSTEM_ADMIN')` | `@workflow-administer`, `has_privilege('WORKFLOW_MONITOR','MANAGE')` | Privilege instead of role |
| 24 | `pages/p00031…` | Resolve RFI conditions | `has_any_role(<staff>)` | `has_privilege('CASES','MANAGE')` | same |
| 25 | `pages/p00030…` | RFI list query | role check + `recipient_user_name = :APP_USER` in SQL | plain query; rows filtered by the VPD policy | Data security in one place |
| 26 | `shared-components/app-processes.apx` | `DOWNLOAD_DOCUMENT` | staff role check | `PARTIES`/`CASES`/`ATTACHMENTS` `.VIEW` privilege; requester branch unchanged (and VPD-filtered) | same |
| 27 | `shared-components/lists.apx` | 35 menu entries | `has_any_role(...)` | `has_page_privilege(<target page>, 'VIEW')`; Administration entries `has_any_admin_privilege` | A menu entry shows exactly when its page opens |

Data security (VPD, one policy function for every table): a user sees the union of the rows allowed by the rules
of their active roles – `ALL_ROWS`, `OWN_RECORDS` (a user column) or `COLUMN_IN_LIST` (e.g. jurisdiction in `AE,SA`);
no rule means no rows. Sessions without an APEX user (install scripts, scheduler jobs) are not filtered.
Seeded rules: compliance staff and `SYSTEM_ADMIN` see all parties and RFIs; a requester sees only the RFIs addressed to them.

Verified (clean install and upgrade):

| User (role) | Parties | RFIs | Page 20 | Create party | Admin page 101 | My Tasks page 30 |
|---|---|---|---|---|---|---|
| ADMIN (`SYSTEM_ADMIN`) | all | all | denied (as in release 9) | – | yes | yes |
| OFFICER1 (`COMPLIANCE_OFFICER`) | all | all | yes | yes | denied | yes |
| REQ1 / REQ2 (`REQUESTER`) | none | own only | denied | – | denied | yes |
| REQ2 + test role with only `PARTIES.VIEW` | all | own only | yes, no Create; party page without Save / Raise RFI / Add Contact; forced `SAVE` ignored | – | – | – |
| not a KYC user | none | none | denied | – | denied | denied |
| `nobody` via the emailed token | – | answer stored; 0 rows visible before and after | – | – | – | – |

Note: the grants copy release 9, where Compliance Managers and the Head of Compliance could open the attachment
and workflow setup screens; this can now be changed per role without a deployment.

## Release 9 – Chunk 1: deployment framework (supporting objects)

Decision: database objects stay in the APEX supporting objects (one `apex import`). To deploy chunk by chunk:

| # | File | Component | Before | After | Reason |
|---|------|-----------|--------|-------|--------|
| 14 | `supporting-objects/supporting-objects.apx` | New install **and** upgrade script `00 Deployment framework` (sequence 5, runs first) | – | table `XXFND_SCHEMA_RELEASES`; package `XXFND_DDL_PKG` (`release_applied`, `mark_release`, `add_column`); records release `R09` | Every later chunk adds one idempotent upgrade script that checks `release_applied`, applies DDL with `create … if not exists` / `add_column`, and records itself with `mark_release`, so a re-import applies only what is new |

Verified live: fresh install (338 objects, 0 invalid, R09 recorded); upgrade over an existing install twice
(data kept – a party and role assignments survived; R09 recorded once); on Oracle 26ai `CREATE … IF NOT EXISTS`
and `DROP … IF EXISTS` work, `ALTER TABLE … ADD IF NOT EXISTS (column)` does not – hence `XXFND_DDL_PKG.ADD_COLUMN`.

## Release 8 – Chunk 0: runtime-breaking defects

| # | File | Component | Before | After | Reason |
|---|------|-----------|--------|-------|--------|
| 9 | `pages/p00102…`, `p00104…`, `p00135…`, `p00143…`, `p00153…`, `p00162…` | Page attribute Reload on Submit | `reloadOnSubmit: always` | `reloadOnSubmit: onlyForSuccess` | Required by APEX for pages with an editable interactive grid (`APEXDEV.IG.RELOAD_ON_SUBMIT_EDITABLE`) |
| 10 | `pages/p00021…`, `p00022…`, `p00023…`, `p00090…`, `p00091…` | Hidden items `Pn_DFF_JSON`, `Pn_DFF_CONTEXT` | value-protected (default) | `settings { valueProtected: false }` | `xxfnd-dff.js` writes them in the browser before submit; protected values caused "Session state protection violation" on every save. Values are still re-validated on the server by `XXFND_DFF_PKG.VALIDATE` |
| 11 | `pages/p00021…`, `p00031…`, `p00091…` | Attachment download links | hand-written `f?p=…:1:…:APPLICATION_PROCESS=DOWNLOAD_DOCUMENT:::G_DOCUMENT_ID:#DOCUMENT_ID#` | `apex_page.get_url(p_page => 1, p_request => 'APPLICATION_PROCESS=DOWNLOAD_DOCUMENT', p_items => 'G_DOCUMENT_ID', …)` in the region SQL as hidden column `DOWNLOAD_URL`, link `#DOWNLOAD_URL#` | Page 1 requires argument checksums; the hand-written link carried none |
| 12 | `pages/p00042-workflow-item.apx` | Process `admin-action` (suspend / resume / move / cancel) | no authorization | `authorizationScheme: @administration-rights` | Any KYC user could submit `RESUME` etc.; the package does not check roles |
| 13 | `supporting-objects/supporting-objects.apx` (install + upgrade script 18) | First-administrator bootstrap | returned immediately when there is no APEX session ("install.sql handles the administrator") | uses the APEX session user when present, otherwise makes every unlocked workspace administrator `SYSTEM_ADMIN` | A single SQLcl `apex import` has no APEX session, so no administrator was created and nobody could use the app |

## Release 7 – install fixes (earlier)

| # | File | Component | Before | After | Reason |
|---|------|-----------|--------|-------|--------|
| 1 | `shared-components/app-settings.apx` → `application.apx` | App settings `MAIL_FROM`, `FUSION_BASE_URL`, `FUSION_CREDENTIAL_STATIC_ID` | in a file the 26.1 compiler ignores | appended to `application.apx` | settings were never imported |
| 2 | `shared-components/text-messages.apx` → `messages.apx` | 11 text messages | file ignored | file renamed | messages were never imported |
| 3 | supporting objects, scripts 05 / 09 | view `XXFND_USER_ROLES_V` | created after the package body that uses it | created just before it | dependency order |
| 4 | script 14 | `XXFND_ATTACH_PKG` | private `NEXT_SEQ` called in SQL (PLS-00231) | computed into `l_seq` first | package compiled invalid |
| 5 | script 15 | `XXFND_WF_PKG` | private `NORM` called in SQL (PLS-00231) | `l_user` variable | package compiled invalid |
| 6 | script 15 | `XXFND_WF_PKG.SEND_QUEUED` | `SQLERRM` in SQL (ORA-00904) | `l_error` variable | package compiled invalid |
| 7 | script 03 | index `XXFND_DF_CONTEXTS_U1` | `(code, case … then 1 end)` | `(case … then code end)` | blocked a second flexfield context (ORA-00001 in seed) |
| 8 | scripts 01, 02, 04 | indexes `XXFND_USER_ROLES_U1`, `XXFND_WF_PROCESSES_U1`, `XXFND_WF_ACTIVITIES_U2`, `XXFND_WF_ITEMS_U1`, `XXCMP_PARTY_CONTACTS_U1` | same pattern as #7 | every key column inside the CASE | same ORA-00001 class; upgrade script 05 repairs existing indexes |

No component was renamed and no IDs were changed.

## One-step import (application + all database objects)

One-time prerequisites (a privilege grant cannot be performed by any application import), run as a DBA:

```sql
grant execute on sys.dbms_crypto to <PARSING_SCHEMA>;
grant execute on sys.dbms_rls    to <PARSING_SCHEMA>;   -- release 10+: row-level data security
```

Then, connected in SQLcl as the parsing schema of workspace `XXCUS`:

```sql
apex validate -input KYC-Compliance-Platform-APEXlang_11.zip

begin
    apex_application_install.set_auto_install_sup_obj(p_auto_install_sup_obj => true);
end;
/

apex import -input KYC-Compliance-Platform-APEXlang_11.zip -workspace XXCUS   -- add -id <n> for a fixed app id

select object_type, object_name from user_objects where status = 'INVALID';
select job_name, enabled, state from user_scheduler_jobs where job_name like 'XXFND%';
```

The workspace administrators who run the import become the first `SYSTEM_ADMIN` users.

**Re-importing over an existing install:** use the same application ID (`-id <current id>`). Because
`XXFND_LOOKUP_TYPES` already exists, APEX runs the *upgrade* scripts: they repair the indexes, recreate all
packages and re-run the merge-based seed data, keeping existing tables.

After import, fill in the Application Settings `MAIL_FROM`, `FUSION_BASE_URL` and `FUSION_CREDENTIAL_STATIC_ID`.
