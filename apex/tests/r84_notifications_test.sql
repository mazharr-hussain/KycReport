-- Release 84 checks (run as XXFUSION): workflow processes and notifications driven by data.
--   - RFI and CONFIG_CHANGE are APEX workflows of COMMON; the RFI loops (answer, review, ask again), waits for an
--     outside person's answer (one-time link, public page) and the configuration change is approved by a second person.
--   - Notifications come from data: events, rules, recipient queries, channels (in the application, e-mail, push,
--     Fusion off), wording per language, link from the event; nothing hardcoded in the packages.
-- The APEX workflow engine runs the activities in the background after each commit, so this test commits and waits.
-- Its rows are kept (entity R84_TEST, the purpose EMAIL_SYNC change): nothing is deleted.
set serveroutput on feedback off
declare
    l_n       number;
    l_n2      number;
    l_v       varchar2(4000);
    l_app     number;
    l_rfi     number;
    l_wf      number;
    l_task    number;
    l_token   varchar2(200);
    l_cat     varchar2(30);
    l_approver varchar2(255);
    l_role    varchar2(30);
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
    procedure session_as(p_user in varchar2) is
    begin
        apex_session.create_session(p_app_id => l_app, p_page_id => 1, p_username => p_user);
    end session_as;
    -- the workflow engine goes on in the background once the step is committed: wait (up to 3 minutes) until the
    -- workflow has nothing left to run - every activity completed, or one waits for a person, a wait or has ended
    procedure settle is
        l_busy number;
    begin
        commit;
        for i in 1 .. 90 loop
            dbms_session.sleep(2);
            select count(*) into l_busy from apex_workflows w
             where w.workflow_id = l_wf and w.state_code = 'ACTIVE'
               and not exists (select 1 from apex_workflow_activities a
                                where a.workflow_id = w.workflow_id and a.end_time is null
                                  and upper(a.state) in ('WAITING'));
            exit when l_busy = 0 and i > 1;
        end loop;
        dbms_session.sleep(2);   -- the task actions of the step just reached
    end settle;
    function activity(p_static_id in varchar2) return varchar2 is
        l_state varchar2(100);
    begin
        select max(state) keep (dense_rank last order by activity_id) into l_state
          from apex_workflow_activities where workflow_id = l_wf and static_id = p_static_id;
        return l_state;
    end activity;
    function open_task(p_def in varchar2) return number is
        l_id number;
    begin
        select max(task_id) into l_id from apex_tasks
         where workflow_id = l_wf and task_def_static_id = p_def and state_code in ('UNASSIGNED', 'ASSIGNED');
        return l_id;
    end open_task;
begin
    apex_util.set_workspace('XXCUS');
    select max(apex_application_id) into l_app from xxfnd_applications where application_code = 'COMMON';

    ---------------------------------------------------------------- objects and data
    select count(*) into l_n from user_objects where status <> 'VALID';
    check_(l_n = 0, 'no invalid object (' || l_n || ')');
    select count(*) into l_n from user_tables
     where table_name in ('XXFND_NOTIFY_CHANNELS', 'XXFND_NOTIFY_EVENTS', 'XXFND_NOTIFY_RECIPIENT_TYPES',
                          'XXFND_NOTIFY_RULES', 'XXFND_NOTIFICATIONS');
    check_(l_n = 5, 'the five notification tables exist (' || l_n || ')');
    select count(*) into l_n from xxfnd_notify_channels where channel_code in ('IN_APP', 'EMAIL', 'PUSH', 'FUSION');
    select count(*) into l_n2 from xxfnd_notify_channels where channel_code = 'FUSION' and enabled_flag = 'N'
       and integration_purpose = 'FUSION_NOTIFY';
    check_(l_n = 4 and l_n2 = 1, 'channels: in the application, e-mail, push, Fusion (prepared, off, purpose FUSION_NOTIFY)');
    select count(*) into l_n from xxfnd_integration_purposes where purpose_code = 'FUSION_NOTIFY';
    check_(l_n = 1, 'integration purpose FUSION_NOTIFY is registered');
    select count(*) into l_n from xxfnd_notify_events
     where event_code in ('TASK_ASSIGNED', 'TASK_APPROVED', 'TASK_REJECTED', 'TASK_INFO_REQUESTED', 'TASK_INFO_SUBMITTED',
                          'TASK_REMINDER', 'TASK_ESCALATED', 'RFI_RAISED', 'RFI_ANSWERED');
    check_(l_n = 9, 'the nine events are set up (' || l_n || ')');
    select count(*) into l_n from xxfnd_notify_events e
     where not exists (select 1 from xxfnd_notify_rules r where r.event_code = e.event_code);
    check_(l_n = 0, 'every event has rules');
    select count(*) into l_n from xxfnd_notify_recipient_types
     where recipient_type_code in ('TASK_OWNERS', 'TASK_INITIATOR', 'ROLE', 'PRIVILEGE', 'RECORD_PEOPLE', 'ESCALATION_ROLE',
                                   'RFI_RECIPIENT', 'RFI_OUTSIDE_PERSON', 'RFI_REQUESTER');
    check_(l_n = 9, 'recipients by query: owners, initiator, role, privilege, record people, escalation, RFI people (' || l_n || ')');
    select count(*) into l_n from xxfnd_notify_events e
     where not exists (select 1 from xxfnd_notification_templates_tl t
                        where t.template_code = e.template_code and t.language_code = 'ar');
    check_(l_n = 0, 'every event has its wording in Arabic too');
    select count(*) into l_n from xxfnd_notification_templates t
     where t.template_code in (select template_code from xxfnd_notify_events) and t.action_label is null;
    check_(l_n = 0, 'the link label is wording (ACTION_LABEL) for every event');

    ---------------------------------------------------------------- nothing hardcoded
    select count(*) into l_n from user_source
     where name = 'XXFND_WORKFLOW_PKG' and type = 'PACKAGE BODY'
       and (text like '%''TASK\_ASSIGNED''%' escape '\' or text like '%''TASK\_REMINDER''%' escape '\'
            or text like '%''TASK\_ESCALATED''%' escape '\' or text like '%''MY-TASKS''%');
    check_(l_n = 0, 'the workflow package names no event code and no page alias (' || l_n || ' lines)');
    select count(*) into l_n from user_source
     where name = 'XXFND_NOTIFY_PKG' and type = 'PACKAGE BODY' and text like '%''Open''%';
    check_(l_n = 0, 'the notification package has no hardcoded link label');
    check_(xxfnd_notify_pkg.event_for('CREATE') = 'TASK_ASSIGNED'
           and xxfnd_notify_pkg.event_for('COMPLETE', 'APPROVED') = 'TASK_APPROVED'
           and xxfnd_notify_pkg.event_for('COMPLETE', 'REJECTED') = 'TASK_REJECTED'
           and xxfnd_notify_pkg.event_for('REMINDER') = 'TASK_REMINDER',
           'the event of a trigger comes from XXFND_NOTIFY_EVENTS');

    ---------------------------------------------------------------- COMMON components
    select count(*) into l_n from apex_appl_workflows where application_id = l_app and static_id in ('RFI', 'CONFIG_CHANGE');
    check_(l_n = 2, 'RFI and CONFIG_CHANGE are APEX workflows of COMMON (' || l_n || ')');
    select count(*) into l_n from apex_appl_taskdefs where application_id = l_app
       and static_id in ('RFI_RESPONSE', 'RFI_REVIEW', 'CONFIG_CHANGE');
    check_(l_n = 3, 'their task definitions are in COMMON (' || l_n || ')');
    select count(*) into l_n from xxfnd_workflow_processes
     where application_code = 'COMMON' and process_code in ('RFI', 'CONFIG_CHANGE');
    check_(l_n = 2, 'both are in the Process Catalogue');
    select count(*) into l_n from apex_applications where application_id = l_app and pwa_is_push_enabled = 'Yes';
    check_(l_n = 1, 'COMMON is a progressive web app with push notifications');
    select count(*) into l_n from apex_application_settings where application_id = l_app and name in ('MAIL_FROM', 'MAIL_FOOTER');
    check_(l_n = 2, 'the sender and the footer are COMMON settings');
    select count(*) into l_n from apex_appl_automations where application_id = l_app and static_id = 'task-deadlines';
    check_(l_n = 1, 'the Task deadlines automation is in COMMON');
    select count(*) into l_n from user_source
     where name = 'XXFND_RFI_PKG' and type = 'PACKAGE BODY' and lower(text) like '%create_task(%';
    check_(l_n = 0, 'XXFND_RFI_PKG creates no task itself (the workflow does)');
    select count(*) into l_n from user_source
     where name = 'XXFND_APPROVAL_PKG' and type = 'PACKAGE BODY' and lower(text) like '%create_task(%';
    check_(l_n = 0, 'XXFND_APPROVAL_PKG creates no task itself (the workflow does)');

    ---------------------------------------------------------------- the RFI of a user: answer, review, ask again (the loop)
    session_as('ADMIN');
    select max(lookup_code) into l_cat from xxfnd_lookup_values where lookup_type = 'RFI_CATEGORY' and enabled_flag = 'Y';
    xxfnd_rfi_pkg.create_rfi(p_entity_name => 'R84_TEST', p_pk1_value => to_char(sysdate, 'YYYYMMDDHH24MISS'),
                             p_recipient_type => 'USER', p_rfi_category => l_cat, p_description => 'R84 question',
                             p_recipient_user_name => 'ADMIN', p_application_code => 'COMMON',
                             p_rfi_id => l_rfi, p_token => l_token);
    select workflow_id into l_wf from xxfnd_rfis where rfi_id = l_rfi;
    settle;
    check_(xxfnd_workflow_pkg.state(l_wf) = 'ACTIVE', 'the RFI starts the COMMON workflow RFI');
    l_task := open_task('RFI_RESPONSE');
    check_(l_task is not null, 'the workflow asks the user (RFI_RESPONSE task)');
    select count(*) into l_n from xxfnd_rfis where rfi_id = l_rfi and response_task_id = l_task;
    check_(l_n = 1, 'the task is kept on the RFI');
    select count(*) into l_n from xxfnd_notifications
     where task_id = l_task and event_code = 'TASK_ASSIGNED' and channel_code = 'IN_APP' and user_name = 'ADMIN'
       and status_code = 'SENT';
    check_(l_n = 1, 'the user is told in the application (TASK_ASSIGNED, raised in the background)');
    select count(*) into l_n from xxfnd_notifications
     where task_id = l_task and event_code = 'TASK_ASSIGNED' and channel_code in ('EMAIL', 'PUSH') and status_code = 'SKIPPED'
       and status_text is not null;
    check_(l_n = 2, 'e-mail and push say why they were skipped (no sender, no device)');
    select count(*) into l_n from xxfnd_notifications
     where task_id = l_task and channel_code = 'FUSION';
    check_(l_n = 0, 'nothing goes to Fusion while its channel is off');
    session_as('ADMIN');
    xxfnd_rfi_pkg.respond(l_rfi, 'R84 answer');
    settle;
    check_(open_task('RFI_REVIEW') is not null, 'the answer goes to the review (RFI_REVIEW task)');
    select count(*) into l_n from xxfnd_notifications where detail_pk = to_char(l_rfi) and event_code = 'RFI_ANSWERED'
       and channel_code = 'IN_APP' and status_code = 'SENT';
    check_(l_n = 1, 'the person who raised it is told (RFI_ANSWERED)');
    session_as('ADMIN');
    l_token := xxfnd_rfi_pkg.ask_again(l_rfi, 'R84 second question');
    settle;
    check_(open_task('RFI_RESPONSE') is not null and open_task('RFI_RESPONSE') <> l_task,
           'asked again, the workflow loops back to the answer');
    session_as('ADMIN');
    xxfnd_rfi_pkg.respond(l_rfi, 'R84 second answer');
    settle;
    session_as('ADMIN');
    xxfnd_rfi_pkg.resolve(l_rfi, 'RESOLVED', 'R84 resolved');
    settle;
    check_(xxfnd_workflow_pkg.state(l_wf) = 'COMPLETED', 'resolved, the workflow ends');
    select count(*) into l_n from xxfnd_rfi_rounds where rfi_id = l_rfi;
    check_(l_n = 2, 'both rounds are kept (questions and answers history)');
    l_task := null;
    select max(review_task_id) into l_task from xxfnd_rfis where rfi_id = l_rfi;
    session_as('ADMIN');
    select count(*) into l_n from table(xxfnd_rfi_pkg.task_messages(l_task));
    check_(l_n >= 6, 'the task page lists every question, answer and review (' || l_n || ')');

    ---------------------------------------------------------------- an outside person: one-time link, wait, public answer
    session_as('ADMIN');
    xxfnd_rfi_pkg.create_rfi(p_entity_name => 'R84_TEST', p_pk1_value => 'EXT' || to_char(sysdate, 'YYYYMMDDHH24MISS'),
                             p_recipient_type => 'EXTERNAL', p_rfi_category => l_cat, p_description => 'R84 outside question',
                             p_recipient_name => 'Outside Person', p_recipient_email => 'outside.r84@example.com',
                             p_application_code => 'COMMON', p_language => 'ar', p_rfi_id => l_rfi, p_token => l_token);
    xxfnd_rfi_pkg.send_email(l_rfi, p_token => l_token);
    select workflow_id into l_wf from xxfnd_rfis where rfi_id = l_rfi;
    settle;
    check_(activity('WAIT_ANSWER') = 'Waiting' or upper(activity('WAIT_ANSWER')) = 'WAITING',
           'the workflow waits for the outside answer (' || activity('WAIT_ANSWER') || ')');
    select count(*) into l_n from xxfnd_notifications
     where detail_pk = to_char(l_rfi) and event_code = 'RFI_RAISED' and channel_code = 'EMAIL'
       and email_address = 'outside.r84@example.com' and language_code = 'ar' and user_name is null;
    check_(l_n = 1, 'the outside person is e-mailed in the chosen language (RFI_RAISED)');
    select count(*) into l_n from xxfnd_notifications
     where detail_pk = to_char(l_rfi) and (dbms_lob.instr(message_text, l_token) > 0 or instr(link_url, l_token) > 0);
    check_(l_n = 0, 'the one-time link is never kept');
    check_(xxfnd_rfi_pkg.question_by_token(l_token) = 'R84 outside question', 'the public page shows the question');
    apex_session.delete_session;
    l_n := xxfnd_rfi_pkg.respond_by_token(l_token, 'R84 outside answer');   -- the public page: no user
    settle;
    check_(upper(activity('WAIT_ANSWER')) = 'COMPLETED' and open_task('RFI_REVIEW') is not null,
           'the public answer continues the workflow to the review');
    check_(xxfnd_rfi_pkg.question_by_token(l_token) is null, 'the link works once');
    expect_error(-20504, 'a used link is refused',
                 'declare n number; begin n := xxfnd_rfi_pkg.respond_by_token(''' || l_token || ''', ''again''); end;');
    session_as('ADMIN');
    xxfnd_rfi_pkg.resolve(l_rfi, 'CANCELLED', 'R84 cancelled');
    settle;
    check_(xxfnd_workflow_pkg.state(l_wf) in ('TERMINATED', 'COMPLETED'), 'cancelled, the workflow ends');

    ---------------------------------------------------------------- configuration change: maker-checker in a workflow
    select min(column_value) into l_approver
      from table(apex_string.split(xxfnd_workflow_pkg.users_with_privilege('CHANGE_APPROVALS', 'MANAGE'), ','))
     where column_value <> 'ADMIN';
    if l_approver is null then
        -- a second person for the test: a user with the role that approves configuration changes
        session_as('ADMIN');
        select min(role_code) into l_role from xxfnd_role_privileges where privilege_code = 'CHANGE_APPROVALS.MANAGE';
        select max(user_id) into l_n from xxfnd_users where user_name = 'R84_APPROVER';
        if l_n is null then
            l_n := xxfnd_user_pkg.create_local_user('R84_APPROVER', 'R84 Approver', 'r84.approver@example.com', 'R84Test#2026x');
        end if;
        xxfnd_user_pkg.assign_role(l_n, l_role);
        commit;
        l_approver := 'R84_APPROVER';
    end if;
    session_as('ADMIN');
    update xxfnd_integration_purposes set purpose_name = purpose_name where purpose_code = 'EMAIL_SYNC';
    xxfnd_approval_pkg.request('XXFND_INTEGRATION_PURPOSES', 'EMAIL_SYNC');
    select max(workflow_id) into l_wf from apex_workflows
     where workflow_def_static_id = 'CONFIG_CHANGE' and detail_pk = 'XXFND_INTEGRATION_PURPOSES:EMAIL_SYNC'
       and state_code = 'ACTIVE';
    settle;
    l_task := open_task('CONFIG_CHANGE');
    check_(l_task is not null, 'a change starts the COMMON workflow CONFIG_CHANGE and its approval task');
    select count(*) into l_n from apex_task_participants
     where task_id = l_task and participant_type = 'POTENTIAL_OWNER' and participant = 'ADMIN';
    check_(l_n = 0, 'the person who made the change is not an approver');
    session_as(l_approver);
    select count(*) into l_n from table(xxfnd_approval_pkg.task_change(l_task));
    check_(l_n = 1, 'the approver sees the change on the task page');
    l_v := xxfnd_approval_rule_pkg.decide_task(l_task, 'APPROVE', 'R84 approved');
    settle;
    session_as('ADMIN');
    select max(approval_status) into l_v from xxfnd_integration_purposes where purpose_code = 'EMAIL_SYNC';
    check_(l_v = 'APPROVED' and xxfnd_workflow_pkg.state(l_wf) = 'COMPLETED', 'approved, the change applies and the workflow ends');
    select count(*) into l_n from xxfnd_notifications
     where task_id = l_task and event_code = 'TASK_APPROVED' and user_name = 'ADMIN' and channel_code = 'IN_APP';
    check_(l_n = 1, 'the maker is told it was approved (TASK_APPROVED)');

    ---------------------------------------------------------------- the notification list, rules and data security
    session_as('ADMIN');
    l_n := xxfnd_notify_pkg.unread_count;
    check_(l_n > 0, 'the bell counts the unread notifications (' || l_n || ')');
    select max(notification_id) into l_n2 from xxfnd_notifications n
     where user_name = 'ADMIN' and read_date is null
       and channel_code in (select channel_code from xxfnd_notify_channels where inbox_flag = 'Y');
    xxfnd_notify_pkg.mark_read(l_n2);
    check_(xxfnd_notify_pkg.unread_count = l_n - 1, 'opening one marks it as read');
    session_as(l_approver);
    xxfnd_notify_pkg.mark_all_read;
    session_as('ADMIN');
    check_(xxfnd_notify_pkg.unread_count = l_n - 1, 'a person marks only their own notifications as read');
    xxfnd_notify_pkg.mark_all_read;
    check_(xxfnd_notify_pkg.unread_count = 0, 'mark all as read');
    select min(rule_id) into l_n from xxfnd_notify_rules where event_code = 'TASK_ASSIGNED' and channel_code = 'IN_APP';
    check_(xxfnd_notify_pkg.rule_recipients(l_n, p_task_id => l_task) like '%' || l_approver || '%',
           'a rule''s recipients can be tested (Notification Delivery)');
    check_(xxfnd_notify_pkg.has_push in ('Y', 'N'), 'push subscription status answers');
    session_as(l_approver);
    check_(xxfnd_workflow_pkg.task_record(l_task) is not null, 'a task''s own approver may open its page');
    session_as('R84_NOBODY');
    check_(xxfnd_workflow_pkg.task_record(l_task) is null, 'someone outside the task may not');
    select count(*) into l_n from table(xxfnd_approval_pkg.task_change(l_task));
    check_(l_n = 0, 'nor read its change');

    -- one RFI is left waiting for ADMIN's answer: the browser test opens its task page
    session_as('ADMIN');
    xxfnd_rfi_pkg.create_rfi(p_entity_name => 'R84_TEST', p_pk1_value => 'UI' || to_char(sysdate, 'YYYYMMDDHH24MISS'),
                             p_recipient_type => 'USER', p_rfi_category => l_cat, p_description => 'R84 question for the browser test',
                             p_recipient_user_name => 'ADMIN', p_application_code => 'COMMON',
                             p_rfi_id => l_rfi, p_token => l_token);
    select workflow_id into l_wf from xxfnd_rfis where rfi_id = l_rfi;
    settle;
    check_(open_task('RFI_RESPONSE') is not null, 'an RFI is left open for the browser test');
end;
/
