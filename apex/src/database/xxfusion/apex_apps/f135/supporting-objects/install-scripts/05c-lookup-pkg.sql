--------------------------------------------------------------------------------
-- 05c XXFND_LOOKUP_PKG - the Lookups component of Reference Data (release 80). COMMON only (XXFUSION).
--   The lookup helpers moved here from XXFND_UTIL_PKG (old callers break on purpose: no wrappers): the meaning of a
--   value in the session language (English when not translated), the check that a value is active.
-- Idempotent: safe on install and on every upgrade.
--------------------------------------------------------------------------------
create or replace package xxfnd_lookup_pkg authid definer as
    -- The meaning of a lookup value in the session language (falls back to English, then to the code).
    function lookup_meaning(p_lookup_type in varchar2, p_lookup_code in varchar2) return varchar2;
    -- True when the value exists and is active today.
    function is_valid_lookup(p_lookup_type in varchar2, p_lookup_code in varchar2) return boolean;
    -- Raises ORA-20100 (with P_LABEL) when a given value is not an active value of the lookup type.
    procedure assert_lookup(p_lookup_type in varchar2, p_lookup_code in varchar2, p_label in varchar2);

    -- Release 86: registration by an application. Added only when missing; what an administrator changed is kept;
    -- a re-run does nothing. The application must be registered (ORA-20180); a lookup type of another application
    -- is refused (ORA-20186). COMMON's rows are the instance's (no application). No APEX session needed.
    procedure register_lookup_type(p_application_code    in varchar2,
                                   p_lookup_type         in varchar2,
                                   p_meaning             in varchar2,
                                   p_customization_level in varchar2 default 'E',
                                   p_description         in varchar2 default null);
    -- A value of a lookup type (ORA-20187 when the type is not registered); P_MEANING_AR: its Arabic meaning.
    procedure register_lookup_value(p_application_code   in varchar2,
                                    p_lookup_type        in varchar2,
                                    p_lookup_code        in varchar2,
                                    p_meaning            in varchar2,
                                    p_display_sequence   in number   default null,
                                    p_description        in varchar2 default null,
                                    p_tag                in varchar2 default null,
                                    p_parent_lookup_type in varchar2 default null,
                                    p_parent_lookup_code in varchar2 default null,
                                    p_meaning_ar         in varchar2 default null);
    -- Release 88 (C8, C9): removes what the application registered (its own rows only, through
    -- XXFND_APPLICATION_PKG.REMOVE_REGISTERED: ORA-20187 not registered, ORA-20186 another application's, ORA-20196 in use).
    procedure unregister_lookup_value(p_application_code in varchar2, p_lookup_type in varchar2, p_lookup_code in varchar2);
    -- the type with its values
    procedure unregister_lookup_type(p_application_code in varchar2, p_lookup_type in varchar2);
    -- every lookup type of the application with its values (XXFND_APPLICATION_PKG.DELETE_APPLICATION)
    procedure unregister_application(p_application_code in varchar2);
end xxfnd_lookup_pkg;
/

create or replace package body xxfnd_lookup_pkg as

    function cached_meaning(p_lookup_type in varchar2, p_lookup_code in varchar2, p_lang in varchar2)
        return varchar2 result_cache is
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
           and t.language_code = p_lang
         where v.lookup_type = p_lookup_type
           and v.lookup_code = p_lookup_code;
        return l_meaning;
    exception
        when no_data_found then
            return p_lookup_code;
    end cached_meaning;

    function lookup_meaning(p_lookup_type in varchar2, p_lookup_code in varchar2) return varchar2 is
        pragma udf;
    begin
        if p_lookup_code is null then
            return null;
        end if;
        return cached_meaning(p_lookup_type, p_lookup_code, xxfnd_util_pkg.current_lang);
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

    ----------------------------------------------------------------------------
    -- Release 86: registration. XXFND_APPLICATION_PKG (09d, the registration rule) and XXFND_ERROR_PKG (09f) are
    -- installed after this package: called by name.
    ----------------------------------------------------------------------------
    function setup_code(p_application_code in varchar2) return varchar2 is
        l_code varchar2(30);
    begin
        execute immediate 'begin :r := xxfnd_application_pkg.setup_code(:c); end;' using out l_code, in p_application_code;
        return l_code;
    end setup_code;

    -- release 88: XXFND_APPLICATION_PKG is created after this package (09d): called by name
    function registered_code(p_application_code in varchar2) return varchar2 is
        l_code varchar2(30);
    begin
        execute immediate 'begin :r := xxfnd_application_pkg.registered_code(:c); end;' using out l_code, in p_application_code;
        return l_code;
    end registered_code;

    procedure remove_registered(p_application_code in varchar2, p_what in varchar2, p_table in varchar2,
                                p_key_columns in apex_t_varchar2, p_keys in apex_t_varchar2,
                                p_owner_sql in varchar2 default 't.application_code') is
    begin
        execute immediate 'begin xxfnd_application_pkg.remove_registered(:a, :w, :t, :c, :k, :o); end;'
            using p_application_code, p_what, p_table, p_key_columns, p_keys, p_owner_sql;
    end remove_registered;

    procedure remove_all_registered(p_application_code in varchar2, p_what in varchar2, p_table in varchar2,
                                    p_owner_sql in varchar2 default 't.application_code') is
    begin
        execute immediate 'begin xxfnd_application_pkg.remove_all_registered(:a, :w, :t, :o); end;'
            using p_application_code, p_what, p_table, p_owner_sql;
    end remove_all_registered;

    -- the lookup type's application, checked against the registering one; false when the type does not exist
    function type_checked(p_lookup_type in varchar2, p_application_code in varchar2) return boolean is
        l_n    pls_integer;
        l_code xxfnd_lookup_types.application_code%type;
    begin
        select count(*), max(application_code) into l_n, l_code from xxfnd_lookup_types where lookup_type = upper(p_lookup_type);
        if l_n > 0 then
            execute immediate 'begin xxfnd_application_pkg.assert_same_application(:w, :k, :r, :a); end;'
                using 'Lookup type', upper(p_lookup_type), l_code, p_application_code;
        end if;
        return l_n > 0;
    end type_checked;

    procedure register_lookup_type(p_application_code    in varchar2,
                                   p_lookup_type         in varchar2,
                                   p_meaning             in varchar2,
                                   p_customization_level in varchar2 default 'E',
                                   p_description         in varchar2 default null) is
        l_code varchar2(30) := setup_code(p_application_code);
    begin
        if type_checked(p_lookup_type, p_application_code) then
            return;
        end if;
        insert into xxfnd_lookup_types (lookup_type, meaning, customization_level, application_code, description)
        values (upper(p_lookup_type), p_meaning, upper(nvl(p_customization_level, 'E')), l_code, p_description);
    end register_lookup_type;

    procedure register_lookup_value(p_application_code   in varchar2,
                                    p_lookup_type        in varchar2,
                                    p_lookup_code        in varchar2,
                                    p_meaning            in varchar2,
                                    p_display_sequence   in number   default null,
                                    p_description        in varchar2 default null,
                                    p_tag                in varchar2 default null,
                                    p_parent_lookup_type in varchar2 default null,
                                    p_parent_lookup_code in varchar2 default null,
                                    p_meaning_ar         in varchar2 default null) is
        l_code varchar2(30) := setup_code(p_application_code);
    begin
        if not type_checked(p_lookup_type, p_application_code) then
            execute immediate 'begin xxfnd_error_pkg.raise_error(:c, apex_t_varchar2(:w, :k)); end;'
                using 'XXFND_REG_UNKNOWN', 'Lookup type', upper(p_lookup_type);
        end if;
        merge into xxfnd_lookup_values t
        using (select upper(p_lookup_type) lookup_type, p_lookup_code lookup_code from dual) s
           on (t.lookup_type = s.lookup_type and t.lookup_code = s.lookup_code)
         when not matched then insert (lookup_type, lookup_code, meaning, description, tag, display_sequence,
                                       parent_lookup_type, parent_lookup_code)
                               values (s.lookup_type, s.lookup_code, p_meaning, p_description, p_tag, p_display_sequence,
                                       upper(p_parent_lookup_type), p_parent_lookup_code);
        if p_meaning_ar is not null then
            merge into xxfnd_lookup_values_tl t
            using (select upper(p_lookup_type) lookup_type, p_lookup_code lookup_code, 'ar' language_code from dual) s
               on (t.lookup_type = s.lookup_type and t.lookup_code = s.lookup_code and t.language_code = s.language_code)
             when not matched then insert (lookup_type, lookup_code, language_code, meaning)
                                   values (s.lookup_type, s.lookup_code, 'ar', p_meaning_ar);
        end if;
    end register_lookup_value;

    -- release 88 (C8, C9)
    procedure unregister_lookup_value(p_application_code in varchar2, p_lookup_type in varchar2, p_lookup_code in varchar2) is
    begin
        remove_registered(p_application_code, 'Lookup value', 'XXFND_LOOKUP_VALUES',
            apex_t_varchar2('LOOKUP_TYPE', 'LOOKUP_CODE'), apex_t_varchar2(upper(trim(p_lookup_type)), upper(trim(p_lookup_code))),
            '(select y.application_code from xxfnd_lookup_types y where y.lookup_type = t.lookup_type)');
    end unregister_lookup_value;

    procedure unregister_lookup_type(p_application_code in varchar2, p_lookup_type in varchar2) is
        l_type xxfnd_lookup_types.lookup_type%type := upper(trim(p_lookup_type));
        l_code varchar2(30) := registered_code(p_application_code);
        l_n    pls_integer;
    begin
        select count(*) into l_n from xxfnd_lookup_types
         where lookup_type = l_type and nvl(application_code, 'COMMON') = l_code;
        if l_n > 0 then
            for v in (select lookup_code from xxfnd_lookup_values where lookup_type = l_type) loop
                unregister_lookup_value(p_application_code, l_type, v.lookup_code);
            end loop;
        end if;
        remove_registered(p_application_code, 'Lookup type', 'XXFND_LOOKUP_TYPES', apex_t_varchar2('LOOKUP_TYPE'), apex_t_varchar2(l_type));
    end unregister_lookup_type;

    procedure unregister_application(p_application_code in varchar2) is
        l_code varchar2(30) := registered_code(p_application_code);
    begin
        for t in (select lookup_type from xxfnd_lookup_types where application_code = l_code) loop
            unregister_lookup_type(p_application_code, t.lookup_type);
        end loop;
    end unregister_application;

end xxfnd_lookup_pkg;
/
