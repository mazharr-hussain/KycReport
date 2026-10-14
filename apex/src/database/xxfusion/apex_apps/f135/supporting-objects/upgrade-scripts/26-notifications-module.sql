--------------------------------------------------------------------------------
-- 26 Notifications module (release 84). COMMON only (XXFUSION), after 25.
--   Workflow notifications come from data, nothing is written into the packages:
--   - the wording per event and language (XXFND_NOTIFICATION_TEMPLATES / _TL, with the link label ACTION_LABEL),
--   - the channels (XXFND_NOTIFY_CHANNELS): in the application (the bell and the Notifications list), e-mail (APEX
--     mail, layout XXFND_STANDARD, sender MAIL_FROM and footer MAIL_FOOTER from the COMMON settings), push (APEX
--     progressive web app) and Fusion notifications (purpose FUSION_NOTIFY on the FUSION server, switched off),
--   - the events (XXFND_NOTIFY_EVENTS): task assigned, approved, rejected, information requested / submitted,
--     reminder, escalation, RFI raised / answered - what raises each and the link it carries (page alias, items),
--   - who is told (XXFND_NOTIFY_RECIPIENT_TYPES): a query each - the task's owners, the initiator, a role, a
--     privilege, the people of the record, the escalation role, the RFI's recipient / requester,
--   - the rules (XXFND_NOTIFY_RULES): per event (and application / process): who, on which channel.
--   The rows below are seeded only when missing: what an administrator changed is kept.
--   Also: the screens of the release (Notifications 43, Notification Delivery 116, Notification Log 117,
--   Communications 45 / E-mail 46, the task pages 143 / 144) and the COMMON processes RFI and CONFIG_CHANGE.
-- Idempotent: merges when missing, checked steps; a re-run changes nothing.
--------------------------------------------------------------------------------
declare
    procedure template(p_code in varchar2, p_subject in varchar2, p_message in varchar2, p_label in varchar2,
                       p_ar_subject in varchar2, p_ar_message in varchar2, p_ar_label in varchar2) is
    begin
        merge into xxfnd_notification_templates t using (select p_code template_code from dual) s
           on (t.template_code = s.template_code)
         when not matched then insert (template_code, subject, message_text, action_label, enabled_flag)
                               values (p_code, p_subject, p_message, p_label, 'Y');
        merge into xxfnd_notification_templates_tl t using (select p_code template_code, 'ar' language_code from dual) s
           on (t.template_code = s.template_code and t.language_code = s.language_code)
         when not matched then insert (template_code, language_code, subject, message_text, action_label)
                               values (p_code, 'ar', p_ar_subject, p_ar_message, p_ar_label);
        -- the link label of a template seeded before release 84 (was 'Open' in the package)
        update xxfnd_notification_templates set action_label = p_label where template_code = p_code and action_label is null;
        update xxfnd_notification_templates_tl set action_label = p_ar_label
         where template_code = p_code and language_code = 'ar' and action_label is null;
    end template;
begin
    xxfnd_util_pkg.set_install_mode(true);
    template('TASK_ASSIGNED', 'Action needed: #TASK_SUBJECT#',
             'A task is waiting for you.' || chr(10) || '#TASK_SUBJECT#' || chr(10) || 'Due: #DUE_DATE#', 'Open My Tasks',
             unistr('\0645\0637\0644\0648\0628 \0625\062C\0631\0627\0621: #TASK_SUBJECT#'),
             unistr('\0645\0647\0645\0629 \0628\0627\0646\062A\0638\0627\0631\0643.') || chr(10) || '#TASK_SUBJECT#'
                 || chr(10) || unistr('\062A\0627\0631\064A\062E \0627\0644\0627\0633\062A\062D\0642\0627\0642: #DUE_DATE#'),
             unistr('\0641\062A\062D \0645\0647\0627\0645\064A'));
    template('TASK_APPROVED', 'Approved: #TASK_SUBJECT#',
             '#OWNER# approved #TASK_SUBJECT#.' || chr(10) || '#COMMENT#', 'Open',
             unistr('\062A\0645\062A \0627\0644\0645\0648\0627\0641\0642\0629: #TASK_SUBJECT#'),
             unistr('\0648\0627\0641\0642 #OWNER# \0639\0644\0649 #TASK_SUBJECT#.') || chr(10) || '#COMMENT#',
             unistr('\0641\062A\062D'));
    template('TASK_REJECTED', 'Rejected: #TASK_SUBJECT#',
             '#OWNER# rejected #TASK_SUBJECT#.' || chr(10) || 'Reason: #COMMENT#', 'Open',
             unistr('\062A\0645 \0627\0644\0631\0641\0636: #TASK_SUBJECT#'),
             unistr('\0631\0641\0636 #OWNER# #TASK_SUBJECT#.') || chr(10) || unistr('\0627\0644\0633\0628\0628: #COMMENT#'),
             unistr('\0641\062A\062D'));
    template('TASK_INFO_REQUESTED', 'Information requested: #TASK_SUBJECT#',
             '#OWNER# needs more information before deciding #TASK_SUBJECT#.' || chr(10) || '#COMMENT#', 'Open My Tasks',
             unistr('\0645\0637\0644\0648\0628 \0645\0639\0644\0648\0645\0627\062A: #TASK_SUBJECT#'),
             unistr('\064A\062D\062A\0627\062C #OWNER# \0625\0644\0649 \0645\0639\0644\0648\0645\0627\062A \0625\0636\0627\0641\064A\0629 \0642\0628\0644 \0627\0644\0642\0631\0627\0631 \0641\064A #TASK_SUBJECT#.')
                 || chr(10) || '#COMMENT#',
             unistr('\0641\062A\062D \0645\0647\0627\0645\064A'));
    template('TASK_INFO_SUBMITTED', 'Information submitted: #TASK_SUBJECT#',
             '#INITIATOR# answered your question on #TASK_SUBJECT#.' || chr(10) || '#COMMENT#', 'Open My Tasks',
             unistr('\062A\0645 \062A\0642\062F\064A\0645 \0627\0644\0645\0639\0644\0648\0645\0627\062A: #TASK_SUBJECT#'),
             unistr('\0623\062C\0627\0628 #INITIATOR# \0639\0644\0649 \0633\0624\0627\0644\0643 \0628\0634\0623\0646 #TASK_SUBJECT#.')
                 || chr(10) || '#COMMENT#',
             unistr('\0641\062A\062D \0645\0647\0627\0645\064A'));
    template('TASK_REMINDER', 'Reminder: #TASK_SUBJECT#',
             'This task is due on #DUE_DATE# and is still open.' || chr(10) || '#TASK_SUBJECT#', 'Open My Tasks',
             unistr('\062A\0630\0643\064A\0631: #TASK_SUBJECT#'),
             unistr('\0647\0630\0647 \0627\0644\0645\0647\0645\0629 \0645\0633\062A\062D\0642\0629 \0641\064A #DUE_DATE# \0648\0644\0627 \062A\0632\0627\0644 \0645\0641\062A\0648\062D\0629.')
                 || chr(10) || '#TASK_SUBJECT#',
             unistr('\0641\062A\062D \0645\0647\0627\0645\064A'));
    template('TASK_ESCALATED', 'Overdue task escalated: #TASK_SUBJECT#',
             'This task was due on #DUE_DATE# and is still open. It is escalated to you.' || chr(10) || '#TASK_SUBJECT#'
                 || chr(10) || 'Assigned to: #ASSIGNEES#', 'Open the Workflow Monitor',
             unistr('\062A\0635\0639\064A\062F \0645\0647\0645\0629 \0645\062A\0623\062E\0631\0629: #TASK_SUBJECT#'),
             unistr('\0643\0627\0646\062A \0647\0630\0647 \0627\0644\0645\0647\0645\0629 \0645\0633\062A\062D\0642\0629 \0641\064A #DUE_DATE# \0648\0644\0627 \062A\0632\0627\0644 \0645\0641\062A\0648\062D\0629.')
                 || chr(10) || '#TASK_SUBJECT#' || chr(10) || unistr('\0645\0633\0646\062F\0629 \0625\0644\0649: #ASSIGNEES#'),
             unistr('\0641\062A\062D \0645\0631\0627\0642\0628 \0633\064A\0631 \0627\0644\0639\0645\0644'));
    template('RFI_RAISED_INTERNAL', 'Information requested: #RFI_NUMBER#',
             'More information is needed for #RFI_NUMBER#.' || chr(10) || '#DESCRIPTION#' || chr(10) || 'Please reply by #DUE_DATE#.',
             'Open My Tasks',
             unistr('\0645\0637\0644\0648\0628 \0645\0639\0644\0648\0645\0627\062A: #RFI_NUMBER#'),
             unistr('\0645\0637\0644\0648\0628 \0645\0639\0644\0648\0645\0627\062A \0625\0636\0627\0641\064A\0629 \0644\0640 #RFI_NUMBER#.')
                 || chr(10) || '#DESCRIPTION#' || chr(10) || unistr('\064A\0631\062C\0649 \0627\0644\0631\062F \0642\0628\0644 #DUE_DATE#.'),
             unistr('\0641\062A\062D \0645\0647\0627\0645\064A'));
    template('RFI_RAISED_EXTERNAL', 'Information requested: #RFI_NUMBER#',
             'Dear #CONTACT_NAME#,' || chr(10) || 'To complete our review we need the following information:' || chr(10)
                 || '#DESCRIPTION#' || chr(10) || 'Please respond by #DUE_DATE# using the secure link.',
             'Provide the information',
             unistr('\0645\0637\0644\0648\0628 \0645\0639\0644\0648\0645\0627\062A: #RFI_NUMBER#'),
             unistr('\0627\0644\0633\064A\062F/\0627\0644\0633\064A\062F\0629 #CONTACT_NAME#\060C') || chr(10)
                 || unistr('\0644\0625\0643\0645\0627\0644 \0627\0644\0645\0631\0627\062C\0639\0629 \0646\062D\062A\0627\062C \0625\0644\0649 \0627\0644\0645\0639\0644\0648\0645\0627\062A \0627\0644\062A\0627\0644\064A\0629:')
                 || chr(10) || '#DESCRIPTION#' || chr(10)
                 || unistr('\064A\0631\062C\0649 \0627\0644\0631\062F \0642\0628\0644 #DUE_DATE# \0639\0628\0631 \0627\0644\0631\0627\0628\0637 \0627\0644\0622\0645\0646.'),
             unistr('\062A\0642\062F\064A\0645 \0627\0644\0645\0639\0644\0648\0645\0627\062A'));
    template('RFI_RESPONDED', 'Response received: #RFI_NUMBER#',
             'An answer was received for #RFI_NUMBER#.' || chr(10) || '#DESCRIPTION#', 'Open My Tasks',
             unistr('\062A\0645 \0627\0633\062A\0644\0627\0645 \0627\0644\0631\062F: #RFI_NUMBER#'),
             unistr('\062A\0645 \0627\0633\062A\0644\0627\0645 \0631\062F \0639\0644\0649 #RFI_NUMBER#.') || chr(10) || '#DESCRIPTION#',
             unistr('\0641\062A\062D \0645\0647\0627\0645\064A'));
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/

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

--------------------------------------------------------------------------------
-- The screens of the release: privileges and pages (every page has View and Manage; data security on the rows).
--   My Tasks: Notifications (43) and the task pages Information Request (143) and Configuration Change (144).
--   Notifications (setup): Notification Delivery (116) and Notification Log (117).
--   Communications (new): the e-mails of a record (45) and the E-mail dialog (46).
--------------------------------------------------------------------------------
declare
    l_app number;
    l_n   number;
    procedure page(p_feature in varchar2, p_page in number) is
    begin
        merge into xxfnd_feature_pages d
        using (select 'COMMON' app_alias, p_page page_id from dual) s
           on (d.app_alias = s.app_alias and d.page_id = s.page_id)
         when not matched then insert (app_alias, page_id, feature_code, tab_label, tab_sequence)
                               values ('COMMON', p_page, p_feature, null, null);
    end page;
begin
    xxfnd_util_pkg.set_install_mode(true);
    select application_id into l_app from xxfnd_applications where application_code = 'COMMON';
    merge into xxfnd_features t using (select 'COMMUNICATIONS' c from dual) s on (t.feature_code = s.c)
     when not matched then insert (feature_code, feature_name, feature_group, display_sequence, admin_flag,
                                   application_id, home_page_id, icon_css, description)
                           values ('COMMUNICATIONS', 'Communications', 'BUSINESS', 30, 'N', l_app, 45, 'fa-envelope-o',
                                   'The e-mails with outside people of a record of any application: send, record a received one, history.');
    merge into xxfnd_privileges t
    using (select 'COMMUNICATIONS.' || column_value pc, column_value act from table(apex_t_varchar2('VIEW', 'CREATE', 'MANAGE'))) s
       on (t.privilege_code = s.pc)
     when not matched then insert (privilege_code, feature_code, action_code, privilege_name)
                           values (s.pc, 'COMMUNICATIONS', s.act, 'Communications - ' || initcap(s.act));
    -- every role sees and sends the e-mails of the records it may see (data security of the application's record);
    -- recording a received e-mail (MANAGE): the roles that manage the notifications
    merge into xxfnd_role_privileges t
    using (select r.role_code, p.column_value pc
             from xxfnd_roles r cross join table(apex_t_varchar2('COMMUNICATIONS.VIEW', 'COMMUNICATIONS.CREATE')) p
           union
           select rp.role_code, 'COMMUNICATIONS.MANAGE' from xxfnd_role_privileges rp
            where rp.privilege_code = 'NOTIFICATIONS.MANAGE') s
       on (t.role_code = s.role_code and t.privilege_code = s.pc)
     when not matched then insert (role_code, privilege_code) values (s.role_code, s.pc);
    -- the approvers of configuration changes (COMMON process CONFIG_CHANGE): the privilege, when COMMON runs alone, granted
    -- once to the roles that manage the Approval Setup
    select count(*) into l_n from xxfnd_features where feature_code = 'CHANGE_APPROVALS';
    if l_n = 0 then
        insert into xxfnd_features (feature_code, feature_name, feature_group, display_sequence, admin_flag, application_id,
                                    icon_css, description)
        values ('CHANGE_APPROVALS', 'Configuration Change Approvals', 'WORKFLOW', 70, 'Y', l_app, 'fa-check-square-o',
                'Who approves the configuration changes of every application (maker-checker, process CONFIG_CHANGE).');
        insert into xxfnd_privileges (privilege_code, feature_code, action_code, privilege_name)
        select 'CHANGE_APPROVALS.' || column_value, 'CHANGE_APPROVALS', column_value,
               'Configuration Change Approvals - ' || initcap(column_value)
          from table(apex_t_varchar2('VIEW', 'MANAGE'))
         where not exists (select 1 from xxfnd_privileges where privilege_code = 'CHANGE_APPROVALS.' || column_value);
        insert into xxfnd_role_privileges (role_code, privilege_code)
        select rp.role_code, 'CHANGE_APPROVALS.' || a.column_value
          from xxfnd_role_privileges rp cross join table(apex_t_varchar2('VIEW', 'MANAGE')) a
         where rp.privilege_code = 'APPROVAL_SETUP.MANAGE'
           and not exists (select 1 from xxfnd_role_privileges x
                            where x.role_code = rp.role_code and x.privilege_code = 'CHANGE_APPROVALS.' || a.column_value);
    end if;
    -- the records of COMMON that keep files (an e-mail's file; an RFI's answer documents) and the category of a file
    -- kept with an e-mail: registered by COMMON itself (before release 84 only the KYC seed did)
    merge into xxfnd_document_entities t
    using (select 'XXFND_COMMUNICATIONS' entity_name, 'XXFND_COMMUNICATIONS' table_name, 'COMMUNICATION_ID' pk from dual
           union all select 'XXFND_RFIS', 'XXFND_RFIS', 'RFI_ID' from dual) s
       on (t.entity_name = s.entity_name)
     when not matched then insert (entity_name, application_code, table_name, pk1_column, enabled_flag)
                           values (s.entity_name, 'COMMON', s.table_name, s.pk, 'Y');
    merge into xxfnd_document_entities_tl t
    using (select 'XXFND_COMMUNICATIONS' entity_name, 'E-mail' user_name from dual
           union all select 'XXFND_RFIS', 'Request for Information' from dual) s
       on (t.entity_name = s.entity_name and t.language_code = 'en')
     when not matched then insert (entity_name, language_code, user_entity_name) values (s.entity_name, 'en', s.user_name);
    merge into xxfnd_document_categories t using (select 'OTHER' category_code from dual) s
       on (t.category_code = s.category_code)
     when not matched then insert (category_code, application_code, category_name, default_datatype_code, has_expiry_flag)
                           values ('OTHER', 'COMMON', 'Other Document', 'FILE', 'N');
    page('MY_TASKS', 43);
    page('MY_TASKS', 143);
    page('MY_TASKS', 144);
    page('NOTIFICATIONS', 116);
    page('NOTIFICATIONS', 117);
    page('COMMUNICATIONS', 45);
    page('COMMUNICATIONS', 46);
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/

--------------------------------------------------------------------------------
-- The COMMON workflow processes RFI and CONFIG_CHANGE in the Process Catalogue (from the APEX dictionary), and the
-- push keys of COMMON in a new workspace: an imported application carries only the public key of its push
-- credential, so the key pair is made here while no device is subscribed yet.
--------------------------------------------------------------------------------
declare
    l_subs number;
    l_app  number;
begin
    xxfnd_util_pkg.set_install_mode(true);
    begin
        xxfnd_workflow_pkg.sync_processes;
    exception
        when others then
            -- the package was recompiled earlier in this install session (its state is discarded once): call again
            if sqlcode in (-4068, -4061, -4065, -6508) then
                xxfnd_workflow_pkg.sync_processes;
            else
                raise;
            end if;
    end;
    update xxfnd_workflow_processes set participants_type = 'RULE'
     where process_code = 'CONFIG_CHANGE' and participants_type <> 'RULE';
    xxfnd_util_pkg.set_install_mode(false);
    commit;
    select max(apex_application_id) into l_app from xxfnd_applications where application_code = 'COMMON';
    select count(*) into l_subs from apex_appl_push_subscriptions where application_id = l_app;
    if l_app is not null and l_subs = 0 then
        begin
            apex_pwa.generate_push_credentials(p_application_id => l_app);
            commit;
        exception
            when others then
                null;   -- not a progressive web app here (e.g. the application is not imported yet): set up in App Builder
        end;
    end if;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/

-- the applications reach the new objects through the usual grants
begin
    xxfnd_share_pkg.grant_to_applications;
end;
/

-- anything a change above left invalid is compiled again (no install error, no stale package state)
begin
    dbms_utility.compile_schema(schema => user, compile_all => false);
end;
/
