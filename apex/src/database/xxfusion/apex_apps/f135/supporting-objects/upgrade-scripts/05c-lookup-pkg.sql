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

end xxfnd_lookup_pkg;
/
