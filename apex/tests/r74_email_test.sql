-- Release 74 R27 (KYC, run as XXCUS): e-mails with outside people kept with the record (COMMON XXFND_COMMUNICATIONS):
-- send (APEX mail queue), record a received reply, rules, the RFI e-mail to an outside person kept with its link masked,
-- data security. Everything is rolled back.
set serveroutput on size unlimited feedback off
declare
    l_app   number;
    l_case  number;
    l_id    number;
    l_in    number;
    l_n     number;
    l_txt   varchar2(4000);
    l_rfi   number;
    l_tok   varchar2(200);
    l_body  clob;
    l_cat   varchar2(30);
    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
begin
    select application_id into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'KYC';
    apex_session.create_session(l_app, 1, 'OFFICER1');
    apex_app_setting.set_value('MAIL_FROM', 'kyc@example.com');
    select max(case_id) into l_case from xxcmp_cases;

    ok('rules: an address is needed', xxfnd_communication_pkg.email_error('OUT', null, 'S', to_clob('B')) is not null);
    ok('rules: addresses are checked', xxfnd_communication_pkg.email_error('OUT', 'a@b.com, wrong', 'S', to_clob('B')) is not null);
    ok('rules: several valid addresses', xxfnd_communication_pkg.email_error('OUT', 'a@b.com, c@d.org', 'S', to_clob('B')) is null);

    l_id := xxfnd_communication_pkg.send_email('KYC', 'XXCMP_CASES', to_char(l_case), 'party@example.com',
                                               'Missing trade licence', to_clob('Please send the renewed licence.'));
    select status || '|' || direction || '|' || nvl2(mail_id, 'Q', '-') into l_txt from xxfnd_communications where communication_id = l_id;
    ok('sent and kept with the case: ' || l_txt, l_txt in ('SENT|OUT|Q', 'NOT_SENT|OUT|-'));
    l_in := xxfnd_communication_pkg.record_received('KYC', 'XXCMP_CASES', to_char(l_case), 'party@example.com',
                                                    'RE: Missing trade licence', to_clob('Attached.'), p_in_reply_to_id => l_id);
    select count(*) into l_n from xxfnd_communications
     where communication_id = l_in and direction = 'IN' and status = 'RECEIVED' and source = 'MANUAL' and in_reply_to_id = l_id;
    ok('reply recorded by hand, linked to the e-mail', l_n = 1);
    select count(*) into l_n from xxfnd_communications where entity_name = 'XXCMP_CASES' and pk1_value = to_char(l_case)
       and communication_id in (l_id, l_in);
    ok('both listed for the case', l_n = 2);

    -- the RFI e-mail to an outside person is kept, its one-time link masked
    select min(lookup_code) into l_cat from xxfnd_lookup_values where lookup_type = 'RFI_CATEGORY';
    xxfnd_rfi_pkg.create_rfi('XXCMP_CASES', to_char(l_case), 'EXTERNAL', l_cat,
                             'Bank statements for 3 months', 'Y', trunc(sysdate) + 7, p_recipient_name => 'Ext Person',
                             p_recipient_email => 'ext@example.com', p_application_code => 'KYC', p_rfi_id => l_rfi, p_token => l_tok);
    xxfnd_rfi_pkg.send_email(l_rfi, 'https://example.com/respond?t=' || l_tok);
    select body into l_body from xxfnd_communications where rfi_id = l_rfi fetch first 1 row only;
    ok('RFI e-mail kept with the record', l_body is not null);
    ok('its response link is masked (no token stored)', dbms_lob.instr(l_body, l_tok) = 0
       and dbms_lob.instr(l_body, '[secure response link]') > 0);

    -- data security: a requester does not see the e-mails
    apex_session.create_session(l_app, 1, 'REQ1');
    select count(*) into l_n from xxfnd_communications where communication_id in (l_id, l_in);
    ok('a requester does not see them', l_n = 0);
    rollback;
    apex_session.delete_session;
end;
/
exit
