--------------------------------------------------------------------------------
-- 03_xxfnd_core_pkgs.sql
--   XXFND_UTIL_PKG      session user/language, lookups, WHO-trigger generator
--   XXFND_AUDIT_PKG     change reason + audit-trigger generator
--   XXFND_SECURITY_PKG  role checks, segregation of duties, Fusion HCM sync
--   XXFND_APPROVAL_PKG  maker-checker for configuration changes
--------------------------------------------------------------------------------

create or replace package xxfnd_util_pkg authid definer as
    -- Signed-in APEX user, or the database user outside APEX (install, jobs).
    function current_user return varchar2;
    -- Session language as an APEX language code ('en', 'ar'); defaults to 'en'.
    function current_lang return varchar2;
    function in_apex_session return boolean;
    -- Install mode: seed scripts run inside an APEX session when installed as
    -- Supporting Objects; this makes the session count as "not APEX" so seeded
    -- rows are not treated as user edits (maker-checker, lookup locks).
    procedure set_install_mode(p_on in boolean);

    function lookup_meaning(p_lookup_type in varchar2, p_lookup_code in varchar2) return varchar2;
    function is_valid_lookup(p_lookup_type in varchar2, p_lookup_code in varchar2) return boolean;
    procedure assert_lookup(p_lookup_type in varchar2, p_lookup_code in varchar2, p_label in varchar2);

    -- Replace #TOKEN# placeholders from a JSON object {"TOKEN":"value",...}.
    function replace_tokens(p_text in clob, p_tokens_json in clob) return clob;

    -- WHO-column trigger: fills CREATED_BY/CREATION_DATE/LAST_UPDATED_BY/
    -- LAST_UPDATE_DATE/LAST_UPDATE_LOGIN and increments OBJECT_VERSION_NUMBER.
    procedure create_who_trigger(p_table_name in varchar2);
    -- Creates WHO triggers on every XXFND_/XXCMP_ table that has the WHO columns.
    procedure create_all_who_triggers;
end xxfnd_util_pkg;
/

create or replace package body xxfnd_util_pkg as

    g_install_mode boolean := false;

    procedure set_install_mode(p_on in boolean) is
    begin
        g_install_mode := nvl(p_on, false);
    end set_install_mode;

    function in_apex_session return boolean is
    begin
        return not g_install_mode and sys_context('APEX$SESSION', 'APP_USER') is not null;
    end in_apex_session;

    function current_user return varchar2 is
    begin
        return coalesce(sys_context('APEX$SESSION', 'APP_USER'),
                        sys_context('USERENV', 'SESSION_USER'));
    end current_user;

    function current_lang return varchar2 is
        l_lang varchar2(30);
    begin
        if in_apex_session then
            begin
                l_lang := lower(apex_util.get_session_lang);
            exception
                when others then l_lang := null;
            end;
        end if;
        -- Normalise regional variants ('en-us' -> 'en') to match seeded rows.
        return nvl(regexp_substr(l_lang, '^[a-z]+'), 'en');
    end current_lang;

    function lookup_meaning(p_lookup_type in varchar2, p_lookup_code in varchar2) return varchar2 is
        l_meaning xxfnd_lookup_values.meaning%type;
    begin
        if p_lookup_code is null then
            return null;
        end if;
        select nvl(t.meaning, v.meaning)
          into l_meaning
          from xxfnd_lookup_values v
          left join xxfnd_lookup_values_tl t
            on t.lookup_type = v.lookup_type
           and t.lookup_code = v.lookup_code
           and t.language_code = current_lang
         where v.lookup_type = p_lookup_type
           and v.lookup_code = p_lookup_code;
        return l_meaning;
    exception
        when no_data_found then
            return p_lookup_code;
    end lookup_meaning;

    function is_valid_lookup(p_lookup_type in varchar2, p_lookup_code in varchar2) return boolean is
        l_count pls_integer;
    begin
        select count(*)
          into l_count
          from xxfnd_lookup_values v
         where v.lookup_type = p_lookup_type
           and v.lookup_code = p_lookup_code
           and v.enabled_flag = 'Y'
           and trunc(sysdate) between v.start_date_active and nvl(v.end_date_active, trunc(sysdate));
        return l_count > 0;
    end is_valid_lookup;

    procedure assert_lookup(p_lookup_type in varchar2, p_lookup_code in varchar2, p_label in varchar2) is
    begin
        if p_lookup_code is not null and not is_valid_lookup(p_lookup_type, p_lookup_code) then
            raise_application_error(-20100,
                p_label || ': "' || p_lookup_code || '" is not an active value of ' || p_lookup_type || '.');
        end if;
    end assert_lookup;

    function replace_tokens(p_text in clob, p_tokens_json in clob) return clob is
        l_result clob := p_text;
        l_obj    json_object_t;
        l_keys   json_key_list;
    begin
        if p_text is null or p_tokens_json is null then
            return p_text;
        end if;
        l_obj  := json_object_t.parse(p_tokens_json);
        l_keys := l_obj.get_keys;
        for i in 1 .. l_keys.count loop
            l_result := replace(l_result, '#' || upper(l_keys(i)) || '#', l_obj.get_string(l_keys(i)));
        end loop;
        return l_result;
    end replace_tokens;

    procedure create_who_trigger(p_table_name in varchar2) is
        l_table varchar2(128) := upper(dbms_assert.simple_sql_name(p_table_name));
        l_trg   varchar2(128) := substr(l_table, 1, 124) || '_WHO';
    begin
        execute immediate
            'create or replace trigger ' || l_trg || '
                before insert or update on ' || l_table || '
                for each row
             begin
                 if inserting then
                     :new.created_by    := nvl(:new.created_by, xxfnd_util_pkg.current_user);
                     :new.creation_date := nvl(:new.creation_date, systimestamp);
                     :new.object_version_number := 1;
                 else
                     :new.created_by    := :old.created_by;
                     :new.creation_date := :old.creation_date;
                     :new.object_version_number := nvl(:old.object_version_number, 0) + 1;
                 end if;
                 :new.last_updated_by   := xxfnd_util_pkg.current_user;
                 :new.last_update_date  := systimestamp;
                 :new.last_update_login := sys_context(''APEX$SESSION'', ''APP_SESSION'');
             end;';
    end create_who_trigger;

    procedure create_all_who_triggers is
    begin
        for t in (select c.table_name
                    from user_tab_columns c
                    join user_tables tb on tb.table_name = c.table_name
                   where (c.table_name like 'XXFND\_%' escape '\' or c.table_name like 'XXCMP\_%' escape '\')
                     and c.column_name = 'OBJECT_VERSION_NUMBER'
                   order by c.table_name)
        loop
            create_who_trigger(t.table_name);
        end loop;
    end create_all_who_triggers;

end xxfnd_util_pkg;
/

--------------------------------------------------------------------------------
create or replace package xxfnd_audit_pkg authid definer as
    -- Set before a save to record why a configuration value changed (FR-36).
    procedure set_change_reason(p_reason in varchar2);
    function  get_change_reason return varchar2;
    procedure clear_change_reason;

    procedure log_change(p_table_name in varchar2,
                         p_pk_value   in varchar2,
                         p_action     in varchar2,
                         p_column     in varchar2 default null,
                         p_old_value  in varchar2 default null,
                         p_new_value  in varchar2 default null);

    -- Generates an AFTER INSERT/UPDATE/DELETE row trigger that writes one row
    -- per changed column (updates) or one row per record (inserts, deletes).
    -- WHO columns and LOB columns are skipped.
    procedure create_audit_trigger(p_table_name in varchar2);
    procedure create_config_audit_triggers;
end xxfnd_audit_pkg;
/

create or replace package body xxfnd_audit_pkg as
    g_reason varchar2(1000);

    procedure set_change_reason(p_reason in varchar2) is
    begin
        g_reason := substr(p_reason, 1, 1000);
    end set_change_reason;

    function get_change_reason return varchar2 is
    begin
        return g_reason;
    end get_change_reason;

    procedure clear_change_reason is
    begin
        g_reason := null;
    end clear_change_reason;

    procedure log_change(p_table_name in varchar2,
                         p_pk_value   in varchar2,
                         p_action     in varchar2,
                         p_column     in varchar2 default null,
                         p_old_value  in varchar2 default null,
                         p_new_value  in varchar2 default null) is
    begin
        insert into xxfnd_audit_log
            (table_name, pk_value, action_code, column_name, old_value, new_value, change_reason, changed_by)
        values
            (p_table_name, p_pk_value, p_action, p_column,
             substr(p_old_value, 1, 4000), substr(p_new_value, 1, 4000),
             g_reason, xxfnd_util_pkg.current_user);
    end log_change;

    function col_to_char(p_ref in varchar2, p_data_type in varchar2) return varchar2 is
    begin
        return case
                 when p_data_type like 'TIMESTAMP%' then 'to_char(' || p_ref || ', ''YYYY-MM-DD HH24:MI:SS.FF'')'
                 when p_data_type = 'DATE'          then 'to_char(' || p_ref || ', ''YYYY-MM-DD HH24:MI:SS'')'
                 when p_data_type = 'NUMBER'        then 'to_char(' || p_ref || ', ''TM9'')'
                 else p_ref
               end;
    end col_to_char;

    procedure create_audit_trigger(p_table_name in varchar2) is
        l_table varchar2(128) := upper(dbms_assert.simple_sql_name(p_table_name));
        l_trg   varchar2(128) := substr(l_table, 1, 124) || '_AUD';
        l_pk_new varchar2(4000);
        l_pk_old varchar2(4000);
        l_body  clob;
    begin
        for c in (select cc.column_name
                    from user_constraints uc
                    join user_cons_columns cc on cc.constraint_name = uc.constraint_name
                   where uc.table_name = l_table
                     and uc.constraint_type = 'P'
                   order by cc.position)
        loop
            l_pk_new := l_pk_new || case when l_pk_new is not null then ' || ''|'' || ' end || 'to_char(:new.' || c.column_name || ')';
            l_pk_old := l_pk_old || case when l_pk_old is not null then ' || ''|'' || ' end || 'to_char(:old.' || c.column_name || ')';
        end loop;
        if l_pk_new is null then
            raise_application_error(-20101, l_table || ' has no primary key; cannot generate audit trigger.');
        end if;

        l_body := 'create or replace trigger ' || l_trg || '
            after insert or update or delete on ' || l_table || '
            for each row
            declare
                l_pk varchar2(400);
            begin
                if inserting then
                    xxfnd_audit_pkg.log_change(''' || l_table || ''', ' || l_pk_new || ', ''I'');
                    return;
                elsif deleting then
                    xxfnd_audit_pkg.log_change(''' || l_table || ''', ' || l_pk_old || ', ''D'');
                    return;
                end if;
                l_pk := ' || l_pk_new || ';
';
        for c in (select column_name, data_type
                    from user_tab_columns
                   where table_name = l_table
                     and data_type not in ('CLOB','BLOB','NCLOB','LONG','LONG RAW','RAW','JSON')
                     and column_name not in ('CREATED_BY','CREATION_DATE','LAST_UPDATED_BY',
                                             'LAST_UPDATE_DATE','LAST_UPDATE_LOGIN','OBJECT_VERSION_NUMBER')
                   order by column_id)
        loop
            l_body := l_body || '
                if (:old.' || c.column_name || ' <> :new.' || c.column_name || ')
                   or (:old.' || c.column_name || ' is null and :new.' || c.column_name || ' is not null)
                   or (:old.' || c.column_name || ' is not null and :new.' || c.column_name || ' is null) then
                    xxfnd_audit_pkg.log_change(''' || l_table || ''', l_pk, ''U'', ''' || c.column_name || ''',
                        ' || col_to_char(':old.' || c.column_name, c.data_type) || ',
                        ' || col_to_char(':new.' || c.column_name, c.data_type) || ');
                end if;';
        end loop;
        l_body := l_body || '
            end;';
        execute immediate l_body;
    end create_audit_trigger;

    procedure create_config_audit_triggers is
        type t_names is table of varchar2(128);
        l_tables t_names := t_names(
            'XXFND_LOOKUP_TYPES','XXFND_LOOKUP_VALUES','XXFND_EMPLOYEES','XXFND_ROLES','XXFND_USER_ROLES',
            'XXFND_SOD_RULES','XXFND_NOTIFICATION_TEMPLATES','XXFND_RETENTION_POLICIES',
            'XXFND_INTEGRATION_ENDPOINTS','XXFND_INTEGRATION_PURPOSES',
            'XXFND_DOCUMENT_ENTITIES','XXFND_DOCUMENT_CATEGORIES','XXFND_ATTACHMENT_FUNCTIONS',
            'XXFND_ATTACHMENT_BLOCKS','XXFND_ATTACHMENT_BLK_ENTITIES','XXFND_DOC_CATEGORY_USAGES',
            'XXFND_STORAGE_CONFIG','XXFND_WF_ITEM_TYPES','XXFND_WF_PROCESSES','XXFND_WF_ACTIVITIES',
            'XXFND_WF_TRANSITIONS','XXFND_WF_DELEGATIONS',
            'XXFND_VALUE_SETS','XXFND_DF_FLEXFIELDS','XXFND_DF_CONTEXTS','XXFND_DF_SEGMENTS',
            'XXCMP_QUESTIONNAIRES','XXCMP_QUESTIONS','XXCMP_ANSWER_OPTIONS','XXCMP_CONCLUSION_TEMPLATES',
            'XXCMP_APPROVAL_MATRIX','XXCMP_ATTACHMENT_RULES','XXCMP_WF_ACTIVITY_CONTROLS');
    begin
        for i in 1 .. l_tables.count loop
            create_audit_trigger(l_tables(i));
        end loop;
    end create_config_audit_triggers;

end xxfnd_audit_pkg;
/

--------------------------------------------------------------------------------
create or replace package xxfnd_security_pkg authid definer as
    -- Resolve the signed-in person. Null when the user has no active record.
    function current_employee_id return number;

    function has_role(p_role_code in varchar2,
                      p_user_name in varchar2 default null) return boolean;
    function has_role_yn(p_role_code in varchar2,
                         p_user_name in varchar2 default null) return varchar2;
    -- Comma-separated role codes; true when the user holds any of them.
    function has_any_role(p_role_codes in varchar2,
                          p_user_name  in varchar2 default null) return boolean;
    -- Y/N form of HAS_ANY_ROLE for use in SQL (report where clauses, LOVs).
    function has_any_role_yn(p_role_codes in varchar2,
                             p_user_name  in varchar2 default null) return varchar2;
    function can_view_sensitive(p_user_name in varchar2 default null) return boolean;

    -- Four-eyes: true when the user already acted on this workflow item under a
    -- role that the SOD rules forbid combining with p_role_code (SAME_RECORD),
    -- or permanently holds a GLOBAL-conflicting role.
    function sod_conflict(p_wf_item_id in number,
                          p_role_code  in varchar2,
                          p_user_name  in varchar2 default null) return boolean;

    -- Upserts one Fusion worker (JSON object from the HCM publicWorkers resource).
    procedure upsert_fusion_worker(p_worker in json_object_t);
    -- Pages through Fusion HCM publicWorkers using APEX's native Fusion
    -- integration web credential and refreshes FUSION rows. Run by job XXFND_HCM_SYNC.
    procedure sync_from_fusion(p_base_url              in varchar2,
                               p_credential_static_id  in varchar2,
                               p_page_size             in pls_integer default 200);
    -- True while SYNC_FROM_FUSION runs; lets the Fusion-owned-row trigger
    -- (XXFND_EMPLOYEES_SRC) tell the sync apart from a user edit.
    function sync_running return boolean;

    -- Creates (or re-enables) a LOCAL employee and grants SYSTEM_ADMIN.
    -- Used by the installer so someone can sign in and grant further access.
    procedure bootstrap_admin(p_user_name in varchar2,
                              p_full_name in varchar2 default null,
                              p_email     in varchar2 default null);
end xxfnd_security_pkg;
/

create or replace view xxfnd_user_roles_v as
select ur.user_role_id,
       ur.employee_id,
       e.user_name,
       e.full_name,
       e.source_type,
       ur.role_code,
       r.role_name,
       r.application_code,
       ur.start_date_active,
       ur.end_date_active,
       ur.enabled_flag,
       case when ur.enabled_flag = 'Y' and r.enabled_flag = 'Y' and e.enabled_flag = 'Y'
             and trunc(sysdate) between ur.start_date_active and nvl(ur.end_date_active, trunc(sysdate))
             and trunc(sysdate) between e.start_date_active  and nvl(e.end_date_active,  trunc(sysdate))
            then 'Y' else 'N' end active_flag
  from xxfnd_user_roles ur
  join xxfnd_employees e on e.employee_id = ur.employee_id
  join xxfnd_roles r     on r.role_code   = ur.role_code;

create or replace package body xxfnd_security_pkg as

    g_sync_running boolean := false;

    function norm_user(p_user_name in varchar2) return varchar2 is
    begin
        return upper(nvl(p_user_name, xxfnd_util_pkg.current_user));
    end norm_user;

    function current_employee_id return number is
        l_id   xxfnd_employees.employee_id%type;
        l_user varchar2(255) := norm_user(null);   -- private functions cannot be called from SQL
    begin
        select e.employee_id
          into l_id
          from xxfnd_employees e
         where e.user_name = l_user
           and e.enabled_flag = 'Y'
           and trunc(sysdate) between e.start_date_active and nvl(e.end_date_active, trunc(sysdate));
        return l_id;
    exception
        when no_data_found then
            return null;
    end current_employee_id;

    function has_role(p_role_code in varchar2, p_user_name in varchar2 default null) return boolean is
        l_count pls_integer;
        l_user  varchar2(255) := norm_user(p_user_name);
    begin
        select count(*)
          into l_count
          from xxfnd_user_roles_v v
         where v.user_name = l_user
           and v.role_code = p_role_code
           and v.active_flag = 'Y';
        return l_count > 0;
    end has_role;

    function has_role_yn(p_role_code in varchar2, p_user_name in varchar2 default null) return varchar2 is
    begin
        return case when has_role(p_role_code, p_user_name) then 'Y' else 'N' end;
    end has_role_yn;

    function has_any_role(p_role_codes in varchar2, p_user_name in varchar2 default null) return boolean is
        l_count pls_integer;
        l_user  varchar2(255) := norm_user(p_user_name);
    begin
        select count(*)
          into l_count
          from xxfnd_user_roles_v v
         where v.user_name = l_user
           and v.active_flag = 'Y'
           and v.role_code in (select trim(column_value)
                                 from table(apex_string.split(p_role_codes, ',')));
        return l_count > 0;
    end has_any_role;

    function has_any_role_yn(p_role_codes in varchar2, p_user_name in varchar2 default null) return varchar2 is
    begin
        return case when has_any_role(p_role_codes, p_user_name) then 'Y' else 'N' end;
    end has_any_role_yn;

    function can_view_sensitive(p_user_name in varchar2 default null) return boolean is
        l_count pls_integer;
        l_user  varchar2(255) := norm_user(p_user_name);
    begin
        select count(*)
          into l_count
          from xxfnd_user_roles_v v
          join xxfnd_roles r on r.role_code = v.role_code
         where v.user_name = l_user
           and v.active_flag = 'Y'
           and r.view_sensitive_flag = 'Y';
        return l_count > 0;
    end can_view_sensitive;

    function sod_conflict(p_wf_item_id in number,
                          p_role_code  in varchar2,
                          p_user_name  in varchar2 default null) return boolean is
        l_count pls_integer;
        l_user  varchar2(255) := norm_user(p_user_name);
    begin
        -- Same record: the user already acted on this item under a conflicting role.
        select count(*)
          into l_count
          from xxfnd_wf_activity_history h
          join xxfnd_wf_activities a on a.activity_id = h.activity_id
          join xxfnd_sod_rules s
            on s.enabled_flag = 'Y'
           and s.conflict_scope = 'SAME_RECORD'
           and ((s.role_code_1 = p_role_code and s.role_code_2 = a.performer_role_code) or
                (s.role_code_2 = p_role_code and s.role_code_1 = a.performer_role_code))
         where h.wf_item_id = p_wf_item_id
           and l_user in (upper(h.actioned_by), upper(h.on_behalf_of))
           and h.result_code is not null;
        if l_count > 0 then
            return true;
        end if;

        -- Global: the user holds a role that may never be combined with p_role_code.
        select count(*)
          into l_count
          from xxfnd_sod_rules s
          join xxfnd_user_roles_v v
            on v.user_name = l_user
           and v.active_flag = 'Y'
           and v.role_code = case when s.role_code_1 = p_role_code then s.role_code_2 else s.role_code_1 end
         where s.enabled_flag = 'Y'
           and s.conflict_scope = 'GLOBAL'
           and p_role_code in (s.role_code_1, s.role_code_2);
        return l_count > 0;
    end sod_conflict;

    procedure upsert_fusion_worker(p_worker in json_object_t) is
        l_person_id   number        := p_worker.get_number('PersonId');
        l_number      varchar2(30)  := p_worker.get_string('PersonNumber');
        l_name        varchar2(240) := p_worker.get_string('DisplayName');
        l_email       varchar2(320) := lower(p_worker.get_string('WorkEmail'));
        l_dept        varchar2(240);
        l_job         varchar2(240);
        l_assignments json_array_t;
        l_asg         json_object_t;
    begin
        if l_person_id is null or l_email is null then
            return; -- a worker without a work email cannot sign in; skip
        end if;
        if p_worker.has('assignments') then
            l_assignments := p_worker.get_array('assignments');
            if l_assignments.get_size > 0 then
                l_asg  := treat(l_assignments.get(0) as json_object_t);
                l_dept := l_asg.get_string('DepartmentName');
                l_job  := l_asg.get_string('JobName');
            end if;
        end if;

        -- A LOCAL record created before the person existed in Fusion is adopted,
        -- not duplicated (the email and user name are unique).
        update xxfnd_employees
           set source_type = 'FUSION', fusion_person_id = l_person_id
         where source_type = 'LOCAL'
           and fusion_person_id is null
           and (email_address = l_email or user_name = upper(l_email));

        merge into xxfnd_employees e
        using (select l_person_id person_id from dual) s
           on (e.fusion_person_id = s.person_id)
         when matched then update set
              e.fusion_person_number = l_number,
              e.full_name            = nvl(l_name, e.full_name),
              e.email_address        = l_email,
              e.user_name            = upper(l_email),
              e.department_name      = l_dept,
              e.job_title            = l_job,
              e.enabled_flag         = 'Y',
              e.last_sync_date       = systimestamp
         when not matched then insert
              (source_type, fusion_person_id, fusion_person_number, user_name, full_name,
               email_address, department_name, job_title, last_sync_date)
              values
              ('FUSION', l_person_id, l_number, upper(l_email), nvl(l_name, l_email),
               l_email, l_dept, l_job, systimestamp);
    end upsert_fusion_worker;

    procedure sync_from_fusion(p_base_url              in varchar2,
                               p_credential_static_id  in varchar2,
                               p_page_size             in pls_integer default 200) is
        l_offset   pls_integer := 0;
        l_response clob;
        l_doc      json_object_t;
        l_items    json_array_t;
        l_has_more boolean := true;
        l_url      varchar2(4000);
        l_run_ts   timestamp := systimestamp;
    begin
        g_sync_running := true;
        while l_has_more loop
            l_url := rtrim(p_base_url, '/')
                  || '/hcmRestApi/resources/11.13.18.05/publicWorkers'
                  || '?onlyData=true&limit=' || p_page_size || '&offset=' || l_offset
                  || '&fields=PersonId,PersonNumber,DisplayName,WorkEmail;assignments:DepartmentName,JobName';
            l_response := apex_web_service.make_rest_request(
                              p_url                  => l_url,
                              p_http_method          => 'GET',
                              p_credential_static_id => p_credential_static_id);
            if apex_web_service.g_status_code <> 200 then
                raise_application_error(-20110, 'Fusion HCM sync failed with HTTP '
                    || apex_web_service.g_status_code || ': ' || dbms_lob.substr(l_response, 500, 1));
            end if;
            l_doc   := json_object_t.parse(l_response);
            l_items := l_doc.get_array('items');
            for i in 0 .. l_items.get_size - 1 loop
                upsert_fusion_worker(treat(l_items.get(i) as json_object_t));
            end loop;
            l_has_more := nvl(l_doc.get_boolean('hasMore'), false);
            l_offset   := l_offset + p_page_size;
            commit;
        end loop;

        -- Workers no longer returned by Fusion (terminated) are disabled, not deleted.
        update xxfnd_employees e
           set e.enabled_flag = 'N'
         where e.source_type = 'FUSION'
           and e.enabled_flag = 'Y'
           and (e.last_sync_date is null or e.last_sync_date < l_run_ts);
        commit;
        g_sync_running := false;
    exception
        when others then
            g_sync_running := false;
            raise;
    end sync_from_fusion;

    function sync_running return boolean is
    begin
        return g_sync_running;
    end sync_running;

    procedure bootstrap_admin(p_user_name in varchar2,
                              p_full_name in varchar2 default null,
                              p_email     in varchar2 default null) is
        l_user  varchar2(255) := upper(trim(p_user_name));
        l_email varchar2(320) := lower(trim(coalesce(p_email,
                                     case when instr(p_user_name, '@') > 0 then p_user_name end,
                                     p_user_name || '@unknown.invalid')));
        l_id    number;
    begin
        if l_user is null then
            return;
        end if;
        begin
            select employee_id into l_id from xxfnd_employees where user_name = l_user;
            update xxfnd_employees set enabled_flag = 'Y', end_date_active = null where employee_id = l_id;
        exception
            when no_data_found then
                insert into xxfnd_employees (source_type, user_name, full_name, email_address)
                values ('LOCAL', l_user, coalesce(trim(p_full_name), l_user), l_email)
                returning employee_id into l_id;
        end;
        merge into xxfnd_user_roles t
        using (select l_id employee_id, 'SYSTEM_ADMIN' role_code from dual) s
           on (t.employee_id = s.employee_id and t.role_code = s.role_code and t.end_date_active is null)
         when matched then update set t.enabled_flag = 'Y'
         when not matched then insert (employee_id, role_code) values (s.employee_id, s.role_code);
    end bootstrap_admin;

end xxfnd_security_pkg;
/

--------------------------------------------------------------------------------
create or replace package xxfnd_approval_pkg authid definer as
    -- Tables under maker-checker control.
    function is_controlled(p_table_name in varchar2) return boolean;

    procedure submit(p_table_name in varchar2, p_pk_value in varchar2);
    procedure approve(p_table_name in varchar2, p_pk_value in varchar2);
    procedure reject(p_table_name in varchar2, p_pk_value in varchar2, p_reason in varchar2);

    -- Called from the BEFORE UPDATE/INSERT trigger on each controlled table.
    -- Editing an approved row sends it back for approval; approving your own
    -- change is refused.
    procedure apply_rules(p_inserting        in boolean,
                          p_old_status       in varchar2,
                          p_new_status       in out varchar2,
                          p_old_last_updated in varchar2,
                          p_approved_by      in out varchar2,
                          p_approved_date    in out timestamp);
end xxfnd_approval_pkg;
/
