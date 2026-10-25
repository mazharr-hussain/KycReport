-- Release 72: the common functions IT switches per application (COMMON Applications) are honoured in KYC.
-- Run as XXCUS; restores the switches.
set serveroutput on
begin apex_util.set_workspace('XXCUS'); end;
/
declare
    l_mail_before number;
    l_mail_after  number;
    procedure ok(p_ok boolean, p_msg varchar2) is
    begin
        dbms_output.put_line(case when p_ok then 'PASS ' else 'FAIL ' end || p_msg);
    end;
    procedure switch(p_feature varchar2, p_flag varchar2) is
    begin
        update xxfnd_application_functions set enabled_flag = p_flag
         where application_code = 'KYC' and feature_code = p_feature;
        commit;
    end;
begin
    ok(xxfnd_app_function_pkg.is_enabled('ATTACHMENTS') = 'Y', 'outside APEX: every function is available');
    apex_session.create_session(p_app_id => 134, p_page_id => 1, p_username => 'ADMIN');
    ok(xxfnd_app_function_pkg.is_enabled('ATTACHMENTS') = 'Y', 'KYC: attachments on');
    switch('ATTACHMENTS', 'N');
    ok(xxfnd_app_function_pkg.is_enabled('ATTACHMENTS') = 'N', 'KYC: attachments switched off');
    ok(xxfnd_attach_pkg.block_permission('KYC', 203, 'request_attachments', 'XXCMP_REQUESTS', 'INSERT') = 'N',
       'attachments off: no attachment can be added');
    switch('ATTACHMENTS', 'Y');
    switch('FLEXFIELDS', 'N');
    ok(xxfnd_dff_pkg.render('XXCMP_PARTIES', null) is null, 'flexfields off: no flexfield region');
    switch('FLEXFIELDS', 'Y');
    select count(*) into l_mail_before from apex_mail_queue;
    xxfnd_notify_pkg.send('TASK_ASSIGNED', 'test@example.com', null);
    select count(*) into l_mail_after from apex_mail_queue;
    ok(l_mail_after = l_mail_before + 1, 'notifications on: the e-mail is queued');
    switch('NOTIFICATIONS', 'N');
    select count(*) into l_mail_before from apex_mail_queue;
    xxfnd_notify_pkg.send('TASK_ASSIGNED', 'test@example.com', null);
    select count(*) into l_mail_after from apex_mail_queue;
    ok(l_mail_after = l_mail_before, 'notifications off: nothing is sent');
    switch('NOTIFICATIONS', 'Y');
    apex_session.delete_session;
exception
    when others then
        dbms_output.put_line('FAIL ' || sqlerrm);
        update xxfnd_application_functions set enabled_flag = 'Y' where application_code = 'KYC';
        commit;
end;
/
