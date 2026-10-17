
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
    -- On while user names are renamed (xxfnd_user_pkg.rename_user): the WHO triggers keep the dates and
    -- version of the rows and accept the new user names in CREATED_BY / LAST_UPDATED_BY.
    procedure set_preserve_who(p_on in boolean);
    function preserve_who return boolean;

    -- Replace #TOKEN# placeholders from a JSON object {"TOKEN":"value",...}.
    function replace_tokens(p_text in clob, p_tokens_json in clob) return clob;

    -- WHO-column trigger: fills CREATED_BY/CREATION_DATE/LAST_UPDATED_BY/
    -- LAST_UPDATE_DATE/LAST_UPDATE_LOGIN and increments OBJECT_VERSION_NUMBER.
    procedure create_who_trigger(p_table_name in varchar2);
    -- Creates WHO triggers on every XXFND_/XXCMP_ table that has the WHO columns.
    procedure create_all_who_triggers;

    -- release 54: owner of a table, view or package this schema can see - itself first, else the application
    -- schema that granted it (KYC objects in XXCUS); raises -20130 when there is none.
    function object_owner(p_name in varchar2) return varchar2;
    -- "OWNER"."NAME" of that object, for dynamic SQL.
    function qualified(p_name in varchar2) return varchar2;
end xxfnd_util_pkg;
/

create or replace package body xxfnd_util_pkg as

    g_install_mode boolean := false;
    g_preserve_who boolean := false;

    procedure set_install_mode(p_on in boolean) is
    begin
        g_install_mode := nvl(p_on, false);
    end set_install_mode;

    procedure set_preserve_who(p_on in boolean) is
    begin
        g_preserve_who := nvl(p_on, false);
    end set_preserve_who;

    function preserve_who return boolean is
    begin
        return g_preserve_who;
    end preserve_who;

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

    -- Result-cached per type, code and language: report queries call LOOKUP_MEANING for every row and column.
    -- Oracle invalidates the cache when XXFND_LOOKUP_VALUES(_TL) change.
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
    begin
        xxfnd_schema_pkg.create_who_trigger(p_table_name);
    end create_who_trigger;

    procedure create_all_who_triggers is
    begin
        xxfnd_schema_pkg.create_all_who_triggers;
    end create_all_who_triggers;

    function object_owner(p_name in varchar2) return varchar2 is
        l_owner varchar2(128);
    begin
        select max(owner) keep (dense_rank first order by case when owner = $$PLSQL_UNIT_OWNER then 0 else 1 end, owner)
          into l_owner
          from all_objects
         where object_name = upper(p_name) and object_type in ('TABLE', 'VIEW', 'PACKAGE');
        if l_owner is null then
            raise_application_error(-20130, p_name || ' does not exist or is not granted to ' || $$PLSQL_UNIT_OWNER || '.');
        end if;
        return l_owner;
    end object_owner;

    function qualified(p_name in varchar2) return varchar2 is
    begin
        return dbms_assert.enquote_name(object_owner(p_name), false) || '.'
            || dbms_assert.enquote_name(upper(dbms_assert.simple_sql_name(p_name)), false);
    end qualified;

end xxfnd_util_pkg;
/

-- every registered application gets its menu entries (only what is missing)
begin
    xxfnd_util_pkg.set_install_mode(true);
    for a in (select application_code from xxfnd_applications where application_code <> 'COMMON') loop
        xxfnd_application_pkg.ensure_menu(a.application_code);
    end loop;
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/

-- C5: the documents of an RFI on page 143 (region "documents"; add and replace, no remove) and the RFI task settings
-- (no due days: the RFI's own due date applies to the answer; IT sets the rest in Task Settings), added when missing
begin
    xxfnd_util_pkg.set_install_mode(true);
    xxfnd_attach_pkg.register_attachment_page(p_application_code    => 'COMMON',
                                              p_function_code       => 'COMMON_RFI',
                                              p_function_name       => 'Information Request - documents of the RFI',
                                              p_page_id             => 143,
                                              p_block_code          => 'DOCUMENTS',
                                              p_region_static_id    => 'documents',
                                              p_entity_name         => 'XXFND_RFIS',
                                              p_pk1_page_item       => 'RFI_ID',
                                              p_block_name          => 'Documents',
                                              p_insert_allowed_flag => 'Y',
                                              p_update_allowed_flag => 'Y',
                                              p_delete_allowed_flag => 'N');
    xxfnd_workflow_pkg.register_task_setting(p_application_code     => 'COMMON',
                                             p_task_definition      => 'RFI_RESPONSE',
                                             p_reminder_days_before => 1,
                                             p_description          => 'Provide the requested information: due on the RFI''s due date.');
    xxfnd_workflow_pkg.register_task_setting(p_application_code     => 'COMMON',
                                             p_task_definition      => 'RFI_REVIEW',
                                             p_description          => 'Review the information received.');
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
