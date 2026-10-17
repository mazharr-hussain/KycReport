
declare
    l_n            number;
    l_new_answered boolean;
    procedure channel(p_code in varchar2, p_name in varchar2, p_proc in varchar2, p_inbox in varchar2, p_enabled in varchar2,
                      p_seq in number, p_purpose in varchar2, p_desc in varchar2) is
    begin
        merge into xxfnd_notify_channels t using (select p_code channel_code from dual) s
           on (t.channel_code = s.channel_code)
         when not matched then insert (channel_code, channel_name, delivery_procedure, inbox_flag, enabled_flag,
                                       display_sequence, integration_purpose, description)
                               values (p_code, p_name, p_proc, p_inbox, p_enabled, p_seq, p_purpose, p_desc);
    end channel;
    procedure event(p_code in varchar2, p_name in varchar2, p_template in varchar2, p_trigger in varchar2,
                    p_outcome in varchar2, p_alias in varchar2, p_items in varchar2 default null,
                    p_tokens in varchar2 default null, p_public in varchar2 default 'N', p_desc in varchar2 default null) is
    begin
        merge into xxfnd_notify_events t using (select p_code event_code from dual) s
           on (t.event_code = s.event_code)
         when not matched then insert (event_code, event_name, template_code, trigger_code, outcome_code,
                                       link_application_code, link_page_alias, link_items, link_tokens, link_public_flag,
                                       description)
                               values (p_code, p_name, p_template, p_trigger, p_outcome,
                                       case when p_alias is not null then 'COMMON' end, p_alias, p_items, p_tokens,
                                       p_public, p_desc);
    end event;
    procedure recipient(p_code in varchar2, p_name in varchar2, p_query in varchar2, p_value in varchar2,
                        p_desc in varchar2) is
    begin
        merge into xxfnd_notify_recipient_types t using (select p_code recipient_type_code from dual) s
           on (t.recipient_type_code = s.recipient_type_code)
         when not matched then insert (recipient_type_code, recipient_type_name, recipient_query, value_required_flag,
                                       description)
                               values (p_code, p_name, p_query, p_value, p_desc);
    end recipient;
    procedure rule(p_event in varchar2, p_recipient in varchar2, p_channels in varchar2, p_template in varchar2 default null,
                   p_enabled in varchar2 default 'Y') is
    begin
        for c in (select trim(column_value) channel_code from table(apex_string.split(p_channels, ','))) loop
            merge into xxfnd_notify_rules t
            using (select p_event event_code, p_recipient recipient_type_code, c.channel_code channel_code from dual) s
               on (t.event_code = s.event_code and t.recipient_type_code = s.recipient_type_code
                   and t.channel_code = s.channel_code and t.application_code is null and t.process_code is null
                   and t.recipient_value is null)
             when not matched then insert (event_code, recipient_type_code, channel_code, template_code, enabled_flag)
                                   values (p_event, p_recipient, c.channel_code, p_template, p_enabled);
        end loop;
    end rule;
begin
    xxfnd_util_pkg.set_install_mode(true);
    -- Fusion notifications: prepared, switched off; switched on by data once purpose FUSION_NOTIFY has its REST source
    merge into xxfnd_integration_purposes t using (select 'FUSION_NOTIFY' purpose_code from dual) s
       on (t.purpose_code = s.purpose_code)
     when not matched then insert (purpose_code, application_code, purpose_name, capture_method,
                                   approval_status, approved_by, approved_date)
                           values ('FUSION_NOTIFY', 'COMMON', 'Fusion notifications (bell of Oracle Fusion)', 'MANUAL',
                                   'APPROVED', 'INSTALL', systimestamp);

    channel('IN_APP', 'In the application', 'xxfnd_notify_pkg.deliver_in_app', 'Y', 'Y', 10, null,
            'The bell in the navigation bar and the Notifications list of the person.');
    channel('EMAIL', 'E-mail', 'xxfnd_notify_pkg.deliver_email', 'N', 'Y', 20, null,
            'APEX mail with the XXFND_STANDARD layout; sender MAIL_FROM and footer MAIL_FOOTER (COMMON settings); the e-mail switches apply.');
    channel('PUSH', 'Push notification', 'xxfnd_notify_pkg.deliver_push', 'N', 'Y', 30, null,
            'APEX progressive web app push to every device the person subscribed (Notifications > This device).');
    channel('FUSION', 'Fusion notifications', 'xxfnd_notify_pkg.deliver_fusion', 'N', 'N', 40, 'FUSION_NOTIFY',
            'Oracle Fusion bell notifications through integration purpose FUSION_NOTIFY on the FUSION server. Switch on once the purpose has its REST Data Source.');

    event('TASK_ASSIGNED', 'A task is assigned', 'TASK_ASSIGNED', 'CREATE', null, 'MY-TASKS');
    event('TASK_APPROVED', 'A task is approved', 'TASK_APPROVED', 'COMPLETE', 'APPROVED', 'MY-TASKS');
    event('TASK_REJECTED', 'A task is rejected', 'TASK_REJECTED', 'COMPLETE', 'REJECTED', 'MY-TASKS');
    event('TASK_INFO_REQUESTED', 'Information is requested on a task', 'TASK_INFO_REQUESTED', 'REQUEST_INFO', null, 'MY-TASKS');
    event('TASK_INFO_SUBMITTED', 'Information is submitted on a task', 'TASK_INFO_SUBMITTED', 'SUBMIT_INFO', null, 'MY-TASKS');
    event('TASK_REMINDER', 'A task is due soon', 'TASK_REMINDER', 'REMINDER', null, 'MY-TASKS');
    event('TASK_ESCALATED', 'An overdue task is escalated', 'TASK_ESCALATED', 'ESCALATION', null, 'WORKFLOW-MONITOR');
    event('RFI_RAISED', 'Information is requested (RFI)', 'RFI_RAISED_EXTERNAL', 'RFI_RAISED', null, 'PROVIDE-INFORMATION',
          'P50_TOKEN', 'RESPONSE_TOKEN', 'Y',
          'The link is the one-time answer link of the outside person (public page Provide Information).');
    select count(*) into l_n from xxfnd_notify_events where event_code = 'RFI_ANSWERED';
    l_new_answered := l_n = 0;
    event('RFI_ANSWERED', 'An RFI is answered', 'RFI_RESPONDED', 'RFI_ANSWERED', null, 'MY-TASKS');

    recipient('TASK_OWNERS', 'The people who can act on the task',
        q'~select participant as user_name from apex_task_participants
 where task_id = to_number(:TASK_ID) and participant_type = 'POTENTIAL_OWNER' and identity_type = 'USER'
union
select actual_owner from apex_tasks where task_id = to_number(:TASK_ID) and actual_owner is not null~', 'N',
        'Potential owners of the task, and its owner once claimed.');
    recipient('TASK_INITIATOR', 'The person who started the task or workflow',
        q'~select initiator as user_name from apex_tasks where task_id = to_number(:TASK_ID)
union
select initiator from apex_workflows where workflow_id = to_number(:WORKFLOW_ID)~', 'N',
        'The initiator of the task (the requester), else of the workflow.');
    recipient('ROLE', 'The users of a role',
        q'~select user_name from xxfnd_user_roles_v where role_code = upper(:VALUE) and active_flag = 'Y'~', 'Y',
        'Every active user of the role given as the rule''s value.');
    recipient('PRIVILEGE', 'The users with a privilege',
        q'~select ur.user_name from xxfnd_user_roles_v ur join xxfnd_role_privileges rp on rp.role_code = ur.role_code
 where rp.privilege_code = upper(:VALUE) and ur.active_flag = 'Y'~', 'Y',
        'Every active user holding the privilege given as the rule''s value (e.g. WORKFLOW_MONITOR.MANAGE).');
    recipient('RECORD_PEOPLE', 'The people of the record',
        q'~select p.participant as user_name
  from apex_tasks t join apex_task_participants p on p.task_id = t.task_id and p.identity_type = 'USER'
 where t.detail_pk = :DETAIL_PK
   and t.task_def_static_id in (select task_def_static_id from apex_tasks where task_id = to_number(:TASK_ID)
                                union select task_def_static_id from apex_tasks where workflow_id = to_number(:WORKFLOW_ID))
union
select initiator from apex_tasks where detail_pk = :DETAIL_PK and task_id = to_number(:TASK_ID)~', 'N',
        'Everyone who took part in the tasks of the same record (owners, approvers, initiator).');
    recipient('ESCALATION_ROLE', 'The escalation role of the task',
        q'~select ur.user_name
  from apex_tasks k join xxfnd_task_settings s on s.task_definition = k.task_def_static_id
  join xxfnd_user_roles_v ur on ur.role_code = s.escalation_role_code and ur.active_flag = 'Y'
 where k.task_id = to_number(:TASK_ID)~', 'N',
        'The users of the escalation role set for the task definition (Deadlines and Escalation).');
    recipient('RFI_RECIPIENT', 'The user an RFI is addressed to',
        q'~select upper(trim(column_value)) as user_name
  from xxfnd_rfis r, table(apex_string.split(xxfnd_rfi_pkg.recipient(r.rfi_id), ','))
 where r.rfi_id = to_number(:DETAIL_PK) and r.recipient_type = 'USER'~', 'N',
        'The user (or the providers from the Approval Setup) who answer the RFI.');
    recipient('RFI_OUTSIDE_PERSON', 'The outside person an RFI is addressed to',
        q'~select null as user_name, recipient_email as email_address, language_code
  from xxfnd_rfis where rfi_id = to_number(:DETAIL_PK) and recipient_type <> 'USER' and recipient_email is not null~', 'N',
        'A person without an account: e-mail only, in the language chosen when the RFI was raised.');
    recipient('RFI_REQUESTER', 'The person who raised the RFI',
        q'~select upper(created_by) as user_name from xxfnd_rfis where rfi_id = to_number(:DETAIL_PK)~', 'N',
        'The user who raised the request for information.');

    rule('TASK_ASSIGNED',       'TASK_OWNERS',     'IN_APP,EMAIL,PUSH,FUSION');
    rule('TASK_APPROVED',       'TASK_INITIATOR',  'IN_APP,EMAIL,PUSH,FUSION');
    rule('TASK_REJECTED',       'TASK_INITIATOR',  'IN_APP,EMAIL,PUSH,FUSION');
    rule('TASK_INFO_REQUESTED', 'TASK_INITIATOR',  'IN_APP,EMAIL,PUSH,FUSION');
    rule('TASK_INFO_SUBMITTED', 'TASK_OWNERS',     'IN_APP,EMAIL,PUSH,FUSION');
    rule('TASK_REMINDER',       'TASK_OWNERS',     'IN_APP,EMAIL,PUSH,FUSION');
    rule('TASK_ESCALATED',      'ESCALATION_ROLE', 'IN_APP,EMAIL,PUSH,FUSION');
    rule('RFI_RAISED',          'RFI_OUTSIDE_PERSON', 'EMAIL');
    -- a user who answers an RFI is told by the RFI_RESPONSE task (TASK_ASSIGNED); this e-mail is there to switch on
    rule('RFI_RAISED',          'RFI_RECIPIENT',   'EMAIL', 'RFI_RAISED_INTERNAL', 'N');
    rule('RFI_ANSWERED',        'RFI_REQUESTER',   'IN_APP,EMAIL,PUSH');
    -- release 82 switched the "response received" wording off (the reviewer gets a task); release 84 tells the person
    -- who raised the RFI with it: switched on once, when its event is first created
    if l_new_answered then
        update xxfnd_notification_templates set enabled_flag = 'Y' where template_code = 'RFI_RESPONDED' and enabled_flag = 'N';
    end if;
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
