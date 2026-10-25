
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
