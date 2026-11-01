--------------------------------------------------------------------------------
-- Validation database only (#192): removes every object of the CURRENT user, so the next install is a fresh one.
-- Run by .github/workflows/db-validate.yml as XXCUS first, then as XXFUSION (KYC objects depend on COMMON).
-- Never run it on a dev or production database.
--------------------------------------------------------------------------------
declare
    procedure run(p varchar2) is
    begin
        execute immediate p;
    exception when others then
        dbms_output.put_line('skipped: ' || p || ' - ' || sqlerrm);  -- already gone through a cascade
    end;
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
                 and object_name not like 'BIN$%' and object_name not like 'SYS_%'
               order by decode(object_type, 'MATERIALIZED VIEW', 1, 'TABLE', 2, 'VIEW', 3, 'TYPE', 9, 5)) loop
        run('drop ' || o.object_type || ' "' || o.object_name || '"'
            || case o.object_type when 'TABLE' then ' cascade constraints purge' when 'TYPE' then ' force' end);
    end loop;
    run('purge recyclebin');
end;
/
