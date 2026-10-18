set serveroutput on size unlimited feedback off
-- test users (release 76: the shared test_users.sql)
@@test_users.sql
-- test data: a party and two RFIs addressed to different requesters (inserted outside APEX: no VPD filter)
declare l_party number; l_n pls_integer; l_rfi number; l_token varchar2(4000); l_cat varchar2(30);
begin
    xxfnd_util_pkg.set_install_mode(true);
    insert into xxcmp_parties (party_type, party_name, jurisdiction)
    values ('ORGANIZATION','VPD Test Co',(select min(lookup_code) from xxfnd_lookup_values where lookup_type='JURISDICTION'))
    returning party_id into l_party;
    -- a re-run keeps the RFIs of the first run. Release 93: created with COMMON's routine (no direct writes since
    -- COMMON 88), without workflow tasks
    select min(lookup_code) into l_cat from xxfnd_lookup_values where lookup_type = 'RFI_CATEGORY';
    for r in (select 'REQ1' usr from dual union all select 'REQ2' from dual) loop
        select count(*) into l_n from xxfnd_rfis where entity_name = 'XXCMP_PARTIES' and description = 'For ' || r.usr;
        if l_n = 0 then
            xxfnd_rfi_pkg.create_rfi('XXCMP_PARTIES', to_char(l_party), 'USER', l_cat, 'For ' || r.usr, 'Y',
                                     trunc(sysdate) + 7, p_recipient_user_name => r.usr, p_application_code => 'KYC', p_with_tasks => 'N', p_rfi_id => l_rfi, p_token => l_token);
        end if;
    end loop;
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
        select count(*), listagg(description, ',') into l_r, l_desc from xxfnd_rfis
         where entity_name = 'XXCMP_PARTIES' and description in ('For REQ1', 'For REQ2');
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
