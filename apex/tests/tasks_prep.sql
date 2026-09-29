-- Creates one RFI_RESPONSE task for REQ1 (raised by OFFICER1) and one CONFIG_CHANGE task (made by MGR1)
-- for tasks_ui.py. Run after workflow_test.sql.
set serveroutput on feedback off
declare
    l_app number; l_party number; l_rfi number; l_token varchar2(200); l_rule number; l_cat varchar2(30);
begin
    select application_id into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'KYC';
    select min(party_id) into l_party from xxcmp_parties;
    select min(lookup_code) into l_cat from xxfnd_lookup_values where lookup_type = 'RFI_CATEGORY';
    -- cancel open tasks of earlier test runs (ADMIN is business administrator)
    apex_session.create_session(l_app, 1, 'ADMIN');
    for t in (select task_id from apex_tasks where state_code in ('UNASSIGNED','ASSIGNED') and task_def_static_id = 'CONFIG_CHANGE') loop
        begin
            apex_human_task.cancel_task(t.task_id);
        exception when others then dbms_output.put_line('could not cancel ' || t.task_id || ': ' || sqlerrm);
        end;
    end loop;
    commit;
    apex_session.delete_session;
    apex_session.create_session(l_app, 1, 'OFFICER1');
    xxcmp_kyc_pkg.create_rfi('XXCMP_PARTIES', to_char(l_party), 'REQUESTING_DEPARTMENT', l_cat,
                             'UI test: please confirm the registered address.', 'Y', trunc(sysdate) + 5,
                             p_recipient_user_name => 'REQ1', p_rfi_id => l_rfi, p_token => l_token);
    commit;
    apex_session.delete_session;
    apex_session.create_session(l_app, 1, 'MGR1');
    delete from xxcmp_attachment_rules where entity_name = 'XXCMP_PARTIES' and jurisdiction = 'QB';
    insert into xxcmp_attachment_rules (entity_name, category_code, jurisdiction, mandatory_flag, priority)
    values ('XXCMP_PARTIES', (select min(category_code) from xxfnd_document_categories), 'QB', 'Y', 50)
    returning attachment_rule_id into l_rule;
    xxfnd_config_approval_pkg.request('XXCMP_ATTACHMENT_RULES', to_char(l_rule));
    commit;
    apex_session.delete_session;
    dbms_output.put_line('rfi=' || l_rfi || ' rule=' || l_rule);
end;
/
exit
