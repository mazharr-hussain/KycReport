create or replace package body xxcus.xxfnd_util_pkg as

    g_install_mode boolean := false;

    procedure set_install_mode (
        p_on in boolean
    ) is
    begin
        g_install_mode := nvl(p_on, false);
    end set_install_mode;

    function in_apex_session return boolean is
    begin
        return
            not g_install_mode
            and sys_context('APEX$SESSION', 'APP_USER') is not null;
    end in_apex_session;

    function current_user return varchar2 is
    begin
        return coalesce(
            sys_context('APEX$SESSION', 'APP_USER'),
            sys_context('USERENV', 'SESSION_USER')
        );
    end current_user;

    function current_lang return varchar2 is
        l_lang varchar2(30);
    begin
        if in_apex_session then
            begin
                l_lang := lower(apex_util.get_session_lang);
            exception
                when others then
                    l_lang := null;
            end;
        end if;
        -- Normalise regional variants ('en-us' -> 'en') to match seeded rows.
        return nvl(
            regexp_substr(l_lang, '^[a-z]+'),
            'en'
        );
    end current_lang;

    -- Result-cached per type, code and language: report queries call LOOKUP_MEANING for every row and column.
    -- Oracle invalidates the cache when XXFND_LOOKUP_VALUES(_TL) change.
    function cached_meaning (
        p_lookup_type in varchar2,
        p_lookup_code in varchar2,
        p_lang        in varchar2
    ) return varchar2
        result_cache
    is
        l_meaning xxfnd_lookup_values.meaning%type;
    begin
        if p_lookup_code is null then
            return null;
        end if;
        select
            nvl(t.meaning, v.meaning)
        into l_meaning
        from
            xxfnd_lookup_values    v
            left join xxfnd_lookup_values_tl t on t.lookup_type = v.lookup_type
                                                  and t.lookup_code = v.lookup_code
                                                  and t.language_code = p_lang
        where
                v.lookup_type = p_lookup_type
            and v.lookup_code = p_lookup_code;

        return l_meaning;
    exception
        when no_data_found then
            return p_lookup_code;
    end cached_meaning;

    function lookup_meaning (
        p_lookup_type in varchar2,
        p_lookup_code in varchar2
    ) return varchar2 is
        pragma udf;
    begin
        if p_lookup_code is null then
            return null;
        end if;
        return cached_meaning(p_lookup_type, p_lookup_code, current_lang);
    end lookup_meaning;

    function is_valid_lookup (
        p_lookup_type in varchar2,
        p_lookup_code in varchar2
    ) return boolean is
        l_count pls_integer;
    begin
        select
            count(*)
        into l_count
        from
            xxfnd_lookup_values v
        where
                v.lookup_type = p_lookup_type
            and v.lookup_code = p_lookup_code
            and v.enabled_flag = 'Y'
            and trunc(sysdate) between v.start_date_active and nvl(v.end_date_active,
                                                                   trunc(sysdate));

        return l_count > 0;
    end is_valid_lookup;

    procedure assert_lookup (
        p_lookup_type in varchar2,
        p_lookup_code in varchar2,
        p_label       in varchar2
    ) is
    begin
        if
            p_lookup_code is not null
            and not is_valid_lookup(p_lookup_type, p_lookup_code)
        then
            raise_application_error(-20100, p_label
                                            || ': "'
                                            || p_lookup_code
                                            || '" is not an active value of '
                                            || p_lookup_type
                                            || '.');

        end if;
    end assert_lookup;

    function replace_tokens (
        p_text        in clob,
        p_tokens_json in clob
    ) return clob is
        l_result clob := p_text;
        l_obj    json_object_t;
        l_keys   json_key_list;
    begin
        if p_text is null
           or p_tokens_json is null then
            return p_text;
        end if;
        l_obj := json_object_t.parse(p_tokens_json);
        l_keys := l_obj.get_keys;
        for i in 1..l_keys.count loop
            l_result := replace(l_result,
                                '#'
                                || upper(l_keys(i))
                                || '#',
                                l_obj.get_string(l_keys(i)));
        end loop;

        return l_result;
    end replace_tokens;

    procedure create_who_trigger (
        p_table_name in varchar2
    ) is

        l_table varchar2(128) := upper(dbms_assert.simple_sql_name(p_table_name));
        l_trg   varchar2(128) := substr(l_table, 1, 124)
                               || '_WHO';
    begin
        execute immediate 'create or replace trigger '
                          || l_trg
                          || '
                before insert or update on '
                          || l_table
                          || '
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
        for t in (
            select
                c.table_name
            from
                     user_tab_columns c
                join user_tables tb on tb.table_name = c.table_name
            where
                ( c.table_name like 'XXFND\_%' escape '\'
                  or c.table_name like 'XXCMP\_%' escape '\' )
                and c.column_name = 'OBJECT_VERSION_NUMBER'
            order by
                c.table_name
        ) loop
            create_who_trigger(t.table_name);
        end loop;
    end create_all_who_triggers;

end xxfnd_util_pkg;
/


-- sqlcl_snapshot {"hash":"4ebdae52753dfb08a324632756f01869f1726e9a","type":"PACKAGE_BODY","name":"XXFND_UTIL_PKG","schemaName":"XXCUS","sxml":""}