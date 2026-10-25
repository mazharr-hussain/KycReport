--------------------------------------------------------------------------------
-- ADMIN SCRIPT: remove the COMMON application and every object it created in XXFUSION.
--   Run as ADMIN in Database Actions > SQL with Run Script (F5). Used to start COMMON again from a clean schema.
--   Other objects in XXFUSION (for example the Fusion web-service data) are kept: only XXFND_ objects, the
--   generated flexfield views (*_DFV), the XXFND_ scheduler jobs and the policies on XXFND_ tables are removed.
--   1. PREVIEW - lists what is removed and what is kept. Changes nothing.
--   2. CHECK   - stops with ORA-20905 and changes nothing while another schema still depends on these objects
--               (synonyms or foreign keys to XXFUSION.XXFND_: an application whose shared data was already moved).
--   3. CLEAN   - deletes the COMMON application, then drops the objects.
-- Safe to re-run: on a clean XXFUSION it removes nothing.
--------------------------------------------------------------------------------
set serveroutput on

prompt ==== 1. PREVIEW: COMMON application(s)
select workspace, application_id, application_name, alias
  from apex_applications
 where alias = 'COMMON';

prompt ==== 1. PREVIEW: objects removed from XXFUSION
select object_type, count(*) objects
  from dba_objects
 where owner = 'XXFUSION'
   and (object_name like 'XXFND\_%' escape '\' or (object_type = 'VIEW' and object_name like '%\_DFV' escape '\'))
 group by object_type
 order by 1;

prompt ==== 1. PREVIEW: objects kept in XXFUSION
select object_type, object_name
  from dba_objects
 where owner = 'XXFUSION'
   and not (object_name like 'XXFND\_%' escape '\' or (object_type = 'VIEW' and object_name like '%\_DFV' escape '\'))
   and object_type not in ('INDEX', 'LOB', 'TRIGGER', 'INDEX PARTITION', 'TABLE PARTITION')
   and object_name not like 'ISEQ$$%'   -- identity sequences go with their tables
 order by 1, 2;

prompt ==== 2. CHECK and 3. CLEAN
declare
    c_owner    constant varchar2(128) := 'XXFUSION';
    l_problems varchar2(4000);
    l_n        pls_integer := 0;

    function removable(p_type in varchar2, p_name in varchar2) return boolean is
    begin
        return p_name like 'XXFND\_%' escape '\' or (p_type = 'VIEW' and p_name like '%\_DFV' escape '\');
    end removable;
begin
    -- 2. CHECK: nothing outside XXFUSION may depend on the objects
    for s in (select owner, synonym_name from dba_synonyms
               where table_owner = c_owner and table_name like 'XXFND\_%' escape '\' and owner <> c_owner
               order by 1, 2
               fetch first 20 rows only) loop
        l_problems := l_problems || chr(10) || '- synonym ' || s.owner || '.' || s.synonym_name;
    end loop;
    for f in (select c.owner, c.table_name, c.constraint_name from dba_constraints c
                join dba_constraints r on r.owner = c.r_owner and r.constraint_name = c.r_constraint_name
               where c.constraint_type = 'R' and r.owner = c_owner and c.owner <> c_owner
                 and r.table_name like 'XXFND\_%' escape '\'
               order by 1, 2
               fetch first 20 rows only) loop
        l_problems := l_problems || chr(10) || '- foreign key ' || f.owner || '.' || f.table_name || '.' || f.constraint_name;
    end loop;
    if l_problems is not null then
        raise_application_error(-20905,
            'STOPPED - other schemas use the COMMON objects in ' || c_owner || ' (their shared data was already moved). '
            || 'Nothing was changed.' || l_problems);
    end if;

    -- 3. CLEAN: the COMMON application
    for a in (select workspace, application_id from apex_applications where alias = 'COMMON') loop
        apex_application_install.set_workspace(a.workspace);
        apex_application_install.remove_application(a.application_id);
        dbms_output.put_line('Removed application ' || a.application_id || ' (workspace ' || a.workspace || ')');
    end loop;
    commit;

    -- scheduler jobs
    for j in (select job_name from dba_scheduler_jobs where owner = c_owner and job_name like 'XXFND\_%' escape '\') loop
        dbms_scheduler.drop_job(c_owner || '.' || j.job_name, force => true);
        l_n := l_n + 1;
    end loop;

    -- data security policies on XXFUSION tables
    for p in (select object_name, policy_name from dba_policies
               where object_owner = c_owner and object_name like 'XXFND\_%' escape '\') loop
        dbms_rls.drop_policy(object_schema => c_owner, object_name => p.object_name, policy_name => p.policy_name);
        l_n := l_n + 1;
    end loop;

    -- objects: views first, code, tables, sequences, types last
    for o in (select object_type, object_name from dba_objects
               where owner = c_owner
                 and object_type in ('VIEW', 'MATERIALIZED VIEW', 'PACKAGE', 'PROCEDURE', 'FUNCTION', 'TABLE',
                                     'SEQUENCE', 'TYPE', 'SYNONYM')
               order by decode(object_type, 'MATERIALIZED VIEW', 0, 'VIEW', 1, 'SYNONYM', 1, 'PACKAGE', 2,
                               'PROCEDURE', 2, 'FUNCTION', 2, 'TABLE', 3, 'SEQUENCE', 4, 'TYPE', 5), object_name) loop
        continue when not removable(o.object_type, o.object_name);
        begin
            execute immediate 'drop ' || o.object_type || ' ' || c_owner || '.' || o.object_name
                || case o.object_type when 'TABLE' then ' cascade constraints purge' when 'TYPE' then ' force' end;
            l_n := l_n + 1;
        exception
            when others then
                -- already gone with its parent (for example a table dropped with cascade)
                if sqlcode not in (-942, -4043, -2289) then
                    raise;
                end if;
        end;
    end loop;
    dbms_output.put_line('Done: ' || l_n || ' objects, jobs and policies removed from ' || c_owner || '.');
end;
/

prompt ==== Remaining COMMON objects in XXFUSION (expected: none)
select object_type, object_name
  from dba_objects
 where owner = 'XXFUSION'
   and (object_name like 'XXFND\_%' escape '\' or (object_type = 'VIEW' and object_name like '%\_DFV' escape '\'))
 order by 1, 2;
