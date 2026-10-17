-- Releases 87 / 88 checks, part 3 of 3 (run as XXFUSION, after r87_app_test.sql): C9 - an application that registered
-- its setup is deleted with it (only business data blocks the delete). R86DEL is registered again by the next run.
set serveroutput on feedback off
declare
    l_n   number;
    l_txt varchar2(4000);
    procedure check_(p_ok in boolean, p_text in varchar2) is
    begin
        dbms_output.put_line(case when p_ok then 'PASS ' else 'FAIL ' end || p_text);
    end check_;
begin
    apex_util.set_workspace('XXCUS');
    xxfnd_application_pkg.set_enabled('R86DEL', 'N');
    l_txt := xxfnd_application_pkg.delete_blocker('R86DEL');
    check_(l_txt is null, 'the setup it registered does not block the delete (' || nvl(l_txt, '-') || ')');
    xxfnd_application_pkg.delete_application('R86DEL');
    commit;
    select count(*) into l_n from xxfnd_applications where application_code = 'R86DEL';
    check_(l_n = 0, 'the application is deleted');
    select (select count(*) from xxfnd_lookup_types where application_code = 'R86DEL')
         + (select count(*) from xxfnd_contact_sources where application_code = 'R86DEL')
         + (select count(*) from xxfnd_app_menu_entries where application_code = 'R86DEL')
         + (select count(*) from xxfnd_roles where application_code = 'R86DEL')
      into l_n from dual;
    check_(l_n = 0, 'with its lookups, contact sources, menu entries and roles (' || l_n || ')');
    select count(*) into l_n from xxfnd_lookup_values where lookup_type = 'R87_DEL_LT';
    check_(l_n = 0, 'and the values of its lookups');
end;
/
