--------------------------------------------------------------------------------
-- 00c Onboard with COMMON (release 87 of COMMON). Generic: the same script for every application that uses the common
--   components, kept once in COMMON's framework. Listed in the application's own install and upgrade order (after
--   00a), it runs as the application's schema and gives the application the bare minimum:
--     1. COMMON (release 87 or later) is installed, else it stops with ORA-20906 and changes nothing;
--     2. the application is registered in COMMON (XXFND_ONBOARD_PKG.ONBOARD_SELF: registration rows, grants, the role
--        <CODE>_ADMIN for the administrator, the menu entries) - a registered application is refreshed;
--     3. a synonym for every COMMON object granted to the schema (synonyms of removed objects are dropped).
--   The install wizard may ask for two values (supporting objects substitutions, prompted): ONBOARD_APP_CODE (default:
--   the application's alias) and ONBOARD_ADMIN_USER (optional: the application's administrator). Nothing else is asked
--   and no APEX setting changes; the rest is set up by IT in COMMON (Application Journey).
-- Idempotent: a re-run changes nothing.
--------------------------------------------------------------------------------
declare
    c_common constant varchar2(30) := 'XXFUSION';
    l_n      pls_integer;
    l_code   varchar2(255);
    l_admin  varchar2(255);
begin
    select count(*) into l_n from all_objects
     where owner = c_common and object_name = 'XXFND_ONBOARD_PKG' and object_type = 'PACKAGE';
    if l_n = 0 then
        raise_application_error(-20906,
            'ACTION NEEDED - COMMON (release 87 or later) is not installed in ' || c_common || ', or it has not given this '
            || 'schema access yet. Nothing was installed.' || chr(10)
            || '1. Install or upgrade the COMMON application and wait until it has finished.' || chr(10)
            || '2. Come back: App Builder > the application > Utilities > Supporting Objects > Install Supporting Objects.');
    end if;
    -- the values the install wizard asked for (App Builder: the application being installed)
    begin
        execute immediate q'~select max(case when substitution_string = 'ONBOARD_APP_CODE' then substitution_value end),
                                     max(case when substitution_string = 'ONBOARD_ADMIN_USER' then substitution_value end)
                                from apex_application_substitutions
                               where application_id = to_number(v('FB_FLOW_ID'))~'
            into l_code, l_admin;
    exception
        when others then
            null;   -- outside App Builder: the defaults
    end;
    execute immediate 'begin ' || c_common || '.xxfnd_onboard_pkg.onboard_self(:s, :c, :a); end;'
        using sys_context('userenv', 'current_schema'), trim(l_code), trim(l_admin);
    commit;
end;
/

-- the synonyms of the common objects granted to this schema (the framework's own objects stay local)
declare
    c_common constant varchar2(30) := 'XXFUSION';
    l_n      pls_integer;
begin
    for s in (select synonym_name from user_synonyms u
               where u.table_owner = c_common and u.synonym_name like 'XXFND\_%' escape '\'
                 and not exists (select 1 from all_objects o where o.owner = c_common and o.object_name = u.table_name)) loop
        execute immediate 'drop synonym ' || s.synonym_name;
    end loop;
    for o in (select distinct object_name from all_objects
               where owner = c_common and object_name like 'XXFND\_%' escape '\'
                 and object_type in ('TABLE', 'VIEW', 'SEQUENCE', 'PACKAGE', 'TYPE', 'PROCEDURE', 'FUNCTION')
                 and object_name not in ('XXFND_SCHEMA_RELEASES', 'XXFND_DDL_PKG', 'XXFND_DROPPED_OBJECTS')) loop
        select count(*) into l_n from user_objects where object_name = o.object_name;
        if l_n = 0 then
            execute immediate 'create synonym ' || o.object_name || ' for ' || c_common || '.' || o.object_name;
        end if;
    end loop;
end;
/
