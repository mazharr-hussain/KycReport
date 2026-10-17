
--==============================================================================
-- 0.0  NOTIFICATION TEMPLATES, AUDIT, RETENTION
--==============================================================================
begin
    if xxfnd_ddl_pkg.create_table('XXFND_NOTIFICATION_TEMPLATES', q'~create table xxfnd_notification_templates (
    template_code          varchar2(50)   not null,
    application_code       varchar2(30),
    subject                varchar2(500)  not null,
    body_html              clob           not null,
    enabled_flag           varchar2(1)    default 'Y' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_notif_templates_pk primary key (template_code),
    constraint xxfnd_notif_templates_ck1 check (enabled_flag in ('Y','N'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_notification_templates is 'Wording of every system email and alert. Placeholders use #TOKEN# syntax and are replaced at send time.'~');
    end if;
end;
/

-- Release 82: the notification wording is plain text per event and language (MESSAGE_TEXT); the layout is the APEX
-- Email Template XXFND_STANDARD. BODY_HTML is kept (no data is deleted) but no longer required.
begin
    xxfnd_ddl_pkg.add_column('XXFND_NOTIFICATION_TEMPLATES', 'MESSAGE_TEXT', 'clob');
    xxfnd_ddl_pkg.add_column('XXFND_NOTIFICATION_TEMPLATES_TL', 'MESSAGE_TEXT', 'clob');
    xxfnd_ddl_pkg.set_nullable('XXFND_NOTIFICATION_TEMPLATES', 'BODY_HTML');
    xxfnd_ddl_pkg.set_nullable('XXFND_NOTIFICATION_TEMPLATES_TL', 'BODY_HTML');
    xxfnd_ddl_pkg.run(q'~comment on column xxfnd_notification_templates.message_text is 'Release 82: the message as plain text with #TOKEN# placeholders; the layout (links, formatting, direction) comes from the APEX Email Template XXFND_STANDARD.'~');
    xxfnd_ddl_pkg.run(q'~comment on column xxfnd_notification_templates.body_html is 'Before release 82: the message as HTML. Kept; read only when MESSAGE_TEXT is empty (tags dropped).'~');
end;
/

--------------------------------------------------------------------------------
-- Release 84: notifications driven by data (created here, before XXFND_NOTIFY_PKG that reads and writes them).
--   XXFND_NOTIFY_CHANNELS        how a notification reaches a person: in the application (bell), e-mail, push to
--                                the browser or phone (APEX PWA), Fusion notifications (prepared, off). Each channel
--                                names its delivery procedure; a channel switched off sends nothing.
--   XXFND_NOTIFY_EVENTS          what happens (a task is assigned, approved, ...): its wording (notification
--                                template), what raises it (TRIGGER_CODE + OUTCOME) and the link it carries.
--   XXFND_NOTIFY_RECIPIENT_TYPES who can be told: a query that returns USER_NAME (and EMAIL_ADDRESS, LANGUAGE_CODE
--                                for people without an account) with the binds :TASK_ID, :WORKFLOW_ID, :DETAIL_PK,
--                                :APPLICATION_CODE, :PROCESS_CODE and :VALUE (the rule's value: a role, a privilege).
--   XXFND_NOTIFY_RULES           per event (and application / process, empty = every one): who is told on which
--                                channel, optionally in other wording (TEMPLATE_CODE).
--   XXFND_NOTIFICATIONS          every notification made: one row per person and channel, with its status; the
--                                in-application rows are the person's notification list (read or not).
--------------------------------------------------------------------------------
begin
    -- the link label of a notification is wording too (was 'Open' in the package): per template and language
    xxfnd_ddl_pkg.add_column('XXFND_NOTIFICATION_TEMPLATES', 'ACTION_LABEL', 'varchar2(100)');
    xxfnd_ddl_pkg.add_column('XXFND_NOTIFICATION_TEMPLATES_TL', 'ACTION_LABEL', 'varchar2(100)');

    if xxfnd_ddl_pkg.create_table('XXFND_NOTIFY_CHANNELS', q'~create table xxfnd_notify_channels (
    channel_code           varchar2(30)   not null,
    channel_name           varchar2(100)  not null,
    delivery_procedure     varchar2(200)  not null,
    integration_purpose    varchar2(30),
    inbox_flag             varchar2(1)    default 'N' not null,
    enabled_flag           varchar2(1)    default 'Y' not null,
    display_sequence       number         default 10 not null,
    description            varchar2(1000),
    created_by             varchar2(255)  not null,
    creation_date          timestamp      not null,
    last_updated_by        varchar2(255)  not null,
    last_update_date       timestamp      not null,
    last_update_login      varchar2(255),
    object_version_number  number         default 1 not null,
    constraint xxfnd_notify_channels_pk primary key (channel_code),
    constraint xxfnd_notify_channels_ck1 check (enabled_flag in ('Y','N')),
    constraint xxfnd_notify_channels_ck2 check (channel_code = upper(channel_code)),
    constraint xxfnd_notify_channels_ck3 check (inbox_flag in ('Y','N'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_notify_channels is 'Release 84: the channels a notification is delivered on (in the application, e-mail, push, Fusion). DELIVERY_PROCEDURE takes the notification ID; INTEGRATION_PURPOSE is the COMMON integration purpose a remote channel calls; INBOX_FLAG Y = its notifications are the person''s notification list (the bell).'~');
    end if;

    if xxfnd_ddl_pkg.create_table('XXFND_NOTIFY_EVENTS', q'~create table xxfnd_notify_events (
    event_code             varchar2(30)   not null,
    event_name             varchar2(200)  not null,
    template_code          varchar2(50)   not null,
    trigger_code           varchar2(30)   not null,
    outcome_code           varchar2(30),
    link_application_code  varchar2(30),
    link_page_alias        varchar2(255),
    link_items             varchar2(1000),
    link_tokens            varchar2(1000),
    link_public_flag       varchar2(1)    default 'N' not null,
    enabled_flag           varchar2(1)    default 'Y' not null,
    description            varchar2(1000),
    created_by             varchar2(255)  not null,
    creation_date          timestamp      not null,
    last_updated_by        varchar2(255)  not null,
    last_update_date       timestamp      not null,
    last_update_login      varchar2(255),
    object_version_number  number         default 1 not null,
    constraint xxfnd_notify_events_pk primary key (event_code),
    constraint xxfnd_notify_events_fk1 foreign key (template_code) references xxfnd_notification_templates (template_code),
    constraint xxfnd_notify_events_ck1 check (enabled_flag in ('Y','N')),
    constraint xxfnd_notify_events_ck2 check (link_public_flag in ('Y','N'))
)~') then
        xxfnd_ddl_pkg.run(q'~create unique index xxfnd_notify_events_u1 on xxfnd_notify_events (trigger_code, nvl(outcome_code, '#'))~');
        xxfnd_ddl_pkg.run(q'~create index xxfnd_notify_events_n1 on xxfnd_notify_events (template_code)~');
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_notify_events is 'Release 84: notification events. TRIGGER_CODE is what raises the event (an APEX task event CREATE, COMPLETE, REQUEST_INFO, SUBMIT_INFO; a deadline REMINDER, ESCALATION; an RFI step), OUTCOME_CODE narrows a completion (APPROVED, REJECTED). The link is the page LINK_PAGE_ALIAS of application LINK_APPLICATION_CODE (empty = the task''s own application), with LINK_ITEMS set from the event values LINK_TOKENS; LINK_PUBLIC_FLAG Y for a page opened without an account.'~');
    end if;

    if xxfnd_ddl_pkg.create_table('XXFND_NOTIFY_RECIPIENT_TYPES', q'~create table xxfnd_notify_recipient_types (
    recipient_type_code    varchar2(30)   not null,
    recipient_type_name    varchar2(200)  not null,
    recipient_query        varchar2(4000) not null,
    value_required_flag    varchar2(1)    default 'N' not null,
    description            varchar2(1000),
    created_by             varchar2(255)  not null,
    creation_date          timestamp      not null,
    last_updated_by        varchar2(255)  not null,
    last_update_date       timestamp      not null,
    last_update_login      varchar2(255),
    object_version_number  number         default 1 not null,
    constraint xxfnd_notify_rcpt_types_pk primary key (recipient_type_code),
    constraint xxfnd_notify_rcpt_types_ck1 check (value_required_flag in ('Y','N'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_notify_recipient_types is 'Release 84: who a notification goes to, as a query returning USER_NAME (optionally EMAIL_ADDRESS and LANGUAGE_CODE for a person without an account). Binds: :TASK_ID, :WORKFLOW_ID, :DETAIL_PK, :APPLICATION_CODE, :PROCESS_CODE, :VALUE.'~');
    end if;

    if xxfnd_ddl_pkg.create_table('XXFND_NOTIFY_RULES', q'~create table xxfnd_notify_rules (
    rule_id                number generated by default on null as identity,
    event_code             varchar2(30)   not null,
    application_code       varchar2(30),
    process_code           varchar2(255),
    recipient_type_code    varchar2(30)   not null,
    recipient_value        varchar2(255),
    channel_code           varchar2(30)   not null,
    template_code          varchar2(50),
    enabled_flag           varchar2(1)    default 'Y' not null,
    created_by             varchar2(255)  not null,
    creation_date          timestamp      not null,
    last_updated_by        varchar2(255)  not null,
    last_update_date       timestamp      not null,
    last_update_login      varchar2(255),
    object_version_number  number         default 1 not null,
    constraint xxfnd_notify_rules_pk primary key (rule_id),
    constraint xxfnd_notify_rules_fk1 foreign key (event_code) references xxfnd_notify_events (event_code),
    constraint xxfnd_notify_rules_fk2 foreign key (recipient_type_code) references xxfnd_notify_recipient_types (recipient_type_code),
    constraint xxfnd_notify_rules_fk3 foreign key (channel_code) references xxfnd_notify_channels (channel_code),
    constraint xxfnd_notify_rules_fk4 foreign key (template_code) references xxfnd_notification_templates (template_code),
    constraint xxfnd_notify_rules_ck1 check (enabled_flag in ('Y','N'))
)~') then
        xxfnd_ddl_pkg.run(q'~create unique index xxfnd_notify_rules_u1 on xxfnd_notify_rules (event_code, nvl(application_code, '#'), nvl(process_code, '#'), recipient_type_code, nvl(recipient_value, '#'), channel_code)~');
        xxfnd_ddl_pkg.run(q'~create index xxfnd_notify_rules_n1 on xxfnd_notify_rules (recipient_type_code)~');
        xxfnd_ddl_pkg.run(q'~create index xxfnd_notify_rules_n2 on xxfnd_notify_rules (channel_code)~');
        xxfnd_ddl_pkg.run(q'~create index xxfnd_notify_rules_n3 on xxfnd_notify_rules (template_code)~');
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_notify_rules is 'Release 84: who is told of an event on which channel. APPLICATION_CODE / PROCESS_CODE empty = every application / process; TEMPLATE_CODE empty = the event''s wording.'~');
    end if;

    if xxfnd_ddl_pkg.create_table('XXFND_NOTIFICATIONS', q'~create table xxfnd_notifications (
    notification_id        number generated by default on null as identity,
    event_code             varchar2(30)   not null,
    channel_code           varchar2(30)   not null,
    rule_id                number,
    application_code       varchar2(30),
    process_code           varchar2(255),
    user_name              varchar2(255),
    email_address          varchar2(320),
    language_code          varchar2(10)   default 'en' not null,
    subject                varchar2(500)  not null,
    message_text           clob,
    link_url               varchar2(4000),
    link_label             varchar2(100),
    task_id                number,
    workflow_id            number,
    detail_pk              varchar2(400),
    status_code            varchar2(30)   default 'PENDING' not null,
    status_text            varchar2(4000),
    mail_id                number,
    read_date              timestamp,
    created_by             varchar2(255)  not null,
    creation_date          timestamp      not null,
    last_updated_by        varchar2(255)  not null,
    last_update_date       timestamp      not null,
    last_update_login      varchar2(255),
    object_version_number  number         default 1 not null,
    constraint xxfnd_notifications_pk primary key (notification_id),
    constraint xxfnd_notifications_fk1 foreign key (event_code) references xxfnd_notify_events (event_code),
    constraint xxfnd_notifications_fk2 foreign key (channel_code) references xxfnd_notify_channels (channel_code),
    constraint xxfnd_notifications_ck1 check (status_code in ('PENDING','SENT','SKIPPED','FAILED')),
    constraint xxfnd_notifications_ck2 check (user_name is not null or email_address is not null)
)~') then
        xxfnd_ddl_pkg.run(q'~create index xxfnd_notifications_n1 on xxfnd_notifications (user_name, channel_code, read_date)~');
        xxfnd_ddl_pkg.run(q'~create index xxfnd_notifications_n2 on xxfnd_notifications (event_code)~');
        xxfnd_ddl_pkg.run(q'~create index xxfnd_notifications_n3 on xxfnd_notifications (task_id)~');
        xxfnd_ddl_pkg.run(q'~create index xxfnd_notifications_n4 on xxfnd_notifications (channel_code)~');
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_notifications is 'Release 84: every notification made, one row per person and channel, with its delivery status (SKIPPED with the reason, e.g. e-mail switched off or no device subscribed). The IN_APP rows are the person''s notification list; READ_DATE is set when it is opened.'~');
    end if;
    for t in (select column_value table_name
                from table(apex_t_varchar2('XXFND_NOTIFY_CHANNELS', 'XXFND_NOTIFY_EVENTS', 'XXFND_NOTIFY_RECIPIENT_TYPES',
                                           'XXFND_NOTIFY_RULES', 'XXFND_NOTIFICATIONS'))) loop
        xxfnd_schema_pkg.create_who_trigger(t.table_name);
    end loop;
end;
/
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
