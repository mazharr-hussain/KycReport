--------------------------------------------------------------------------------
-- Steps 5.1 / 6.1 (part 2), validation database only (I-077): removes the APPLICATION's own objects from the
-- CURRENT user (the application schema, proxy) - never the schema and never another application's objects in it.
-- db/run.sh writes the head of this block: "declare ... l_list t_list := t_list('<TYPE> <NAME>', ...);" (the list
-- from db/app_objects.py and XXCI_APP_OBJECTS), then appends this file. Order: VPD policies on the listed tables,
-- scheduler jobs, then the objects (materialized views, tables, views, the rest, types last). The run fails if a
-- listed object is still there.
--------------------------------------------------------------------------------
    l_left pls_integer := 0;
    function listed(p_type varchar2, p_name varchar2) return boolean is
    begin
        for i in 1 .. l_list.count loop
            if l_list(i) = replace(p_type, ' ', '_') || ' ' || p_name then return true; end if;
        end loop;
        return false;
    end listed;
    procedure run(p varchar2) is
    begin
        execute immediate p;
    exception
        when others then
            dbms_output.put_line('skipped: ' || p || ' - ' || sqlerrm);  -- already gone through a cascade
    end run;
begin
    for p in (select object_name, policy_name from user_policies) loop
        if listed('TABLE', p.object_name) or listed('VIEW', p.object_name) then
            dbms_rls.drop_policy(user, p.object_name, p.policy_name);
        end if;
    end loop;
    for j in (select job_name from user_scheduler_jobs) loop
        if listed('JOB', j.job_name) then dbms_scheduler.drop_job(j.job_name, force => true); end if;
    end loop;
    for o in (select object_name, object_type from user_objects
               where object_type in ('MATERIALIZED VIEW', 'TABLE', 'VIEW', 'SEQUENCE', 'SYNONYM', 'PACKAGE',
                                     'PROCEDURE', 'FUNCTION', 'TYPE', 'TRIGGER')
               order by decode(object_type, 'MATERIALIZED VIEW', 1, 'TABLE', 2, 'VIEW', 3, 'TYPE', 9, 5)) loop
        if listed(o.object_type, o.object_name) then
            run('drop ' || o.object_type || ' "' || o.object_name || '"'
                || case o.object_type when 'TABLE' then ' cascade constraints purge' when 'TYPE' then ' force' end);
        end if;
    end loop;
    for o in (select object_name, object_type from user_objects
               where object_type in ('MATERIALIZED VIEW', 'TABLE', 'VIEW', 'SEQUENCE', 'SYNONYM', 'PACKAGE',
                                     'PROCEDURE', 'FUNCTION', 'TYPE', 'TRIGGER')) loop
        if listed(o.object_type, o.object_name) then
            l_left := l_left + 1;
            dbms_output.put_line('left: ' || o.object_type || ' ' || o.object_name);
        end if;
    end loop;
    if l_left > 0 then
        raise_application_error(-20002, l_left || ' application object(s) could not be removed - the install would not be fresh.');
    end if;
    dbms_output.put_line('the application''s objects are removed from ' || user || ' (other objects kept)');
end;
/
