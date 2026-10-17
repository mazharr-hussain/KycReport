--------------------------------------------------------------------------------
-- Debug (patch 102): why App Builder > Import cannot install an application with Parsing Schema = XXFUSION.
-- Run as ADMIN (Database Actions > SQL > Run Script, or SQLcl / SQL*Plus). Read-only: it changes nothing.
-- It prints a report; copy the whole output (or the spooled file debug-xxfusion-install.txt) and send it.
--
-- What happens (found with test application 301, release 89):
--   App Builder's APEXlang import does not run in the database session of the APEX builder. It calls ORDS:
--     PUT /ords/<schema>/_/apexlang/import   {"parsing_schema": "XXFUSION", ...}
--   where <schema> is the workspace's first schema (XXCUS). ORDS connects as that schema and, before it
--   installs anything, checks
--     select count(*) from apex_workspace_schemas where schema = :parsing_schema and workspace_id = :workspace
--   That view, outside an APEX session, shows a schema only its own row - unless the schema has the role
--   APEX_ADMINISTRATOR_READ_ROLE (or APEX_ADMINISTRATOR_ROLE). So for XXCUS the count for XXFUSION is 0 and ORDS
--   answers 400 "Not allowed to install in workspace <id> or schema XXFUSION." and the wizard page goes blank.
--   XXFUSION being assigned to the workspace and REST-enabled is necessary, but not enough.
--
-- Fix (one grant, read-only on APEX metadata):
--   grant apex_administrator_read_role to xxcus;
-- Without the grant, keep the documented route (import as XXCUS, then switch the parsing schema) or import with
-- SQLcl connected as XXFUSION (apex import -input <unzipped app folder>).
--------------------------------------------------------------------------------
set serveroutput on size unlimited format wrapped
set feedback off
set linesize 200
spool debug-xxfusion-install.txt

declare
    c_workspace constant varchar2(30) := 'XXCUS';
    c_target    constant varchar2(30) := 'XXFUSION';
    l_ws_id     number;
    l_first     varchar2(128);
    l_n         number;
    l_s         varchar2(4000);
    l_problems  pls_integer := 0;

    procedure line(p varchar2 default null) is begin dbms_output.put_line(p); end;
    procedure head(p varchar2) is begin line; line('== ' || p); end;
    procedure result(p_ok boolean, p_text varchar2, p_fix varchar2 default null) is
    begin
        line(case when p_ok then '  OK         ' else '  DIFFERENT  ' end || p_text);
        if not p_ok then
            l_problems := l_problems + 1;
            if p_fix is not null then line('             fix: ' || p_fix); end if;
        end if;
    end;
    -- a count from a query that may not exist or be readable on this database (ORDS metadata, APEX views)
    function cnt(p_sql varchar2, p_bind varchar2 default null) return number is
        l number;
    begin
        if p_bind is null then execute immediate p_sql into l; else execute immediate p_sql into l using p_bind; end if;
        return l;
    exception when others then
        line('             (not readable: ' || substr(sqlerrm, 1, 120) || ')');
        return null;
    end;
    -- the role is granted to the user directly or through another role
    function has_role(p_user varchar2, p_role varchar2) return boolean is
        l number;
    begin
        select count(*) into l
          from (select granted_role from dba_role_privs
                 start with grantee = p_user connect by nocycle prior granted_role = grantee)
         where granted_role = p_role;
        return l > 0;
    end;
begin
    line('XXFUSION install debug - ' || to_char(systimestamp, 'YYYY-MM-DD HH24:MI:SS TZH:TZM')
         || ' - run by ' || sys_context('userenv', 'session_user')
         || ' in ' || sys_context('userenv', 'con_name'));

    head('Versions');
    begin
        execute immediate 'select version_no from apex_release' into l_s;
        line('  APEX ' || l_s);
    exception when others then line('  APEX: ' || sqlerrm);
    end;
    begin
        execute immediate 'select version from ords_metadata.ords_version' into l_s;
        line('  ORDS ' || l_s);
    exception when others then line('  ORDS: not readable (' || substr(sqlerrm, 1, 100) || ')');
    end;
    select banner_full into l_s from v$version where rownum = 1;
    line('  ' || replace(l_s, chr(10), ' '));

    head('Database users');
    for u in (select n.column_value username, d.account_status, d.default_tablespace
                from table(sys.odcivarchar2list(c_workspace, c_target, 'ORDS_PUBLIC_USER', 'APEX_PUBLIC_USER')) n
                left join dba_users d on d.username = n.column_value) loop
        result(u.account_status = 'OPEN', rpad(u.username, 18) || nvl(u.account_status, 'MISSING')
               || case when u.default_tablespace is not null then ' (tablespace ' || u.default_tablespace || ')' end,
               case when u.account_status is null and u.username = c_target
                    then 'run apex/db/admin/create-xxfusion-schema.sql as ADMIN' end);
    end loop;

    head('Workspace ' || c_workspace);
    begin
        execute immediate 'select max(workspace_id), max(first_schema_provisioned) from apex_workspace_schemas'
                       || ' where workspace_name = :w' into l_ws_id, l_first using c_workspace;
    exception when others then line('  apex_workspace_schemas: ' || sqlerrm);
    end;
    result(l_ws_id is not null, 'workspace id ' || nvl(to_char(l_ws_id), 'NOT FOUND'),
           'if the workspace exists, the user running this script cannot read the APEX views: run it as ADMIN'
           || ' (or grant apex_administrator_read_role to the user running it)');
    line('             first schema: ' || nvl(l_first, '-')
         || '  <- App Builder''s APEXlang import calls ORDS as this schema (/ords/'
         || lower(nvl(l_first, c_workspace)) || '/_/apexlang/import)');
    l_first := nvl(l_first, c_workspace);
    for s in (select schema from apex_workspace_schemas where workspace_id = l_ws_id order by schema) loop
        line('             assigned schema: ' || s.schema);
    end loop;
    l_n := cnt('select count(*) from apex_workspace_schemas where workspace_id = ' || nvl(l_ws_id, -1)
               || ' and schema = :s', c_target);
    result(l_n > 0, c_target || ' is assigned to the workspace',
           'Administration Services > Manage Workspaces > Manage Workspace to Schema Assignments > Add ('
           || c_workspace || ' / ' || c_target || '), or apex/db/admin/create-xxfusion-schema.sql');

    head('ORDS (REST-enabled schemas and proxy connections)');
    for s in (select column_value schema from table(sys.odcivarchar2list(l_first, c_target))) loop
        l_n := cnt('select count(*) from ords_metadata.ords_schemas where parsing_schema = :s and status = ''ENABLED''',
                   s.schema);
        if l_n is not null then
            result(l_n > 0, rpad(s.schema, 18) || 'REST-enabled',
                   'connected as ' || s.schema || ': exec ords.enable_schema;');
        end if;
        select count(*) into l_n from dba_proxies where proxy = 'ORDS_PUBLIC_USER' and client = s.schema;
        result(l_n > 0, rpad(s.schema, 18) || 'ORDS_PUBLIC_USER may connect through it',
               'alter user ' || lower(s.schema) || ' grant connect through ords_public_user;');
    end loop;

    head('The ORDS import check (the cause of "Not allowed to install in workspace ... or schema ' || c_target || '")');
    line('  ORDS runs, connected as ' || l_first || ':');
    line('    select count(*) from apex_workspace_schemas where schema = ''' || c_target
         || ''' and workspace_id = ' || nvl(to_char(l_ws_id), '?'));
    line('  Outside an APEX session that view shows ' || l_first || ' only its own row, unless ' || l_first
         || ' has an APEX administrator role.');
    if l_first = c_target then
        result(true, 'the first schema is ' || c_target || ' itself: the check passes');
    else
        result(has_role(l_first, 'APEX_ADMINISTRATOR_READ_ROLE') or has_role(l_first, 'APEX_ADMINISTRATOR_ROLE'),
               l_first || ' has APEX_ADMINISTRATOR_READ_ROLE (or APEX_ADMINISTRATOR_ROLE)',
               'grant apex_administrator_read_role to ' || lower(l_first) || ';');
        for r in (select granted_role, default_role from dba_role_privs
                   where grantee = l_first and granted_role like 'APEX%') loop
            line('             ' || l_first || ' role: ' || r.granted_role || ' (default ' || r.default_role || ')');
        end loop;
    end if;

    head('Applications of the workspace by parsing schema');
    for a in (select owner, count(*) n, listagg(application_id || ' ' || alias, ', ') within group (order by application_id) apps
                from apex_applications where workspace = c_workspace group by owner order by owner) loop
        line('  ' || rpad(a.owner, 18) || a.n || ': ' || substr(a.apps, 1, 150));
    end loop;

    head('Privileges ' || c_target || ' needs for COMMON (checked again by COMMON script 00a)');
    for p in (select column_value priv from table(sys.odcivarchar2list(
                  'CREATE SESSION', 'CREATE TABLE', 'CREATE VIEW', 'CREATE SEQUENCE', 'CREATE PROCEDURE',
                  'CREATE TRIGGER', 'CREATE TYPE', 'CREATE SYNONYM', 'CREATE JOB'))) loop
        select count(*) into l_n from dba_sys_privs where grantee = c_target and privilege = p.priv;
        if l_n = 0 then
            select count(*) into l_n from dba_sys_privs
             where privilege = p.priv
               and grantee in (select granted_role from dba_role_privs
                                start with grantee = c_target connect by nocycle prior granted_role = grantee);
        end if;
        result(l_n > 0, rpad(p.priv, 18), 'grant ' || lower(p.priv) || ' to ' || lower(c_target) || ';');
    end loop;
    select count(*) into l_n from dba_ts_quotas where username = c_target;
    select l_n + count(*) into l_n from dba_sys_privs where grantee = c_target and privilege = 'UNLIMITED TABLESPACE';
    result(l_n > 0, 'tablespace quota', 'alter user ' || lower(c_target) || ' quota unlimited on data;');

    head('Result');
    if l_problems = 0 then
        line('  No difference found: App Builder > Import with Parsing Schema = ' || c_target || ' should work.');
        line('  Test it with XXFTEST-Application-APEXlang_1.zip (application 301, patch 102).');
    else
        line('  ' || l_problems || ' difference(s) found. Run the fix statements above as ADMIN, then run this script again.');
    end if;
end;
/

spool off
set feedback on
