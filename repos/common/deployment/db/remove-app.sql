--------------------------------------------------------------------------------
-- Steps 4.1 / 5.1 (part 1), run as the pipeline user: removes the APEX application when it is installed.
-- Substitution variable: app_id.
--------------------------------------------------------------------------------
set define on verify off feedback off serveroutput on
declare
    l_n pls_integer;
begin
    select count(*) into l_n from apex_applications where application_id = &app_id;
    if l_n > 0 then
        apex_instance_admin.remove_application(p_application_id => &app_id);
        commit;
        dbms_output.put_line('removed application &app_id');
    else
        dbms_output.put_line('application &app_id is not installed');
    end if;
end;
/
