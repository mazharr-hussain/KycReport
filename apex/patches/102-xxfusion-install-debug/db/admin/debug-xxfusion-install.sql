--------------------------------------------------------------------------------
-- Debug (patch 102): why App Builder > Import cannot install an application
-- with Parsing Schema = XXFUSION.
-- Run as ADMIN (Database Actions > SQL > Run Script, or SQLcl / SQL*Plus).
-- Read-only: it changes nothing. Copy the whole output and send it.
-- Works in Database Actions (no SET LINESIZE / SPOOL; lines under 80 chars).
--
-- What happens (found with test application 301, release 89):
--   App Builder's APEXlang import calls ORDS
--     PUT /ords/<first schema>/_/apexlang/import {"parsing_schema":"XXFUSION"}
--   ORDS connects as the workspace's first schema (XXCUS) and checks
--     select count(*) from apex_workspace_schemas
--      where schema = :parsing_schema and workspace_id = :workspace
--   Outside an APEX session that view shows XXCUS only its own row, unless
--   XXCUS has APEX_ADMINISTRATOR_READ_ROLE (or APEX_ADMINISTRATOR_ROLE).
--   So ORDS answers 400 "Not allowed to install in workspace <id> or schema
--   XXFUSION." and the wizard page goes blank.
--
-- Fix (one read-only grant):  grant apex_administrator_read_role to xxcus;
--------------------------------------------------------------------------------
set serveroutput on size unlimited format wrapped
set feedback off

declare
    c_workspace constant varchar2(30) := 'XXCUS';
    c_target    constant varchar2(30) := 'XXFUSION';
    l_ws_id     number;
    l_first     varchar2(128);
    l_n         number;
    l_s         varchar2(4000);
    l_problems  pls_integer := 0;

    procedure line(p varchar2 default null) is
    begin
        dbms_output.put_line(p);
    end;

    procedure head(p varchar2) is
    begin
        line;
        line('== ' || p);
    end;

    procedure info(p varchar2) is
    begin
        line('   ' || p);
    end;

    procedure result(p_ok boolean, p_text varchar2, p_fix varchar2 default null) is
        l_ok boolean := nvl(p_ok, false);       -- an unknown answer is not OK
    begin
        line(case when l_ok then '   OK    ' else '   FIX   ' end || p_text);
        if not l_ok then
            l_problems := l_problems + 1;
            if p_fix is not null then
                line('         -> ' || p_fix);
            end if;
        end if;
    end;

    -- the role is granted to the user directly or through another role
    function has_role(p_user varchar2, p_role varchar2) return boolean is
        l number;
    begin
        select count(*) into l
          from (select granted_role from dba_role_privs
                 start with grantee = p_user
               connect by nocycle prior granted_role = grantee)
         where granted_role = p_role;
        return l > 0;
    end;

    -- REST-enabled? null when no ORDS metadata view is readable (Autonomous DB)
    function rest_enabled(p_schema varchar2) return number is
        l number;
    begin
        for v in (select column_value q from table(sys.odcivarchar2list(
                      'select count(*) from ords_metadata.ords_schemas'
                      || ' where parsing_schema = :s and status = ''ENABLED''',
                      'select count(*) from dba_ords_schemas'
                      || ' where parsing_schema = :s and status = ''ENABLED'''))) loop
            begin
                execute immediate v.q into l using p_schema;
                return l;
            exception when others then
                null;
            end;
        end loop;
        return null;
    end;
begin
    line('XXFUSION install debug');
    info(to_char(systimestamp, 'YYYY-MM-DD HH24:MI:SS TZH:TZM')
         || ', run by ' || sys_context('userenv', 'session_user'));

    head('Versions');
    begin
        execute immediate 'select version_no from apex_release' into l_s;
        info('APEX ' || l_s);
    exception when others then
        info('APEX: ' || substr(sqlerrm, 1, 70));
    end;
    begin
        execute immediate 'select version from ords_metadata.ords_version' into l_s;
        info('ORDS ' || l_s);
    exception when others then
        info('ORDS: version not readable here (not needed)');
    end;
    begin
        execute immediate 'select version_full from v$instance' into l_s;
        info('Database ' || l_s);
    exception when others then
        info('Database: version not readable here (not needed)');
    end;

    head('Database users');
    for u in (select n.column_value username, d.account_status
                from table(sys.odcivarchar2list(c_workspace, c_target, 'ORDS_PUBLIC_USER')) n
                left join dba_users d on d.username = n.column_value) loop
        result(u.account_status = 'OPEN', rpad(u.username, 18) || nvl(u.account_status, 'MISSING'),
               case when u.account_status is null and u.username = c_target
                    then 'run apex/db/admin/create-xxfusion-schema.sql as ADMIN' end);
    end loop;

    head('Workspace ' || c_workspace);
    begin
        execute immediate 'select max(workspace_id), max(first_schema_provisioned)'
                       || ' from apex_workspace_schemas where workspace_name = :w'
                     into l_ws_id, l_first using c_workspace;
    exception when others then
        info('apex_workspace_schemas: ' || substr(sqlerrm, 1, 60));
    end;
    result(l_ws_id is not null, 'workspace id ' || nvl(to_char(l_ws_id), 'NOT FOUND'),
           'run this script as ADMIN (it must read the APEX views)');
    l_first := nvl(l_first, c_workspace);
    info('first schema: ' || l_first);
    info('  (the import calls ORDS as it: /ords/' || lower(l_first)
         || '/_/apexlang/import)');
    for s in (select schema from apex_workspace_schemas
               where workspace_id = l_ws_id order by schema) loop
        info('assigned schema: ' || s.schema);
    end loop;
    select count(*) into l_n from apex_workspace_schemas
     where workspace_id = l_ws_id and schema = c_target;
    result(l_n > 0, c_target || ' is assigned to the workspace',
           'Manage Workspaces > Workspace to Schema Assignments > Add');

    head('ORDS (REST-enabled schemas, proxy connections)');
    for s in (select column_value schema
                from table(sys.odcivarchar2list(l_first, c_target))) loop
        l_n := rest_enabled(s.schema);
        if l_n is null then
            info(rpad(s.schema, 18) || 'REST-enabled: not readable here');
        else
            result(l_n > 0, rpad(s.schema, 18) || 'REST-enabled',
                   'as ' || s.schema || ': exec ords.enable_schema;');
        end if;
        select count(*) into l_n from dba_proxies
         where proxy = 'ORDS_PUBLIC_USER' and client = s.schema;
        result(l_n > 0, rpad(s.schema, 18) || 'ORDS may connect through it',
               'alter user ' || lower(s.schema)
               || ' grant connect through ords_public_user;');
    end loop;

    head('The ORDS import check (the cause of the error)');
    info('ORDS, connected as ' || l_first || ', runs:');
    info('  select count(*) from apex_workspace_schemas');
    info('   where schema = ''' || c_target || '''');
    info('     and workspace_id = ' || nvl(to_char(l_ws_id), '?'));
    info('Outside an APEX session ' || l_first || ' sees only its own row,');
    info('unless it has an APEX administrator role.');
    if l_first = c_target then
        result(true, 'the first schema is ' || c_target || ' itself');
    else
        result(has_role(l_first, 'APEX_ADMINISTRATOR_READ_ROLE')
               or has_role(l_first, 'APEX_ADMINISTRATOR_ROLE'),
               l_first || ' has APEX_ADMINISTRATOR_READ_ROLE',
               'grant apex_administrator_read_role to ' || lower(l_first) || ';');
        for r in (select granted_role, default_role from dba_role_privs
                   where grantee = l_first and granted_role like 'APEX%') loop
            info(l_first || ' role: ' || r.granted_role
                 || ' (default ' || r.default_role || ')');
        end loop;
    end if;

    head('Applications of the workspace by parsing schema');
    for a in (select owner, count(*) n from apex_applications
               where workspace = c_workspace group by owner order by owner) loop
        info(rpad(a.owner, 18) || a.n || ' application(s)');
    end loop;
    for a in (select application_id, alias from apex_applications
               where workspace = c_workspace and owner = c_target
               order by application_id) loop
        info('  in ' || c_target || ': ' || a.application_id || ' ' || a.alias);
    end loop;

    head('Privileges ' || c_target || ' needs (COMMON script 00a checks them too)');
    for p in (select column_value priv from table(sys.odcivarchar2list(
                  'CREATE SESSION', 'CREATE TABLE', 'CREATE VIEW', 'CREATE SEQUENCE',
                  'CREATE PROCEDURE', 'CREATE TRIGGER', 'CREATE TYPE',
                  'CREATE SYNONYM', 'CREATE JOB'))) loop
        select count(*) into l_n from dba_sys_privs
         where privilege = p.priv
           and (grantee = c_target
                or grantee in (select granted_role from dba_role_privs
                                start with grantee = c_target
                              connect by nocycle prior granted_role = grantee));
        result(l_n > 0, p.priv, 'grant ' || lower(p.priv) || ' to ' || lower(c_target) || ';');
    end loop;
    select count(*) into l_n from dba_ts_quotas where username = c_target;
    select l_n + count(*) into l_n from dba_sys_privs
     where grantee = c_target and privilege = 'UNLIMITED TABLESPACE';
    result(l_n > 0, 'tablespace quota',
           'alter user ' || lower(c_target) || ' quota unlimited on data;');

    head('Result');
    if l_problems = 0 then
        info('Nothing to fix: App Builder > Import with Parsing Schema =');
        info(c_target || ' should work. Test it with application 301');
        info('(XXFTEST-Application-APEXlang_1.zip, patch 102).');
    else
        info(l_problems || ' item(s) to fix: run the "->" statements above');
        info('as ADMIN, then run this script again.');
    end if;
end;
/

set feedback on
