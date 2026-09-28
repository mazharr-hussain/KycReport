# KYC Compliance Platform – APEXlang export: change log

Current release: **`KYC-Compliance-Platform-APEXlang_8.zip`** (APEX 26.1, `mmdVersion 26.1.0+3102`).
Source of truth: the APEXlang tree in `apex/src` (the zip is built from it; each chunk is one commit).

## How each release is verified

| Layer | Tool | Result for release 8 |
|---|---|---|
| Compiler | SQLcl 26.2.2 `apex validate` | Validation successful, 0 warnings |
| Oracle APEX skill – live gate | `apexctl runtime validate` against a live APEX 26.1 | `live_check_status = pass`, 0 problems |
| Cross-component rules | `apex/tests/rules.py` (IG ↔ page settings, forms ↔ DML, references, hidden items, links …) | 2,386 checks, 0 FAIL |
| Clean install | SQLcl `apex import` + supporting objects into Oracle AI Database 26ai Free (23.26.3) + APEX 26.1.0 | all 20 scripts run; 0 invalid objects; 0 compile errors; seed data + first administrator present |
| Browser | `apex/tests/smoke.py` (Playwright, ORDS 26.2.3): login, 37 pages, and the detail/grid page behind each list | 0 APEX errors (only the by-design "Compliance team" denial for a user without that role) |
| Save test | `apex/tests/save21.py`: create a Party with flexfields | "Changes saved." |

The unfixed release 7 was imported side by side and fails the same browser test on pages 102, 104, 135, 143, 153
(`For an Editable Interactive Grid, the Page attribute 'Reload on Submit' must be set to 'Only for Success'`) and
the save test (`Session state protection violation … P21_DFF_JSON`).

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

One-time prerequisite (a privilege grant cannot be performed by any application import), run as a DBA:

```sql
grant execute on sys.dbms_crypto to <PARSING_SCHEMA>;
```

Then, connected in SQLcl as the parsing schema of workspace `XXCUS`:

```sql
apex validate -input KYC-Compliance-Platform-APEXlang_8.zip

begin
    apex_application_install.set_auto_install_sup_obj(p_auto_install_sup_obj => true);
end;
/

apex import -input KYC-Compliance-Platform-APEXlang_8.zip -workspace XXCUS   -- add -id <n> for a fixed app id

select object_type, object_name from user_objects where status = 'INVALID';
select job_name, enabled, state from user_scheduler_jobs where job_name like 'XXFND%';
```

The workspace administrators who run the import become the first `SYSTEM_ADMIN` users.

**Re-importing over an existing install:** use the same application ID (`-id <current id>`). Because
`XXFND_LOOKUP_TYPES` already exists, APEX runs the *upgrade* scripts: they repair the indexes, recreate all
packages and re-run the merge-based seed data, keeping existing tables.

After import, fill in the Application Settings `MAIL_FROM`, `FUSION_BASE_URL` and `FUSION_CREDENTIAL_STATIC_ID`.
