set serveroutput on size unlimited feedback off
-- test users (employees + role grants + APEX accounts)
declare
    procedure u(p_user varchar2, p_role varchar2) is
        l_id number;
    begin
        xxfnd_util_pkg.set_install_mode(true);
        begin select employee_id into l_id from xxfnd_employees where user_name = p_user;
        exception when no_data_found then
            insert into xxfnd_employees (source_type, user_name, full_name, email_address)
            values ('LOCAL', p_user, initcap(p_user), lower(p_user)||'@example.com') returning employee_id into l_id;
        end;
        merge into xxfnd_user_roles t using (select l_id e, p_role r from dual) s
           on (t.employee_id = s.e and t.role_code = s.r and t.end_date_active is null)
         when not matched then insert (employee_id, role_code) values (s.e, s.r);
        xxfnd_util_pkg.set_install_mode(false);
        apex_util.set_workspace('XXCUS');
        if apex_util.find_security_group_id('XXCUS') is not null and apex_util.get_user_id(p_user) is null then
            apex_util.create_user(p_user_name => p_user, p_web_password => 'KycTest#2026', p_change_password_on_first_use => 'N');
        end if;
    end;
begin
    u('REQ1','REQUESTER'); u('REQ2','REQUESTER'); u('OFFICER1','COMPLIANCE_OFFICER');
    commit;
end;
/
-- test data: a party and two RFIs addressed to different requesters (inserted outside APEX: no VPD filter)
declare l_party number;
begin
    xxfnd_util_pkg.set_install_mode(true);
    insert into xxcmp_parties (party_type, party_name, jurisdiction)
    values ('ORGANIZATION','VPD Test Co',(select min(lookup_code) from xxfnd_lookup_values where lookup_type='JURISDICTION'))
    returning party_id into l_party;
    -- a re-run keeps the RFIs of the first run
    insert into xxfnd_rfis (application_code, entity_name, pk1_value, rfi_category, recipient_type, recipient_user_name, description, rfi_status, due_date, continue_other_work_flag, rfi_number)
    select 'KYC', 'XXCMP_PARTIES', to_char(l_party), (select min(lookup_code) from xxfnd_lookup_values where lookup_type='RFI_CATEGORY'),
            'USER', 'REQ1', 'For REQ1', 'WAITING_FOR_INFORMATION', trunc(sysdate)+7, 'Y', 'RFI-VPD-1' from dual
     where not exists (select 1 from xxfnd_rfis where rfi_number = 'RFI-VPD-1');
    insert into xxfnd_rfis (application_code, entity_name, pk1_value, rfi_category, recipient_type, recipient_user_name, description, rfi_status, due_date, continue_other_work_flag, rfi_number)
    select 'KYC', 'XXCMP_PARTIES', to_char(l_party), (select min(lookup_code) from xxfnd_lookup_values where lookup_type='RFI_CATEGORY'),
            'USER', 'REQ2', 'For REQ2', 'WAITING_FOR_INFORMATION', trunc(sysdate)+7, 'Y', 'RFI-VPD-2' from dual
     where not exists (select 1 from xxfnd_rfis where rfi_number = 'RFI-VPD-2');
    xxfnd_util_pkg.set_install_mode(false);
    commit;
end;
/
-- checks inside real APEX sessions
declare
    procedure chk(p_user varchar2) is
        l_p number; l_r number; l_desc varchar2(4000);
        function b(x boolean) return varchar2 is begin return case when x then 'Y' else 'N' end; end;
    begin
        apex_session.create_session(p_app_id => 134, p_page_id => 1, p_username => p_user);
        select count(*) into l_p from xxcmp_parties;
        select count(*), listagg(description, ',') into l_r, l_desc from xxfnd_rfis where rfi_number like 'RFI-VPD-%';
        dbms_output.put_line(rpad(p_user,9)||' parties='||l_p||' rfis='||l_r||' ['||l_desc||']'
            ||' p20.VIEW='||b(xxfnd_privilege_pkg.has_page_privilege(20,'VIEW'))
            ||' p21.CREATE='||b(xxfnd_privilege_pkg.has_page_request_privilege(21,'CREATE'))
            ||' p101.VIEW='||b(xxfnd_privilege_pkg.has_page_privilege(101,'VIEW'))
            ||' p30.VIEW='||b(xxfnd_privilege_pkg.has_page_privilege(30,'VIEW'))
            ||' admin='||b(xxfnd_privilege_pkg.has_any_admin_privilege)
            ||' any='||b(xxfnd_privilege_pkg.has_any_privilege));
        apex_session.delete_session;
    end;
begin
    chk('ADMIN'); chk('OFFICER1'); chk('REQ1'); chk('REQ2'); chk('NOBODY');
end;
/
-- no APEX session (install / jobs): unfiltered
select count(*) rfis_without_apex_session from xxfnd_rfis;
exit
