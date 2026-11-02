--------------------------------------------------------------------------------
-- Steps 6.1 / 7.1 (part 2), validation database only (#192): removes every object of the CURRENT user, so the next
-- install is a fresh one. Run by db/run.sh as the application schema (proxy). Never run it on dev or production.
-- An object already dropped through a cascade is reported and skipped; the run fails if anything is left.
--------------------------------------------------------------------------------
set define off verify off feedback off serveroutput on
declare
    l_left pls_integer;
    procedure run(p varchar2) is
    begin
        execute immediate p;
    exception
        when others then
            dbms_output.put_line('skipped: ' || p || ' - ' || sqlerrm);  -- already gone through a cascade
    end run;
begin
    for p in (select object_name, policy_name from user_policies) loop
        dbms_rls.drop_policy(user, p.object_name, p.policy_name);
    end loop;
    for j in (select job_name from user_scheduler_jobs) loop
        dbms_scheduler.drop_job(j.job_name, force => true);
    end loop;
    for o in (select object_name, object_type from user_objects
               where object_type in ('MATERIALIZED VIEW', 'TABLE', 'VIEW', 'SEQUENCE', 'SYNONYM', 'PACKAGE',
                                     'PROCEDURE', 'FUNCTION', 'TYPE', 'TRIGGER')
                 and object_name not like 'BIN$%' and object_name not like 'SYS\_%' escape '\'
               order by decode(object_type, 'MATERIALIZED VIEW', 1, 'TABLE', 2, 'VIEW', 3, 'TYPE', 9, 5)) loop
        run('drop ' || o.object_type || ' "' || o.object_name || '"'
            || case o.object_type when 'TABLE' then ' cascade constraints purge' when 'TYPE' then ' force' end);
    end loop;
    run('purge recyclebin');
    select count(*) into l_left from user_objects
     where object_type in ('MATERIALIZED VIEW', 'TABLE', 'VIEW', 'SEQUENCE', 'SYNONYM', 'PACKAGE', 'PROCEDURE',
                           'FUNCTION', 'TYPE', 'TRIGGER')
       and object_name not like 'BIN$%' and object_name not like 'SYS\_%' escape '\';
    if l_left > 0 then
        raise_application_error(-20002, l_left || ' object(s) could not be removed - the install would not be fresh.');
    end if;
    dbms_output.put_line('schema ' || user || ' is empty');
end;
/
