set serveroutput on feedback off
declare
    l_party number; l_rfi number; l_tok varchar2(200); l_cnt number; l_contact number; l_cat varchar2(30);
begin
    select min(party_id) into l_party from xxcmp_parties;
    xxfnd_util_pkg.set_install_mode(true);
    insert into xxcmp_party_contacts (party_id, contact_name, email)
    values (l_party, 'Ext Person', 'ext@example.com')
    returning party_contact_id into l_contact;
    xxfnd_util_pkg.set_install_mode(false);
    select min(lookup_code) into l_cat from xxfnd_lookup_values where lookup_type='RFI_CATEGORY';
    apex_session.create_session(134, 1, 'OFFICER1');
    xxfnd_rfi_pkg.create_rfi('XXCMP_PARTIES', to_char(l_party), 'EXTERNAL',
        l_cat, 'x', 'Y', trunc(sysdate)+5, p_recipient_name => 'Ext Person', p_recipient_email => 'ext@example.com',
        p_recipient_reference => to_char(l_contact), p_application_code => 'KYC', p_rfi_id => l_rfi, p_token => l_tok);
    commit;
    apex_session.delete_session;
    -- the public page runs as nobody (release 89: COMMON's Provide Information page 50; KYC page 33 is gone)
    apex_session.create_session(xxfnd_application_pkg.apex_app_id('COMMON'), 50, 'nobody');
    begin
        l_cnt := xxfnd_rfi_pkg.respond_by_token('wrong-token', to_clob('no'));
    exception when others then dbms_output.put_line('bad token -> '||sqlerrm);
    end;
    l_rfi := xxfnd_rfi_pkg.respond_by_token(l_tok, to_clob('Here you go'));
    select count(*) into l_cnt from xxfnd_rfis;
    dbms_output.put_line('nobody responded to rfi '||l_rfi||'; rows visible to nobody afterwards = '||l_cnt);
    commit;
    apex_session.delete_session;
    select count(*) into l_cnt from xxfnd_rfis where rfi_id = l_rfi and responded_date is not null and response_token_hash is null;
    dbms_output.put_line('stored response ok = '||l_cnt);
end;
/
exit
