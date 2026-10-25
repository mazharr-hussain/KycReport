-- COMMON application scope (16i; release 71): COMMON is for IT only; the application selector is a view filter
-- (ALL = every row; one application = its rows and the shared rows; new rows belong to it). Run as XXFUSION; rolls back.
set serveroutput on
begin apex_util.set_workspace('XXCUS'); end;
/
declare
    l_n number;
    procedure ok(p_ok boolean, p_msg varchar2) is
    begin
        dbms_output.put_line(case when p_ok then 'PASS ' else 'FAIL ' end || p_msg);
    end;
begin
    -- outside APEX: no restriction (APEX sessions commit, so the test rows are removed explicitly)
    delete from xxfnd_lookup_types where lookup_type like 'ZZ\_%' escape '\';
    insert into xxfnd_lookup_types (lookup_type, meaning, application_code) values ('ZZ_SHARED', 'Shared', null);
    insert into xxfnd_lookup_types (lookup_type, meaning, application_code) values ('ZZ_KYC', 'Kyc', 'KYC');
    insert into xxfnd_lookup_types (lookup_type, meaning, application_code) values ('ZZ_OTHER', 'Other', 'OTHER');
    apex_session.create_session(p_app_id => 135, p_page_id => 100, p_username => 'ADMIN');
    -- release 71: COMMON is for IT (Common Administrator); the application is a view filter (ALL = everything)
    apex_util.set_session_state('G_ADMIN_APP', 'ALL');
    select count(*) into l_n from xxfnd_lookup_types where lookup_type like 'ZZ\_%' escape '\';
    ok(l_n = 3, 'IT, all applications: every row (' || l_n || ' of 3)');
    apex_util.set_session_state('G_ADMIN_APP', 'KYC');
    select count(*) into l_n from xxfnd_lookup_types where lookup_type like 'ZZ\_%' escape '\';
    ok(l_n = 2, 'IT, application KYC: its rows and the shared rows (' || l_n || ' of 3)');
    update xxfnd_lookup_types set description = 'x' where lookup_type like 'ZZ\_%' escape '\';
    ok(sql%rowcount = 2, 'IT, application KYC: changes what it sees (' || sql%rowcount || ')');
    insert into xxfnd_lookup_types (lookup_type, meaning) values ('ZZ_NEW', 'New');
    for r in (select application_code from xxfnd_lookup_types where lookup_type = 'ZZ_NEW') loop
        ok(r.application_code = 'KYC', 'a new row belongs to the application chosen (' || r.application_code || ')');
    end loop;
    apex_util.set_session_state('G_ADMIN_APP', 'ALL');
    insert into xxfnd_lookup_types (lookup_type, meaning) values ('ZZ_NEW2', 'New');
    for r in (select nvl(application_code, 'Shared') app from xxfnd_lookup_types where lookup_type = 'ZZ_NEW2') loop
        ok(r.app = 'Shared', 'all applications: a new row without an application is shared (' || r.app || ')');
    end loop;
    apex_session.delete_session;
    -- a user who is not IT sees nothing in COMMON
    apex_session.create_session(p_app_id => 135, p_page_id => 100, p_username => 'MGR1');
    apex_util.set_session_state('G_ADMIN_APP', 'ALL');
    select count(*) into l_n from xxfnd_lookup_types where lookup_type like 'ZZ\_%' escape '\';
    ok(l_n = 0, 'not IT: no rows in COMMON (' || l_n || ')');
    apex_session.delete_session;
    delete from xxfnd_lookup_types where lookup_type like 'ZZ\_%' escape '\';
    commit;
exception
    when others then
        dbms_output.put_line('FAIL ' || sqlerrm);
        rollback;
end;
/
