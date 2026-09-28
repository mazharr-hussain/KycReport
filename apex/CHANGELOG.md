# KYC Compliance Platform – APEXlang export: change log

Source: `KYC-Compliance-Platform-APEXlang_5.zip` → Corrected: `KYC-Compliance-Platform-APEXlang_6.zip`
(same APEXlang folder structure, APEX 26.1, `mmdVersion 26.1.0+3102`).

Validated offline with SQLcl 26.2.2 `apex validate`: **Validation successful, 0 warnings**
(the original gave 2 `FILE_IGNORED` warnings).

| # | File | Component | Before | After | Reason |
|---|------|-----------|--------|-------|--------|
| 1 | `shared-components/app-settings.apx` → `application.apx` | App settings `MAIL_FROM`, `FUSION_BASE_URL`, `FUSION_CREDENTIAL_STATIC_ID` | Defined in `shared-components/app-settings.apx`, which the 26.1 compiler ignores (`FILE_IGNORED`) – the settings were never imported | The 3 `appSetting` blocks appended unchanged to `application.apx`; `app-settings.apx` removed | App settings are children of the application and must be declared in `application.apx`. Without them `apex_app_setting.get_value` fails in the RFI e-mail, the mailer job and the HCM sync job |
| 2 | `shared-components/text-messages.apx` → `shared-components/messages.apx` | 11 text messages (`DELETE_MSG`, `XXFND_DFF_*`) | File ignored by the compiler (`FILE_IGNORED`) – messages never imported | File renamed; content unchanged | 26.1 expects text messages in `shared-components/messages.apx`. Without them delete confirmations and flexfield errors show message keys |
| 3 | `supporting-objects/supporting-objects.apx` | Install script **05 Core packages – part 1 of 2** and **09 Views** (same change in the matching upgrade scripts) | View `XXFND_USER_ROLES_V` created in script 09, but package body `XXFND_SECURITY_PKG` (script 05) queries it → body created with compilation errors (ORA-00942) and the supporting-objects install reports failure | View definition (unchanged) moved into script 05 immediately before `create or replace package body xxfnd_security_pkg`; removed from script 09 | Dependency order: the view only depends on tables from script 01. Static dependency check now finds no object used before it is created (install and upgrade) |

| 4 | `supporting-objects/supporting-objects.apx` | Script **14 Attachments** – `XXFND_ATTACH_PKG` body, `ADD_FILE` and `ADD_TEXT` | `values (…, next_seq(p_entity_name, p_pk1_value))` | `l_seq := next_seq(…);` before the insert, `values (…, l_seq)` | `NEXT_SEQ` is private to the body; private functions cannot be called inside SQL (PLS-00231). Body was created invalid |
| 5 | same file | Script **15 Workflow** – `XXFND_WF_PKG` body, `ADMIN_NOTE` and `REASSIGN_ACTIVITY` | `norm(null)` inside `insert … values` / `update … set` | `l_user varchar2(255) := norm(null);` declared, SQL uses `l_user` | Same PLS-00231 (private function `NORM` in SQL) |
| 6 | same file | Script **15 Workflow** – `XXFND_WF_PKG.SEND_QUEUED` exception handler | `update … error_message = substr(sqlerrm, 1, 4000)` | `l_error := substr(sqlerrm, 1, 4000);` then `error_message = l_error` | `SQLERRM` is PL/SQL only; inside SQL it raises ORA-00904 |
| 7 | same file | Script **03** index `XXFND_DF_CONTEXTS_U1` (+ one-off repair block at the start of upgrade script 05) | `(descriptive_flexfield_code, case when global_flag = 'Y' then 1 end)` | `(case when global_flag = 'Y' then descriptive_flexfield_code end)` | Intended "one GLOBAL context per flexfield", but every non-global context keyed `(code, NULL)`, so a second context failed with ORA-00001 in seed script 18. That aborted the whole seed block (roles included), which then made `bootstrap_admin` fail with ORA-02291 on `XXFND_USER_ROLES_FK2`. The upgrade block drops and recreates the index only if the old definition is present |

Fixes 4–6 are applied to both the install and the upgrade copy of the scripts.

No component was renamed and no IDs were changed. Everything else is byte-for-byte identical to the original.

## One-step import (application + all database objects)

The export already contains every table, package, view, seed row and scheduler job as Supporting Objects.
They install during `apex import` **only** when auto-install is switched on in the same session.

One-time prerequisite (a privilege grant cannot be performed by any application import), run as a DBA:

```sql
grant execute on sys.dbms_crypto to <PARSING_SCHEMA>;
```

Then, connected in SQLcl as the parsing schema of workspace `XXCUS`:

```sql
-- 1. Offline check of the file
apex validate -input KYC-Compliance-Platform-APEXlang_6.zip

-- 2. Install supporting objects as part of the import
begin
    apex_application_install.set_auto_install_sup_obj(p_auto_install_sup_obj => true);
end;
/

-- 3. Import (add -id <n> to choose the application ID)
apex import -input KYC-Compliance-Platform-APEXlang_6.zip -workspace XXCUS

-- 4. Verify
select object_type, object_name from user_objects
 where status = 'INVALID' and (object_name like 'XXFND%' or object_name like 'XXCMP%');
select job_name, enabled, state from user_scheduler_jobs where job_name like 'XXFND%';
```

**Re-importing over the failed install:** import with the same application ID (`-id <current id>`).
Because `XXFND_LOOKUP_TYPES` already exists, APEX runs the *upgrade* scripts: they repair the index,
recreate all packages and re-run the (merge-based) seed data, keeping existing tables.

After import, fill in the Application Settings `MAIL_FROM`, `FUSION_BASE_URL` and `FUSION_CREDENTIAL_STATIC_ID`
(Shared Components → Application Settings).
