--------------------------------------------------------------------------------
-- 00a Prerequisites check (release 50). First script of every install and upgrade, for every application.
--   Checks that the parsing schema has the privileges the scripts need. When one is missing, the script stops
--   with an error that lists the exact statements to run as ADMIN; run them, then come back and run
--   Supporting Objects again (App Builder > the application > Utilities > Supporting Objects >
--   Install Supporting Objects / Upgrade). Every script can be re-run, so nothing needs to be undone.
--------------------------------------------------------------------------------
declare
    l_schema varchar2(128) := sys_context('userenv', 'current_schema');
    l_fix    varchar2(4000);
    l_n      pls_integer;
begin
    -- system privileges (directly or through a role)
    for p in (select column_value priv
                from table(sys.odcivarchar2list('CREATE TABLE', 'CREATE VIEW', 'CREATE SEQUENCE', 'CREATE PROCEDURE',
                                                'CREATE TRIGGER', 'CREATE TYPE', 'CREATE SYNONYM', 'CREATE JOB',
                                                'CREATE MATERIALIZED VIEW'))) loop
        select count(*) into l_n from session_privs where privilege = p.priv;
        if l_n = 0 then
            l_fix := l_fix || 'grant ' || lower(p.priv) || ' to ' || l_schema || ';' || chr(10);
        end if;
    end loop;
    -- packages used by stored code: must be granted directly to the schema
    for p in (select column_value pkg from table(sys.odcivarchar2list('DBMS_RLS', 'DBMS_CRYPTO'))) loop
        select count(*) into l_n from user_tab_privs
         where owner = 'SYS' and table_name = p.pkg and privilege = 'EXECUTE' and grantee in (l_schema, 'PUBLIC');
        if l_n = 0 then
            l_fix := l_fix || 'grant execute on sys.' || lower(p.pkg) || ' to ' || l_schema || ';' || chr(10);
        end if;
    end loop;
    -- tables need space
    select count(*) into l_n from user_ts_quotas where max_bytes = -1 or max_bytes > 0;
    if l_n = 0 then
        select count(*) into l_n from session_privs where privilege = 'UNLIMITED TABLESPACE';
        if l_n = 0 then
            for t in (select lower(default_tablespace) ts from user_users) loop
                l_fix := l_fix || 'alter user ' || l_schema || ' quota unlimited on ' || t.ts || ';' || chr(10);
            end loop;
        end if;
    end if;
    if l_fix is not null then
        raise_application_error(-20900,
            'ACTION NEEDED - schema ' || l_schema || ' is missing privileges.' || chr(10)
            || '1. Sign in to the database as ADMIN (Database Actions > SQL) and run:' || chr(10)
            || l_fix
            || '2. Come back and run Supporting Objects again: App Builder > this application > Utilities > '
            || 'Supporting Objects > Install Supporting Objects (or Upgrade). Every script can be re-run.');
    end if;
end;
/
