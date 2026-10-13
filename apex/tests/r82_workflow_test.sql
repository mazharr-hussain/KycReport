-- Release 82 checks (run as XXFUSION): C5 Workflow - one package per component (XXFND_WORKFLOW_PKG = runtime + switches
-- + tasks; XXFND_NOTIFY_PKG = notifications + communications), the Process Catalogue (RFI process, participants
-- type), RFI default recipient and language, the shared task decision, the questions-and-answers history, plain-text
-- wording with the XXFND_STANDARD layout, My Tasks and the Workflow Monitor. Changes are rolled back.
set serveroutput on feedback off
declare
    l_n     number;
    l_n2    number;
    l_v     varchar2(4000);
    l_c     clob;
    l_id    number;
    l_token varchar2(200);
    l_cat   varchar2(30);
    procedure check_(p_ok in boolean, p_text in varchar2) is
    begin
        dbms_output.put_line(case when p_ok then 'PASS ' else 'FAIL ' end || p_text);
    end check_;
    procedure expect_error(p_code in number, p_text in varchar2, p_block in varchar2) is
    begin
        execute immediate p_block;
        check_(false, p_text || ' (no error)');
    exception
        when others then
            check_(sqlcode = p_code, p_text || ' (' || sqlcode || ')');
    end expect_error;
begin
    -- merged packages and the unused view are gone; nothing invalid
    select count(*) into l_n from user_objects
     where object_name in ('XXFND_TASK_PKG', 'XXFND_WORKFLOW_SWITCH_PKG', 'XXFND_COMMUNICATION_PKG', 'XXFND_PENDING_APPROVALS_V');
    check_(l_n = 0, 'merged packages and XXFND_PENDING_APPROVALS_V dropped (' || l_n || ' left)');
    select count(*) into l_n from xxfnd_dropped_objects
     where object_name in ('XXFND_TASK_PKG', 'XXFND_WORKFLOW_SWITCH_PKG', 'XXFND_COMMUNICATION_PKG', 'XXFND_PENDING_APPROVALS_V');
    select count(*) into l_n2 from xxfnd_dropped_objects where object_name = 'XXFND_SECURITY_PKG';
    check_((l_n2 > 0 and l_n >= 4) or (l_n2 = 0 and l_n = 0), 'their DDL is recorded in XXFND_DROPPED_OBJECTS when they existed (' || l_n || ')');
    select count(*) into l_n from user_objects where status <> 'VALID';
    check_(l_n = 0, 'no invalid object (' || l_n || ')');
    select count(*) into l_n from user_procedures
     where object_name = 'XXFND_WORKFLOW_PKG'
       and procedure_name in ('START_PROCESS', 'WORKFLOW_ENABLED', 'EMAIL_ENABLED', 'SYNC_PROCESSES', 'CREATE_TASK',
                              'BUSINESS_ADMINS', 'PROCESS_DEADLINES', 'SET_WORKSPACE_EMAIL', 'OPEN_TASK_COUNT',
                              'MONITOR_WORKFLOW', 'MONITOR_TASK');
    check_(l_n = 11, 'XXFND_WORKFLOW_PKG holds runtime, switches, tasks and monitor (' || l_n || ' of 11)');
    select count(*) into l_n from user_procedures
     where object_name = 'XXFND_NOTIFY_PKG'
       and procedure_name in ('SEND', 'SEND_TO_USERS', 'SEND_MESSAGE', 'SEND_EMAIL', 'RECORD_RECEIVED', 'RECORD_SENT',
                              'PREVIEW_SUBJECT', 'PREVIEW_MESSAGE', 'SEND_TEST');
    check_(l_n = 9, 'XXFND_NOTIFY_PKG holds notifications and communications (' || l_n || ' of 9)');

    -- Process Catalogue: the RFI process of every application, participants chosen by the user
    select count(*) into l_n from xxfnd_applications a
     where a.application_code <> 'COMMON'
       and not exists (select 1 from xxfnd_workflow_processes p
                        where p.application_code = a.application_code and p.process_code = 'RFI'
                          and p.participants_type = 'CHOSEN');
    check_(l_n = 0, 'every application has the RFI process (participants CHOSEN)');
    select count(*) into l_n from xxfnd_workflow_processes where participants_type not in ('RULE', 'CHOSEN');
    check_(l_n = 0, 'participants type is RULE or CHOSEN');
    select count(*) into l_n from xxfnd_approval_types where approval_type_code = 'CASE_RFI' and enabled_flag = 'Y';
    check_(l_n = 0, 'Approval Setup type CASE_RFI is disabled (or absent)');
    expect_error(-20161, 'workspace e-mail switch refused without the privilege',
                 q'~begin xxfnd_workflow_pkg.set_workspace_email('N'); end;~');

    -- RFI: the requester is the default recipient; an external recipient gets the chosen language
    select min(lookup_code) into l_cat from xxfnd_lookup_values where lookup_type = 'RFI_CATEGORY' and enabled_flag = 'Y';
    xxfnd_rfi_pkg.create_rfi(p_entity_name => 'XXFND_R82_TEST', p_pk1_value => 'R82', p_recipient_type => 'USER',
                             p_rfi_category => l_cat, p_description => 'R82 question', p_with_tasks => 'N',
                             p_requester => 'ADMIN', p_rfi_id => l_id, p_token => l_token);
    select recipient_user_name into l_v from xxfnd_rfis where rfi_id = l_id;
    check_(l_v = 'ADMIN', 'RFI recipient defaults to the requester');
    expect_error(-20509, 'RFI without recipient or requester refused',
                 q'~declare i number; t varchar2(200); begin xxfnd_rfi_pkg.create_rfi(p_entity_name => 'XXFND_R82_TEST', p_pk1_value => 'R82', p_recipient_type => 'USER', p_rfi_category => '~'
                 || l_cat || q'~', p_description => 'x', p_with_tasks => 'N', p_rfi_id => i, p_token => t); end;~');
    xxfnd_rfi_pkg.create_rfi(p_entity_name => 'XXFND_R82_TEST', p_pk1_value => 'R82', p_recipient_type => 'EXTERNAL',
                             p_rfi_category => l_cat, p_description => 'R82 external', p_recipient_email => 'a@example.com',
                             p_recipient_name => 'A', p_language => 'ar', p_rfi_id => l_id, p_token => l_token);
    select language_code into l_v from xxfnd_rfis where rfi_id = l_id;
    check_(l_v = 'ar' and l_token is not null, 'external RFI keeps its language and gets a one-time link');

    -- one questions-and-answers history
    select count(*) into l_n from xxfnd_qa_history_v where record_key = 'R82' and source_type = 'RFI_QUESTION';
    check_(l_n = 2, 'questions of the record are in XXFND_QA_HISTORY_V (' || l_n || ')');

    -- shared task decision
    expect_error(-20536, 'unknown task decision refused',
                 q'~declare r varchar2(1); begin r := xxfnd_approval_rule_pkg.decide_task(1, 'MAYBE'); end;~');

    -- notifications: plain-text wording, English when not translated, two events disabled
    select count(*) into l_n from xxfnd_notification_templates where message_text is null and body_html is not null;
    check_(l_n = 0, 'every wording has its plain-text message');
    select count(*) into l_n from xxfnd_notification_templates
     where template_code in ('RFI_RESPONDED', 'CONFIG_CHANGE_PENDING') and enabled_flag = 'Y';
    check_(l_n = 0, 'RFI_RESPONDED and CONFIG_CHANGE_PENDING disabled');
    select max(template_code) into l_v from xxfnd_notification_templates where template_code = 'TASK_ASSIGNED';
    if l_v is not null then
        check_(xxfnd_notify_pkg.preview_subject('TASK_ASSIGNED', 'en') is not null, 'preview: English subject');
        l_c := xxfnd_notify_pkg.preview_message('TASK_ASSIGNED', 'zz');
        check_(l_c is not null and not regexp_like(dbms_lob.substr(l_c, 4000, 1), '<[a-z]+[^>]*>', 'i'),
               'preview: an untranslated language falls back to English, without HTML');
        check_(xxfnd_notify_pkg.preview_subject('TASK_ASSIGNED', 'en', '{"TASK_SUBJECT":"R82 task"}') is not null,
               'preview: tokens replaced');
    else
        check_(false, 'template TASK_ASSIGNED exists');
    end if;
    check_(xxfnd_notify_pkg.user_language('NOBODY_R82') = 'en', 'unknown user reads English');

    -- My Tasks and the Workflow Monitor
    select count(*) into l_n from xxfnd_privileges where privilege_code in ('MY_TASKS.VIEW', 'MY_TASKS.MANAGE');
    check_(l_n = 2, 'My Tasks has View and Manage');
    select count(*) into l_n from xxfnd_feature_pages
     where app_alias = 'COMMON' and ((page_id = 40 and feature_code = 'MY_TASKS')
                                  or (page_id in (141, 142) and feature_code = 'WORKFLOW_MONITOR'));
    check_(l_n = 3, 'pages 40, 141 and 142 belong to My Tasks and Workflow Monitor');
    select count(*) into l_n from xxfnd_roles r
     where not exists (select 1 from xxfnd_role_privileges p where p.role_code = r.role_code and p.privilege_code = 'MY_TASKS.VIEW');
    check_(l_n = 0, 'every role may open My Tasks');
    expect_error(-20164, 'Workflow Monitor action refused without the privilege',
                 q'~begin xxfnd_workflow_pkg.monitor_workflow(1, 'SUSPEND'); end;~');
    rollback;
end;
/
