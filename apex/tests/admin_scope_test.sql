-- COMMON application scope (release 61, 16i): inside COMMON a setup screen sees its application's rows and the shared
-- rows, changes only its application's rows, and new rows belong to it. Run as XXFUSION; rolls back.
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
    -- outside APEX: no restriction
    insert into xxfnd_lookup_types (lookup_type, meaning, application_code) values ('ZZ_SHARED', 'Shared', null);
    insert into xxfnd_lookup_types (lookup_type, meaning, application_code) values ('ZZ_KYC', 'Kyc', 'KYC');
    insert into xxfnd_lookup_types (lookup_type, meaning, application_code) values ('ZZ_OTHER', 'Other', 'OTHER');
    apex_session.create_session(p_app_id => 135, p_page_id => 100, p_username => 'ADMIN');
    apex_util.set_session_state('G_ADMIN_APP', 'KYC');
    select count(*) into l_n from xxfnd_lookup_types where lookup_type like 'ZZ\_%' escape '\';
    ok(l_n = 2, 'scope KYC sees its rows and the shared rows (' || l_n || ' of 3)');
    update xxfnd_lookup_types set description = 'x' where lookup_type like 'ZZ\_%' escape '\';
    ok(sql%rowcount = 1, 'scope KYC changes only its own row (' || sql%rowcount || ')');
    insert into xxfnd_lookup_types (lookup_type, meaning) values ('ZZ_NEW', 'New');
    for r in (select application_code from xxfnd_lookup_types where lookup_type = 'ZZ_NEW') loop
        ok(r.application_code = 'KYC', 'a new row belongs to the application in scope (' || r.application_code || ')');
    end loop;
    apex_util.set_session_state('G_ADMIN_APP', 'COMMON');
    update xxfnd_lookup_types set description = 'y' where lookup_type like 'ZZ\_%' escape '\';
    ok(sql%rowcount = 1, 'scope COMMON changes the shared rows only (' || sql%rowcount || ')');
    apex_session.delete_session;
    rollback;
exception
    when others then
        dbms_output.put_line('FAIL ' || sqlerrm);
        rollback;
end;
/
