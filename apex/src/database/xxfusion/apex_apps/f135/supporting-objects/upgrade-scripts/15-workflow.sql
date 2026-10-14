--------------------------------------------------------------------------------
-- 15_workflow.sql  (release R12)
-- Processes and tasks run on native APEX Workflow and Task Definitions
-- (APEX_WORKFLOW, APEX_HUMAN_TASK); My Tasks is the APEX Unified Task List.
-- This script holds only what APEX leaves to the application:
--   XXFND_TASK_SETTINGS       deadlines and escalation per task definition (admin screen)
--   XXFND_TASK_ALERTS         reminders/escalations already sent (sent once)
--   XXFND_NOTIFY_PKG          e-mail from the admin-maintained notification templates, and e-mails per record
--                             (release 82: + XXFND_COMMUNICATION_PKG; table XXFND_COMMUNICATIONS created here)
--   XXFND_WORKFLOW_PKG        runtime, workflow / e-mail switches, participants, due dates, vacation rule,
--                             notifications, deadlines (release 82: + XXFND_WORKFLOW_SWITCH_PKG, XXFND_TASK_PKG)
--   XXFND_CONFIG_APPROVAL_PKG maker-checker changes as CONFIG_CHANGE approval tasks
-- It also retires the former custom workflow engine (idempotent; nothing to do
-- on a new install). Safe to run on install and on every upgrade.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Retire the former custom engine (XXFND_WF_* tables, package, view, mailer job)
--------------------------------------------------------------------------------
declare
    procedure run(p_sql in varchar2) is
    begin
        execute immediate p_sql;
    end run;
    function exists_(p_sql in varchar2) return boolean is
        l_count pls_integer;
    begin
        execute immediate p_sql into l_count;
        return l_count > 0;
    end exists_;
begin
    for j in (select job_name from user_scheduler_jobs where job_name in ('XXFND_WF_MAILER','XXFND_HCM_SYNC')) loop
        dbms_scheduler.drop_job(j.job_name, force => true);   -- replaced by APEX Automations
    end loop;
    run('drop package if exists xxfnd_wf_pkg');
    run('drop view if exists xxfnd_wf_items_v');
    if exists_(q'[select count(*) from user_constraints where constraint_name = 'XXFND_WF_DELEGATIONS_FK1']') then
        run('alter table xxfnd_wf_delegations drop constraint xxfnd_wf_delegations_fk1');
    end if;
    if exists_(q'[select count(*) from user_tab_columns where table_name = 'XXFND_WF_DELEGATIONS' and column_name = 'ITEM_TYPE']') then
        run('alter table xxfnd_wf_delegations rename column item_type to task_definition');
        run('alter table xxfnd_wf_delegations modify (task_definition varchar2(255))');
        xxfnd_audit_pkg.create_audit_trigger('XXFND_WF_DELEGATIONS');   -- its column list changed
    end if;
    -- Item types of the former engine mean nothing to APEX task definitions.
    run(q'[update xxfnd_wf_delegations set task_definition = null where task_definition in ('RFI','KYC_CASE')]');
    for t in (select column_value table_name
                from table(apex_t_varchar2('XXFND_WF_NOTIFICATIONS','XXFND_WF_ACTIVITY_HISTORY',
                                           'XXFND_WF_ITEMS','XXFND_WF_TRANSITIONS','XXFND_WF_ACTIVITIES',
                                           'XXFND_WF_PROCESSES','XXFND_WF_ITEM_TYPES'))) loop
        run('drop table if exists ' || t.table_name || ' cascade constraints purge');
    end loop;
    delete from xxfnd_lookup_values_tl where lookup_type in ('WF_ACTIVITY_TYPE','WF_RESULT','WF_ITEM_STATUS');
    delete from xxfnd_lookup_values    where lookup_type in ('WF_ACTIVITY_TYPE','WF_RESULT','WF_ITEM_STATUS');
    delete from xxfnd_lookup_types     where lookup_type in ('WF_ACTIVITY_TYPE','WF_RESULT','WF_ITEM_STATUS');
    delete from xxfnd_notification_templates_tl where template_code = 'WF_TASK_ASSIGNED';
    delete from xxfnd_notification_templates    where template_code = 'WF_TASK_ASSIGNED';
    commit;
end;
/

--------------------------------------------------------------------------------
-- Deadlines and escalation (Workflow Setup > Deadlines and Escalation)
--------------------------------------------------------------------------------
create table if not exists xxfnd_task_settings (
    task_definition        varchar2(255)  not null,
    due_days               number,
    reminder_days_before   number,
    escalation_role_code   varchar2(30),
    notify_on_create_flag  varchar2(1)    default 'Y' not null,
    description            varchar2(1000),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_task_settings_pk primary key (task_definition),
    constraint xxfnd_task_settings_fk1 foreign key (escalation_role_code) references xxfnd_roles (role_code),
    constraint xxfnd_task_settings_ck1 check (due_days > 0),
    constraint xxfnd_task_settings_ck2 check (reminder_days_before >= 0),
    constraint xxfnd_task_settings_ck3 check (notify_on_create_flag in ('Y','N'))
);
comment on table xxfnd_task_settings is 'Per APEX task definition (static ID): due date in days from creation, reminder before it, role that receives overdue tasks, e-mail on creation.';

create table if not exists xxfnd_task_alerts (
    task_id                number         not null,
    alert_type             varchar2(30)   not null,
    sent_date              timestamp      default systimestamp not null,
    constraint xxfnd_task_alerts_pk primary key (task_id, alert_type),
    constraint xxfnd_task_alerts_ck1 check (alert_type in ('REMINDER','ESCALATION'))
);
comment on table xxfnd_task_alerts is 'Deadline reminders and escalations already sent, so each goes out once per task.';

begin
    xxfnd_util_pkg.create_who_trigger('XXFND_TASK_SETTINGS');
    xxfnd_audit_pkg.create_audit_trigger('XXFND_TASK_SETTINGS');
    xxfnd_audit_pkg.create_audit_trigger('XXFND_WF_DELEGATIONS');
end;
/

--------------------------------------------------------------------------------
-- Communications table (release 74, R27; release 82: created here, before XXFND_NOTIFY_PKG that writes it)
--------------------------------------------------------------------------------
begin
    if xxfnd_ddl_pkg.create_table('XXFND_COMMUNICATIONS', q'~create table xxfnd_communications (
    communication_id       number generated by default on null as identity,
    application_code       varchar2(30)   not null,
    entity_name            varchar2(30)   not null,
    pk1_value              varchar2(100)  not null,
    rfi_id                 number,
    direction              varchar2(10)   not null,
    channel                varchar2(30)   default 'EMAIL' not null,
    from_address           varchar2(320),
    to_address             varchar2(4000),
    cc_address             varchar2(4000),
    subject                varchar2(500)  not null,
    body                   clob,
    communication_date     timestamp with time zone default systimestamp not null,
    status                 varchar2(30)   not null,
    source                 varchar2(30)   default 'MANUAL' not null,
    mail_id                number,
    external_message_id    varchar2(1000),
    conversation_id        varchar2(1000),
    in_reply_to_id         number,
    recorded_by            varchar2(255)  not null,
    created_by             varchar2(255)  not null,
    creation_date          timestamp      not null,
    last_updated_by        varchar2(255)  not null,
    last_update_date       timestamp      not null,
    last_update_login      varchar2(255),
    object_version_number  number         default 1 not null,
    constraint xxfnd_communications_pk primary key (communication_id),
    constraint xxfnd_communications_fk1 foreign key (in_reply_to_id) references xxfnd_communications (communication_id),
    constraint xxfnd_communications_ck1 check (direction in ('OUT','IN')),
    constraint xxfnd_communications_ck2 check (status in ('SENT','NOT_SENT','FAILED','RECEIVED')),
    constraint xxfnd_communications_ck3 check (source in ('MANUAL','APEX_MAIL','OUTLOOK'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_communications is 'E-mails with outside people per record (application, entity, key; optionally a request for information): sent from the application (APEX mail) or received and recorded (by hand now, Outlook later). NOT_SENT = recorded while e-mail is switched off.'~');
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_communications.conversation_id is 'Outlook conversation (thread) ID, filled by the Outlook integration later to match replies.'~');
        xxfnd_ddl_pkg.run('create index xxfnd_communications_n1 on xxfnd_communications (entity_name, pk1_value)');
        xxfnd_ddl_pkg.run('create index xxfnd_communications_n2 on xxfnd_communications (rfi_id)');
    end if;
    -- R23: the reply link (foreign key) is indexed
    xxfnd_ddl_pkg.ensure_index('XXFND_COMMUNICATIONS_N3',
        'create index xxfnd_communications_n3 on xxfnd_communications (in_reply_to_id)');
    xxfnd_schema_pkg.create_who_trigger('XXFND_COMMUNICATIONS');
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

-- Release 82: one message of the questions-and-answers history (XXFND_QA_HISTORY_V, script 24)
create or replace type xxfnd_qa_row force as object (
    application_code  varchar2(30),
    source_code       varchar2(255),
    source_type       varchar2(30),
    record_key        varchar2(4000),
    source_id         number,
    message_text      varchar2(4000),
    author            varchar2(255),
    message_date      timestamp with time zone
);
/
create or replace type xxfnd_qa_tab force as table of xxfnd_qa_row;
/

--------------------------------------------------------------------------------
-- Workflow and notifications (release 82: one package each). Both specs first: each body calls the other.
--------------------------------------------------------------------------------
create or replace package xxfnd_workflow_pkg authid definer as
    -- Release 82: one package for the Workflow component - the runtime (start, state, end), the workflow and
    -- e-mail switches (was XXFND_WORKFLOW_SWITCH_PKG) and the task helpers (was XXFND_TASK_PKG).

    ---------------------------------------------------------------- runtime
    -- Starts the APEX workflow p_static_id for the record p_detail_pk; returns the workflow ID.
    -- Release 84: a COMMON workflow (RFI, CONFIG_CHANGE) runs for another application's record: p_application_code is
    -- that application (workflow parameter APPLICATION_CODE; its switches and notification rules apply).
    function start_process(p_static_id        in varchar2,
                           p_detail_pk        in varchar2,
                           p_initiator        in varchar2 default null,
                           p_application_id   in number   default null,
                           p_application_code in varchar2 default null) return number;
    -- Release 84: the APEX ID of the COMMON application (it owns the shared workflows and task definitions).
    function common_application_id return number;
    -- Release 84: the application a workflow runs for (its APPLICATION_CODE parameter, else the workflow's own
    -- application).
    function workflow_application(p_workflow_id in number) return varchar2;
    -- ACTIVE, SUSPENDED, FAULTED, COMPLETED, TERMINATED ... (null when unknown).
    function state(p_workflow_id in number) return varchar2;
    -- Y while the workflow still runs (active, suspended or faulted).
    function is_running(p_workflow_id in number) return varchar2;
    -- Ends a running workflow and its open tasks; nothing when it already ended.
    procedure end_process(p_workflow_id in number);

    ---------------------------------------------------------------- switches
    c_auto_approved constant varchar2(100) := 'Auto-approved (workflow disabled)';
    -- Release 82: the request for information process (COMMON RFI) of every application in the Process Catalogue.
    c_rfi_process   constant varchar2(30)  := 'RFI';
    -- Y when the approval workflow of the process is on for the application (default: the running one); Y when
    -- the process is not registered.
    function workflow_enabled(p_process_code in varchar2, p_application_code in varchar2 default null) return varchar2;
    -- Y when e-mail is on for the instance, the application (default: the running one) and the process (when given).
    function email_enabled(p_process_code in varchar2 default null, p_application_code in varchar2 default null) return varchar2;
    -- The workflow process (static ID) an APEX task belongs to, else null.
    function process_of_task(p_task_id in number) return varchar2;
    -- One row per APEX workflow of every registered application, and its RFI process (new ones on, existing rows kept).
    procedure sync_processes;
    -- Release 82: e-mail on / off for the whole workspace (the COMMON row; page 147), MANAGE of WORKFLOW_SETUP.
    procedure set_workspace_email(p_enabled in varchar2);

    ---------------------------------------------------------------- tasks

    -- Empty parameter list for CREATE_TASK.
    c_no_parameters apex_human_task.t_task_parameters;

    -- Task participants: comma-separated user names (task definition participant expressions).
    function users_in_role(p_role_code in varchar2, p_exclude in varchar2 default null) return varchar2;
    function users_with_privilege(p_feature_code in varchar2, p_action in varchar2,
                                  p_exclude in varchar2 default null) return varchar2;
    -- Business administrators of every task: holders of WORKFLOW_MONITOR.MANAGE.
    function business_admins return varchar2;

    -- Due date from XXFND_TASK_SETTINGS (null = no deadline).
    function due_date(p_task_definition in varchar2) return timestamp with time zone;

    -- Creates a task of the current application with the configured due date.
    function create_task(p_task_definition in varchar2,
                         p_detail_pk       in varchar2,
                         p_subject         in varchar2 default null,
                         p_parameters      in apex_human_task.t_task_parameters default c_no_parameters) return number;

    -- Completes the open tasks of a definition for a record that the current user may complete.
    -- Release 84: p_application_id is the application of the task definition (default: the running one; the COMMON
    -- definitions: COMMON_APPLICATION_ID).
    procedure complete_open(p_task_definition in varchar2, p_detail_pk in varchar2, p_outcome in varchar2 default null,
                            p_application_id in number default null);
    -- Cancels the open tasks of a definition for a record (initiator or business administrator).
    procedure cancel_open(p_task_definition in varchar2, p_detail_pk in varchar2, p_application_id in number default null);

    -- Most recent comment on a task (e.g. the reason given when rejecting).
    function last_comment(p_task_id in number) return varchar2;

    -- Request Information on an approval notification goes to the task initiator (the requester); APEX does not let
    -- the initiator ask themselves. Y when the current user can ask the initiator of this task.
    function can_request_info(p_task_id in number) return varchar2;
    -- The open task of a definition for a record waiting for the current user's information (INFO_REQUESTED, the
    -- user is its initiator): the requester answers it with Submit Information on the same notification screen.
    function info_task(p_task_definition in varchar2, p_detail_pk in varchar2) return number;

    -- Task vacation rule procedure (set on every task definition): while a delegation in
    -- XXFND_WF_DELEGATIONS is active, the delegate is offered the delegator's tasks too.
    procedure vacation_rule(p_param  in  apex_human_task.t_vacation_rule_input,
                            p_result out apex_human_task.t_vacation_rule_result);

    -- Release 84: the task definition actions of every task definition call this on an APEX task event (p_trigger:
    -- CREATE, COMPLETE with the outcome, REQUEST_INFO, SUBMIT_INFO). The notification event of that trigger
    -- (XXFND_NOTIFY_EVENTS) is raised with the task's values; nothing when none is set up. CREATE is skipped when
    -- NOTIFY_ON_CREATE_FLAG is N for the task definition.
    procedure on_task_event(p_task_id in number, p_trigger in varchar2, p_outcome in varchar2 default null);
    -- Task definition action "on create" (kept for the applications' task definitions): ON_TASK_EVENT(CREATE).
    procedure notify_created(p_task_id in number);

    -- Daily Automation (COMMON "Task deadlines"; release 84: the tasks of every application): the deadline events
    -- REMINDER (REMINDER_DAYS_BEFORE the due date) and ESCALATION (once overdue). Each is raised once per task.
    procedure process_deadlines;

    ---------------------------------------------------------------- My Tasks and Workflow Monitor (release 82)
    -- Open tasks of the user (default: the signed-in one) in every application of the workspace (COMMON Home, D20).
    function open_task_count(p_user_name in varchar2 default null) return number;
    -- Workflow Monitor (D19): acts on a workflow of any application on anyone's behalf - SUSPEND, RESUME, RETRY or
    -- TERMINATE. Needs WORKFLOW_MONITOR.MANAGE (ORA-20164 otherwise).
    procedure monitor_workflow(p_workflow_id in number, p_action in varchar2);
    -- Workflow Monitor: REASSIGN (the task's owner becomes p_user_name), DELEGATE (p_user_name may also act on it) or
    -- RELEASE (back to its potential owners) a task of any application. Needs WORKFLOW_MONITOR.MANAGE.
    procedure monitor_task(p_task_id in number, p_action in varchar2, p_user_name in varchar2 default null);
    -- Release 84 (data security of the task pages 143 / 144): the record (detail key) of a task when the signed-in
    -- user takes part in it (participant, owner or initiator) or is a workflow administrator; null otherwise.
    function task_record(p_task_id in number) return varchar2;
    -- The comments of the APEX tasks (Request Information, Submit Information, decisions) of every application, for
    -- the questions-and-answers history XXFND_QA_HISTORY_V (the applications cannot be granted the APEX views).
    function task_messages return xxfnd_qa_tab pipelined;

end xxfnd_workflow_pkg;
/

create or replace package xxfnd_notify_pkg authid definer as
    -- Release 82: one package for notifications and e-mail with outside people (was XXFND_COMMUNICATION_PKG).

    -- Release 82: e-mails use the APEX Email Template XXFND_STANDARD of the COMMON application (the layout: #SUBJECT#,
    -- #MESSAGE#, #ACTION_URL#, #ACTION_LABEL#, #FOOTER#, #DIR#). XXFND_NOTIFICATION_TEMPLATES keeps only the wording:
    -- a subject and a plain-text message per event, translated in XXFND_NOTIFICATION_TEMPLATES_TL. The wording is in
    -- the recipient's language (English when not translated); Arabic is sent right to left. #TOKEN# placeholders are
    -- replaced from the JSON object P_TOKENS (plain values: the layout escapes them); the link is the token TASK_URL,
    -- RESPONSE_URL or LINK.
    c_layout constant varchar2(30) := 'XXFND_STANDARD';

    -- Sends notification template P_TEMPLATE_CODE to P_TO in P_LANGUAGE (default English). Does nothing when the
    -- template is disabled, the MAIL_FROM application setting is empty, or e-mail is off for the instance, the
    -- application or the workflow process (P_PROCESS_CODE, XXFND_WORKFLOW_PKG.EMAIL_ENABLED). Returns the APEX mail ID
    -- (null when nothing was sent).
    function send_message(p_template_code    in varchar2,
                          p_to               in varchar2,
                          p_tokens           in clob     default null,
                          p_language         in varchar2 default null,
                          p_process_code     in varchar2 default null,
                          p_application_code in varchar2 default null) return number;
    procedure send(p_template_code in varchar2, p_to in varchar2, p_tokens in clob default null,
                   p_process_code in varchar2 default null, p_language in varchar2 default null);
    -- Same, once per application user (comma-separated user names) that has an e-mail address, each in their language
    -- (XXFND_USERS.LANGUAGE_CODE).
    procedure send_to_users(p_template_code in varchar2, p_user_names in varchar2, p_tokens in clob default null,
                            p_process_code in varchar2 default null);
    -- The wording as it is sent (tokens without a value stay as #TOKEN#), for the Notifications screen preview.
    function preview_subject(p_template_code in varchar2, p_language in varchar2 default null,
                             p_tokens in clob default null) return varchar2;
    function preview_message(p_template_code in varchar2, p_language in varchar2 default null,
                             p_tokens in clob default null) return clob;
    -- "Send test to me": the wording in P_LANGUAGE to the current user's e-mail address, whatever the switches.
    procedure send_test(p_template_code in varchar2, p_language in varchar2 default null);
    -- The language of a user (XXFND_USERS.LANGUAGE_CODE), English when unknown.
    function user_language(p_user_name in varchar2) return varchar2;

    ---------------------------------------------------------------- notifications driven by data (release 84)
    -- Raises event P_EVENT_CODE (XXFND_NOTIFY_EVENTS). Every enabled rule of the event (XXFND_NOTIFY_RULES: for
    -- P_APPLICATION_CODE / P_PROCESS_CODE or for every one) on an enabled channel tells the people its recipient type
    -- returns (XXFND_NOTIFY_RECIPIENT_TYPES), each once per channel, in their language, with the event's link. Every
    -- notification is kept in XXFND_NOTIFICATIONS with its delivery status; a failing channel never stops the caller.
    -- P_TOKENS (JSON object): the values of the wording (#TOKEN#) and of the link (the event's LINK_TOKENS; a LINK
    -- value is used as the link itself).
    procedure raise_event(p_event_code       in varchar2,
                          p_application_code in varchar2 default null,
                          p_process_code     in varchar2 default null,
                          p_task_id          in number   default null,
                          p_workflow_id      in number   default null,
                          p_detail_pk        in varchar2 default null,
                          p_tokens           in clob     default null);
    -- The event raised by a trigger (an APEX task event CREATE / COMPLETE / REQUEST_INFO / SUBMIT_INFO, a deadline
    -- REMINDER / ESCALATION, an RFI step) and outcome; null when none is set up or it is disabled.
    function event_for(p_trigger_code in varchar2, p_outcome_code in varchar2 default null) return varchar2;
    -- The people a rule tells for a task / workflow / record (comma-separated user names or e-mail addresses), for
    -- the setup screen's "Test".
    function rule_recipients(p_rule_id in number, p_task_id in number default null, p_workflow_id in number default null,
                             p_detail_pk in varchar2 default null) return varchar2;
    -- The delivery procedures of the channels (XXFND_NOTIFY_CHANNELS.DELIVERY_PROCEDURE): each sets the status of the
    -- notification (SENT, SKIPPED with the reason, FAILED with the error).
    procedure deliver_in_app(p_notification_id in number);
    procedure deliver_email(p_notification_id in number);
    procedure deliver_push(p_notification_id in number);
    procedure deliver_fusion(p_notification_id in number);
    -- Y when the person (default: the signed-in one) has a device subscribed to the COMMON push notifications.
    function has_push(p_user_name in varchar2 default null) return varchar2;
    -- The signed-in person's notification list (the bell): unread count, mark one / all as read.
    function unread_count(p_user_name in varchar2 default null) return number;
    procedure mark_read(p_notification_id in number);
    procedure mark_all_read;
    -- A setting of the COMMON application (Shared Components > Application Settings), e.g. MAIL_FROM, MAIL_FOOTER.
    function common_setting(p_name in varchar2) return varchar2;

    ---------------------------------------------------------------- communications (e-mails per record)
    -- Sends an e-mail for a record and keeps it (status SENT; NOT_SENT when e-mail is switched off for the instance or
    -- the application, or MAIL_FROM is not set - the e-mail is still recorded). P_TEMP_FILE_NAME: an uploaded file
    -- (APEX temporary file) sent with it and kept as the communication's attachment. Returns the communication ID.
    function send_email(p_application_code in varchar2,
                        p_entity_name      in varchar2,
                        p_pk1_value        in varchar2,
                        p_to               in varchar2,
                        p_subject          in varchar2,
                        p_body             in clob,
                        p_cc               in varchar2 default null,
                        p_rfi_id           in number   default null,
                        p_in_reply_to_id   in number   default null,
                        p_temp_file_name   in varchar2 default null) return number;
    -- Records an e-mail received from an outside person. Typed by a person now (SOURCE MANUAL); the Outlook
    -- integration later calls it with SOURCE OUTLOOK and the message / conversation IDs. Returns the communication ID.
    function record_received(p_application_code    in varchar2,
                             p_entity_name         in varchar2,
                             p_pk1_value           in varchar2,
                             p_from                in varchar2,
                             p_subject             in varchar2,
                             p_body                in clob,
                             p_received_date       in timestamp with time zone default systimestamp,
                             p_rfi_id              in number   default null,
                             p_in_reply_to_id      in number   default null,
                             p_source              in varchar2 default 'MANUAL',
                             p_external_message_id in varchar2 default null,
                             p_conversation_id     in varchar2 default null,
                             p_temp_file_name      in varchar2 default null) return number;
    -- Keeps an e-mail another common service already sent (e.g. the RFI e-mail from its template), so it shows with
    -- the record's communications.
    procedure record_sent(p_application_code in varchar2,
                          p_entity_name      in varchar2,
                          p_pk1_value        in varchar2,
                          p_to               in varchar2,
                          p_subject          in varchar2,
                          p_body             in clob,
                          p_rfi_id           in number default null,
                          p_mail_id          in number default null);
    -- The rule of an e-mail before it is sent or recorded (null when it is fine).
    function email_error(p_direction in varchar2, p_address in varchar2, p_subject in varchar2, p_body in clob) return varchar2;
end xxfnd_notify_pkg;
/

create or replace package body xxfnd_notify_pkg as
    -- communications: the attachment entity of an e-mail (release 82: moved to the top with the merge)
    c_entity constant varchar2(30) := 'XXFND_COMMUNICATIONS';
    -- release 84: the people of a notification rule
    type t_person is record (user_name varchar2(255), email_address varchar2(320), language_code varchar2(10));
    type t_people is table of t_person index by pls_integer;
    -- the notification being delivered with a link that must not be kept (a one-time answer link): the delivery
    -- procedures send these, the table keeps the masked wording
    g_secret_id      number;
    g_secret_message clob;
    g_secret_link    varchar2(4000);
    c_masked_link    constant varchar2(30) := '[secure link]';


    function user_language(p_user_name in varchar2) return varchar2 is
        l_lang varchar2(10);
    begin
        select max(language_code) into l_lang from xxfnd_users where user_name = upper(p_user_name);
        return nvl(l_lang, 'en');
    end user_language;

    -- The wording of a template in a language (English, then the base row, when not translated); null when the
    -- template does not exist or is disabled (p_enabled_only).
    procedure wording(p_template_code in varchar2, p_language in varchar2, p_enabled_only in boolean,
                      p_subject out varchar2, p_message out clob) is
        -- release 82: wording only; a row kept from before release 82 may still hold HTML: its tags are dropped
        function plain(p_text in clob) return clob is
        begin
            return regexp_replace(regexp_replace(p_text, '<br\s*/?>|</p>|</div>|</li>', chr(10), 1, 0, 'i'), '<[^>]+>', '');
        end plain;
    begin
        for w in (select coalesce(t.subject, e.subject, n.subject) subject,
                         t.message_text t_text, t.body_html t_html, e.message_text e_text, e.body_html e_html,
                         n.message_text n_text, n.body_html n_html
                    from xxfnd_notification_templates n
                    left join xxfnd_notification_templates_tl t
                      on t.template_code = n.template_code and t.language_code = nvl(p_language, 'en')
                    left join xxfnd_notification_templates_tl e
                      on e.template_code = n.template_code and e.language_code = 'en'
                   where n.template_code = p_template_code
                     and (n.enabled_flag = 'Y' or not p_enabled_only)) loop
            p_subject := w.subject;
            p_message := coalesce(w.t_text, plain(w.t_html), w.e_text, plain(w.e_html), w.n_text, plain(w.n_html));
        end loop;
    end wording;

    -- release 84: the link label is wording too (XXFND_NOTIFICATION_TEMPLATES.ACTION_LABEL per language; before release 84 a fixed label in this package)
    function action_label(p_template_code in varchar2, p_language in varchar2) return varchar2 is
        l_label varchar2(100);
    begin
        select max(coalesce(t.action_label, e.action_label, n.action_label))
          into l_label
          from xxfnd_notification_templates n
          left join xxfnd_notification_templates_tl t
            on t.template_code = n.template_code and t.language_code = nvl(p_language, 'en')
          left join xxfnd_notification_templates_tl e
            on e.template_code = n.template_code and e.language_code = 'en'
         where n.template_code = p_template_code;
        return l_label;
    end action_label;

    function common_app_id return number is
        l_id number;
    begin
        select max(apex_application_id) into l_id from xxfnd_applications where application_code = 'COMMON';
        return l_id;
    end common_app_id;

    -- release 84: the settings are read from the APEX dictionary for the COMMON application, whichever application
    -- raised the notification
    function common_setting(p_name in varchar2) return varchar2 is
        l_value varchar2(4000);
        l_app   number := common_app_id;
    begin
        select max(value) into l_value
          from apex_application_settings
         where application_id = l_app and name = upper(p_name);
        return l_value;
    end common_setting;

    -- the placeholders of the XXFND_STANDARD layout: the sender's footer is the COMMON setting MAIL_FOOTER
    function placeholders(p_subject in varchar2, p_message in clob, p_url in varchar2, p_label in varchar2,
                          p_language in varchar2) return clob is
        l_json json_object_t := json_object_t();
    begin
        l_json.put('SUBJECT', p_subject);
        l_json.put('MESSAGE', p_message);
        l_json.put('ACTION_URL', p_url);
        l_json.put('ACTION_LABEL', case when p_url is not null then p_label end);
        l_json.put('FOOTER', common_setting('MAIL_FOOTER'));
        l_json.put('DIR', case when p_language = 'ar' then 'rtl' else 'ltr' end);
        return l_json.to_clob;
    end placeholders;

    function deliver(p_to in varchar2, p_subject in varchar2, p_message in clob, p_url in varchar2,
                     p_label in varchar2, p_language in varchar2) return number is
    begin
        return apex_mail.send(
                   p_to                 => p_to,
                   p_from               => common_setting('MAIL_FROM'),
                   p_template_static_id => c_layout,
                   p_placeholders       => placeholders(p_subject, p_message, p_url, p_label, p_language),
                   p_application_id     => common_app_id);
    end deliver;

    -- the link of a token set (the older wording carries it as TASK_URL or RESPONSE_URL)
    function token_link(p_tokens in clob) return varchar2 is
        l_tokens json_object_t;
    begin
        if p_tokens is null then
            return null;
        end if;
        l_tokens := json_object_t.parse(p_tokens);
        return coalesce(l_tokens.get_string('LINK'), l_tokens.get_string('TASK_URL'), l_tokens.get_string('RESPONSE_URL'));
    end token_link;

    function send_message(p_template_code    in varchar2,
                          p_to               in varchar2,
                          p_tokens           in clob     default null,
                          p_language         in varchar2 default null,
                          p_process_code     in varchar2 default null,
                          p_application_code in varchar2 default null) return number is
        l_subject varchar2(4000);
        l_message clob;
        l_lang    varchar2(10) := nvl(p_language, 'en');
    begin
        if p_to is null or common_setting('MAIL_FROM') is null
           or xxfnd_workflow_pkg.email_enabled(p_process_code, p_application_code) = 'N' then   -- e-mail switched off
            return null;
        end if;
        wording(p_template_code, l_lang, true, l_subject, l_message);
        if l_subject is null then
            return null;   -- no such template, or disabled
        end if;
        if p_tokens is not null then
            l_subject := dbms_lob.substr(xxfnd_util_pkg.replace_tokens(l_subject, p_tokens), 500, 1);
            l_message := xxfnd_util_pkg.replace_tokens(l_message, p_tokens);
        end if;
        return deliver(p_to, l_subject, l_message, token_link(p_tokens), action_label(p_template_code, l_lang), l_lang);
    end send_message;

    procedure send(p_template_code in varchar2, p_to in varchar2, p_tokens in clob default null,
                   p_process_code in varchar2 default null, p_language in varchar2 default null) is
        l_mail_id number;
    begin
        l_mail_id := send_message(p_template_code, p_to, p_tokens, p_language, p_process_code);
    end send;

    procedure send_to_users(p_template_code in varchar2, p_user_names in varchar2, p_tokens in clob default null,
                            p_process_code in varchar2 default null) is
    begin
        for u in (select e.email_address, max(nvl(us.language_code, 'en')) language_code
                    from xxfnd_employees e
                    left join xxfnd_users us on us.user_name = e.user_name
                   where e.user_name in (select upper(trim(column_value)) from table(apex_string.split(p_user_names, ',')))
                     and e.enabled_flag = 'Y'
                     and e.email_address is not null
                   group by e.email_address) loop
            send(p_template_code, u.email_address, p_tokens, p_process_code, u.language_code);
        end loop;
    end send_to_users;

    function preview_subject(p_template_code in varchar2, p_language in varchar2 default null,
                             p_tokens in clob default null) return varchar2 is
        l_subject varchar2(4000);
        l_message clob;
    begin
        wording(p_template_code, nvl(p_language, 'en'), false, l_subject, l_message);
        return case when p_tokens is null then l_subject
                    else dbms_lob.substr(xxfnd_util_pkg.replace_tokens(l_subject, p_tokens), 4000, 1) end;
    end preview_subject;

    function preview_message(p_template_code in varchar2, p_language in varchar2 default null,
                             p_tokens in clob default null) return clob is
        l_subject varchar2(4000);
        l_message clob;
    begin
        wording(p_template_code, nvl(p_language, 'en'), false, l_subject, l_message);
        return case when p_tokens is null then l_message else xxfnd_util_pkg.replace_tokens(l_message, p_tokens) end;
    end preview_message;

    procedure send_test(p_template_code in varchar2, p_language in varchar2 default null) is
        l_to      varchar2(320);
        l_subject varchar2(4000);
        l_message clob;
        l_mail_id number;
    begin
        select max(e.email_address) into l_to from xxfnd_employees e where e.user_name = xxfnd_util_pkg.current_user;
        if l_to is null then
            select max(email_address) into l_to from xxfnd_users where user_name = xxfnd_util_pkg.current_user;
        end if;
        if l_to is null then
            raise_application_error(-20162, 'You have no e-mail address: the test cannot be sent.');
        end if;
        if common_setting('MAIL_FROM') is null then
            raise_application_error(-20163, 'The sender address (application setting MAIL_FROM) is not set.');
        end if;
        wording(p_template_code, nvl(p_language, 'en'), false, l_subject, l_message);
        l_mail_id := deliver(l_to, '[Test] ' || l_subject, l_message, null, null, nvl(p_language, 'en'));
        apex_mail.push_queue;
    end send_test;


    ---------------------------------------------------------------- notifications driven by data (release 84)

    function event_for(p_trigger_code in varchar2, p_outcome_code in varchar2 default null) return varchar2 is
        l_event xxfnd_notify_events.event_code%type;
    begin
        select max(event_code) into l_event
          from xxfnd_notify_events
         where trigger_code = upper(p_trigger_code)
           and nvl(outcome_code, '#') = nvl(upper(p_outcome_code), '#')
           and enabled_flag = 'Y';
        return l_event;
    end event_for;

    -- the people of a recipient type: its query, run with the binds it uses
    function people(p_recipient_type in varchar2, p_value in varchar2, p_task_id in number, p_workflow_id in number,
                    p_detail_pk in varchar2, p_application_code in varchar2, p_process_code in varchar2) return t_people is
        l_query  xxfnd_notify_recipient_types.recipient_query%type;
        l_cur    integer;
        l_cols   dbms_sql.desc_tab2;
        l_ncol   integer;
        l_rows   integer;
        l_pos    apex_t_varchar2 := apex_t_varchar2(null, null, null);   -- column positions: user, e-mail, language
        l_val    varchar2(4000);
        l_people t_people;
        l_i      pls_integer := 0;
        procedure bind(p_name in varchar2, p_bind_value in varchar2) is
        begin
            if regexp_like(l_query, ':' || p_name || '([^A-Za-z0-9_$#]|$)', 'i') then
                dbms_sql.bind_variable(l_cur, ':' || p_name, p_bind_value);
            end if;
        end bind;
    begin
        select recipient_query into l_query from xxfnd_notify_recipient_types where recipient_type_code = p_recipient_type;
        l_cur := dbms_sql.open_cursor;
        begin
            dbms_sql.parse(l_cur, l_query, dbms_sql.native);
            bind('TASK_ID', to_char(p_task_id));
            bind('WORKFLOW_ID', to_char(p_workflow_id));
            bind('DETAIL_PK', p_detail_pk);
            bind('APPLICATION_CODE', p_application_code);
            bind('PROCESS_CODE', p_process_code);
            bind('VALUE', p_value);
            dbms_sql.describe_columns2(l_cur, l_ncol, l_cols);
            for c in 1 .. l_ncol loop
                case upper(l_cols(c).col_name)
                    when 'USER_NAME'     then l_pos(1) := c;
                    when 'EMAIL_ADDRESS' then l_pos(2) := c;
                    when 'LANGUAGE_CODE' then l_pos(3) := c;
                    else null;
                end case;
                dbms_sql.define_column(l_cur, c, l_val, 4000);
            end loop;
            l_rows := dbms_sql.execute(l_cur);
            while dbms_sql.fetch_rows(l_cur) > 0 loop
                l_i := l_i + 1;
                for k in 1 .. 3 loop
                    if l_pos(k) is not null then
                        dbms_sql.column_value(l_cur, to_number(l_pos(k)), l_val);
                        case k
                            when 1 then l_people(l_i).user_name     := upper(l_val);
                            when 2 then l_people(l_i).email_address := l_val;
                            else        l_people(l_i).language_code := l_val;
                        end case;
                    end if;
                end loop;
                if l_people(l_i).user_name is null and l_people(l_i).email_address is null then
                    l_people.delete(l_i);
                    l_i := l_i - 1;
                end if;
            end loop;
            dbms_sql.close_cursor(l_cur);
        exception
            when others then
                if dbms_sql.is_open(l_cur) then
                    dbms_sql.close_cursor(l_cur);
                end if;
                raise;
        end;
        return l_people;
    end people;

    function rule_recipients(p_rule_id in number, p_task_id in number default null, p_workflow_id in number default null,
                             p_detail_pk in varchar2 default null) return varchar2 is
        l_rule   xxfnd_notify_rules%rowtype;
        l_people t_people;
        l_list   varchar2(32767);
    begin
        select * into l_rule from xxfnd_notify_rules where rule_id = p_rule_id;
        l_people := people(l_rule.recipient_type_code, l_rule.recipient_value, p_task_id, p_workflow_id, p_detail_pk,
                           l_rule.application_code, l_rule.process_code);
        for i in 1 .. l_people.count loop
            l_list := l_list || case when l_list is not null then ', ' end
                   || coalesce(l_people(i).user_name, l_people(i).email_address);
        end loop;
        return substr(l_list, 1, 4000);
    end rule_recipients;

    -- the link of an event: page LINK_PAGE_ALIAS of the event's application (empty = the task's application), its
    -- items set from the event values LINK_TOKENS; a LINK value given by the caller wins
    function event_link(p_event in xxfnd_notify_events%rowtype, p_task_id in number, p_application_code in varchar2,
                        p_tokens in clob) return varchar2 is
        l_tokens json_object_t := case when p_tokens is not null then json_object_t.parse(p_tokens) end;
        l_app    number;
        l_values varchar2(4000);
    begin
        if l_tokens is not null and l_tokens.get_string('LINK') is not null then
            return l_tokens.get_string('LINK');
        end if;
        if p_event.link_page_alias is null then
            return null;
        end if;
        select max(apex_application_id) into l_app from xxfnd_applications
         where application_code = coalesce(p_event.link_application_code, p_application_code);
        if l_app is null and p_task_id is not null then
            select max(application_id) into l_app from apex_tasks where task_id = p_task_id;
        end if;
        for t in (select trim(column_value) name from table(apex_string.split(p_event.link_tokens, ','))) loop
            l_values := l_values || case when l_values is not null then ',' end
                     || case when l_tokens is not null then l_tokens.get_string(t.name) end;
        end loop;
        return apex_page.get_url(p_application  => to_char(l_app),
                                 p_page         => p_event.link_page_alias,
                                 p_session      => case when p_event.link_public_flag = 'Y' then 0 end,
                                 p_items        => p_event.link_items,
                                 p_values       => l_values,
                                 p_plain_url    => true,
                                 p_absolute_url => true);
    exception
        when others then
            return null;   -- no APEX context (e.g. a script): the notification goes without its link
    end event_link;

    procedure set_status(p_notification_id in number, p_status in varchar2, p_text in varchar2 default null,
                         p_mail_id in number default null) is
    begin
        update xxfnd_notifications
           set status_code = p_status, status_text = substr(p_text, 1, 4000), mail_id = nvl(p_mail_id, mail_id)
         where notification_id = p_notification_id;
    end set_status;

    procedure deliver_one(p_notification_id in number, p_procedure in varchar2) is
    begin
        execute immediate 'begin ' || dbms_assert.qualified_sql_name(p_procedure) || '(:id); end;' using p_notification_id;
    exception
        when others then
            -- a failing channel never stops the business step that raised the event
            set_status(p_notification_id, 'FAILED', sqlerrm);
    end deliver_one;

    procedure raise_event_(p_event_code       in varchar2,
                           p_application_code in varchar2,
                           p_process_code     in varchar2,
                           p_task_id          in number,
                           p_workflow_id      in number,
                           p_detail_pk        in varchar2,
                           p_tokens           in clob) is
        l_event   xxfnd_notify_events%rowtype;
        l_people  t_people;
        l_done    apex_t_varchar2 := apex_t_varchar2();
        l_key     varchar2(1000);
        l_link    varchar2(4000);
        l_tokens  json_object_t;
        l_subject varchar2(4000);
        l_message clob;
        l_shown   clob;
        l_lang    varchar2(10);
        l_email   varchar2(320);
        l_label   varchar2(100);
        l_id      number;
    begin
        begin
            select * into l_event from xxfnd_notify_events where event_code = p_event_code and enabled_flag = 'Y';
        exception
            when no_data_found then
                return;   -- not set up, or switched off
        end;
        l_link := event_link(l_event, p_task_id, p_application_code, p_tokens);
        l_tokens := case when p_tokens is not null then json_object_t.parse(p_tokens) else json_object_t() end;
        -- the older wording names the link TASK_URL or RESPONSE_URL
        l_tokens.put('LINK', l_link);
        l_tokens.put('TASK_URL', l_link);
        l_tokens.put('RESPONSE_URL', l_link);
        for r in (select r.rule_id, r.recipient_type_code, r.recipient_value, r.channel_code,
                         nvl(r.template_code, l_event.template_code) template_code, c.delivery_procedure
                    from xxfnd_notify_rules r
                    join xxfnd_notify_channels c on c.channel_code = r.channel_code
                   where r.event_code = l_event.event_code
                     and r.enabled_flag = 'Y'
                     and c.enabled_flag = 'Y'
                     and (r.application_code is null or r.application_code = p_application_code)
                     and (r.process_code is null or r.process_code = upper(p_process_code))
                   order by c.display_sequence, r.rule_id) loop
            l_people := people(r.recipient_type_code, r.recipient_value, p_task_id, p_workflow_id, p_detail_pk,
                               p_application_code, upper(p_process_code));
            for i in 1 .. l_people.count loop
                l_key := r.channel_code || '|' || coalesce(l_people(i).user_name, lower(l_people(i).email_address));
                continue when l_key member of l_done;
                l_done.extend;
                l_done(l_done.count) := l_key;
                l_lang := coalesce(l_people(i).language_code,
                                   case when l_people(i).user_name is not null then user_language(l_people(i).user_name) end, 'en');
                wording(r.template_code, l_lang, true, l_subject, l_message);
                continue when l_subject is null;   -- the wording is switched off
                l_subject := dbms_lob.substr(xxfnd_util_pkg.replace_tokens(l_subject, l_tokens.to_clob), 500, 1);
                l_message := xxfnd_util_pkg.replace_tokens(l_message, l_tokens.to_clob);
                if l_event.link_public_flag = 'Y' and l_link is not null then
                    -- a one-time answer link is sent, never kept
                    l_shown := replace(l_message, l_link, c_masked_link);
                else
                    l_shown := l_message;
                end if;
                l_email := l_people(i).email_address;
                if l_email is null and l_people(i).user_name is not null then
                    select max(email_address) into l_email from xxfnd_employees
                     where user_name = l_people(i).user_name and enabled_flag = 'Y';
                end if;
                l_label := action_label(r.template_code, l_lang);
                insert into xxfnd_notifications (event_code, channel_code, rule_id, application_code, process_code,
                                                 user_name, email_address, language_code, subject, message_text,
                                                 link_url, link_label, task_id, workflow_id, detail_pk)
                values (l_event.event_code, r.channel_code, r.rule_id, p_application_code, upper(p_process_code),
                        l_people(i).user_name, l_email, l_lang, nvl(l_subject, l_event.event_name), l_shown,
                        case when l_event.link_public_flag = 'Y' and l_link is not null then c_masked_link else l_link end,
                        l_label, p_task_id, p_workflow_id, p_detail_pk)
                returning notification_id into l_id;
                g_secret_id      := l_id;
                g_secret_message := l_message;
                g_secret_link    := l_link;
                deliver_one(l_id, r.delivery_procedure);
                g_secret_id      := null;
                g_secret_message := null;
                g_secret_link    := null;
            end loop;
        end loop;
    end raise_event_;

    procedure raise_event(p_event_code       in varchar2,
                          p_application_code in varchar2 default null,
                          p_process_code     in varchar2 default null,
                          p_task_id          in number   default null,
                          p_workflow_id      in number   default null,
                          p_detail_pk        in varchar2 default null,
                          p_tokens           in clob     default null) is
    begin
        -- the setup (wording, rules, people) is read whoever raises the event: a task action runs in the workflow's
        -- background session (no user), where the data security of the setup tables would hide it
        xxfnd_vpd_pkg.begin_trusted;
        raise_event_(p_event_code, p_application_code, p_process_code, p_task_id, p_workflow_id, p_detail_pk, p_tokens);
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end raise_event;

    procedure deliver_in_app(p_notification_id in number) is
        l_user xxfnd_notifications.user_name%type;
    begin
        select user_name into l_user from xxfnd_notifications where notification_id = p_notification_id;
        if l_user is null then
            set_status(p_notification_id, 'SKIPPED', 'A person without an account has no notification list.');
        else
            set_status(p_notification_id, 'SENT');
        end if;
    end deliver_in_app;

    procedure deliver_email(p_notification_id in number) is
        l_n       xxfnd_notifications%rowtype;
        l_mail_id number;
    begin
        select * into l_n from xxfnd_notifications where notification_id = p_notification_id;
        if l_n.email_address is null then
            set_status(p_notification_id, 'SKIPPED', 'No e-mail address.');
        elsif common_setting('MAIL_FROM') is null then
            set_status(p_notification_id, 'SKIPPED', 'The sender address (COMMON setting MAIL_FROM) is not set.');
        elsif xxfnd_workflow_pkg.email_enabled(l_n.process_code, l_n.application_code) = 'N' then
            set_status(p_notification_id, 'SKIPPED', 'E-mail is switched off for this process or application.');
        else
            l_mail_id := deliver(l_n.email_address, l_n.subject,
                                 case when g_secret_id = p_notification_id then g_secret_message else l_n.message_text end,
                                 case when g_secret_id = p_notification_id then g_secret_link else l_n.link_url end,
                                 l_n.link_label, l_n.language_code);
            set_status(p_notification_id, 'SENT', null, l_mail_id);
        end if;
    end deliver_email;

    procedure deliver_push(p_notification_id in number) is
        l_n xxfnd_notifications%rowtype;
    begin
        select * into l_n from xxfnd_notifications where notification_id = p_notification_id;
        if l_n.user_name is null then
            set_status(p_notification_id, 'SKIPPED', 'A person without an account has no device subscribed.');
        elsif not apex_pwa.has_push_subscription(p_application_id => common_app_id, p_user_name => l_n.user_name) then
            set_status(p_notification_id, 'SKIPPED', 'No device of this person is subscribed to push notifications.');
        else
            apex_pwa.send_push_notification(p_application_id => common_app_id,
                                            p_user_name      => l_n.user_name,
                                            p_title          => l_n.subject,
                                            p_body           => dbms_lob.substr(l_n.message_text, 1000, 1),
                                            p_target_url     => l_n.link_url);
            set_status(p_notification_id, 'SENT');
        end if;
    end deliver_push;

    procedure deliver_fusion(p_notification_id in number) is
        l_n       xxfnd_notifications%rowtype;
        l_purpose xxfnd_notify_channels.integration_purpose%type;
        l_body    json_object_t := json_object_t();
        l_resp    clob;
    begin
        select * into l_n from xxfnd_notifications where notification_id = p_notification_id;
        select max(integration_purpose) into l_purpose from xxfnd_notify_channels where channel_code = l_n.channel_code;
        if l_n.user_name is null then
            set_status(p_notification_id, 'SKIPPED', 'A person without an account is not a Fusion user.');
            return;
        end if;
        l_body.put('userName', l_n.user_name);
        l_body.put('title', l_n.subject);
        l_body.put('message', dbms_lob.substr(l_n.message_text, 4000, 1));
        l_body.put('link', l_n.link_url);
        l_resp := xxfnd_integration_pkg.call(p_purpose_code => l_purpose, p_http_method => 'POST', p_body => l_body.to_clob,
                                             p_entity_name  => 'XXFND_NOTIFICATIONS', p_pk1_value => to_char(p_notification_id));
        set_status(p_notification_id, 'SENT');
    end deliver_fusion;

    function has_push(p_user_name in varchar2 default null) return varchar2 is
    begin
        return case when apex_pwa.has_push_subscription(p_application_id => common_app_id,
                                                        p_user_name => upper(nvl(p_user_name, xxfnd_util_pkg.current_user)))
                    then 'Y' else 'N' end;
    exception
        when others then
            return 'N';   -- not a progressive web app (push not set up)
    end has_push;

    function unread_count(p_user_name in varchar2 default null) return number is
        l_n number;
    begin
        select count(*) into l_n
          from xxfnd_notifications n
          join xxfnd_notify_channels c on c.channel_code = n.channel_code and c.inbox_flag = 'Y'
         where n.user_name = upper(nvl(p_user_name, xxfnd_util_pkg.current_user))
           and n.status_code = 'SENT' and n.read_date is null;
        return l_n;
    end unread_count;

    procedure mark_read(p_notification_id in number) is
    begin
        -- only the person's own notification
        update xxfnd_notifications set read_date = systimestamp
         where notification_id = p_notification_id and user_name = upper(xxfnd_util_pkg.current_user)
           and read_date is null;
    end mark_read;

    procedure mark_all_read is
    begin
        update xxfnd_notifications set read_date = systimestamp
         where user_name = upper(xxfnd_util_pkg.current_user) and read_date is null
           and channel_code in (select channel_code from xxfnd_notify_channels where inbox_flag = 'Y');
    end mark_all_read;


    ---------------------------------------------------------------- communications (e-mails per record)


    function valid_addresses(p_list in varchar2) return boolean is
    begin
        for a in (select trim(column_value) addr from table(apex_string.split(replace(p_list, ';', ','), ','))
                   where trim(column_value) is not null) loop
            if not regexp_like(a.addr, '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$') then
                return false;
            end if;
        end loop;
        return true;
    end valid_addresses;

    function email_error(p_direction in varchar2, p_address in varchar2, p_subject in varchar2, p_body in clob) return varchar2 is
    begin
        if trim(p_address) is null then
            return case when p_direction = 'OUT' then 'Enter who the e-mail goes to.' else 'Enter who sent the e-mail.' end;
        elsif not valid_addresses(p_address) then
            return 'Enter valid e-mail addresses (separate several with a comma).';
        elsif trim(p_subject) is null then
            return 'Enter the subject.';
        elsif p_body is null or dbms_lob.getlength(p_body) = 0 then
            return 'Enter the message.';
        end if;
        return null;
    end email_error;

    procedure keep_file(p_communication_id in number, p_temp_file_name in varchar2, p_application_code in varchar2) is
        l_id number;
    begin
        if p_temp_file_name is not null then
            l_id := xxfnd_attach_pkg.add_file(p_entity_name    => c_entity,
                                              p_pk1_value      => to_char(p_communication_id),
                                              p_category_code  => 'OTHER',
                                              p_temp_file_name => p_temp_file_name,
                                              p_title          => 'E-mail attachment');
        end if;
    end keep_file;

    function send_email(p_application_code in varchar2,
                        p_entity_name      in varchar2,
                        p_pk1_value        in varchar2,
                        p_to               in varchar2,
                        p_subject          in varchar2,
                        p_body             in clob,
                        p_cc               in varchar2 default null,
                        p_rfi_id           in number   default null,
                        p_in_reply_to_id   in number   default null,
                        p_temp_file_name   in varchar2 default null) return number is
        l_error   varchar2(4000) := email_error('OUT', p_to, p_subject, p_body);
        l_from    varchar2(320)  := common_setting('MAIL_FROM');
        l_status  varchar2(30)   := 'NOT_SENT';
        l_mail_id number;
        l_id      number;
    begin
        if l_error is not null then
            raise_application_error(-20540, l_error);
        end if;
        if l_from is not null and xxfnd_workflow_pkg.email_enabled(null, p_application_code) = 'Y' then
            l_mail_id := apex_mail.send(p_to => p_to, p_cc => p_cc, p_from => l_from, p_subj => substr(p_subject, 1, 500),
                                        p_body => p_body);
            for f in (select filename, mime_type, blob_content from apex_application_temp_files
                       where name = p_temp_file_name) loop
                apex_mail.add_attachment(p_mail_id => l_mail_id, p_attachment => f.blob_content,
                                         p_filename => f.filename, p_mime_type => f.mime_type);
            end loop;
            l_status := 'SENT';
        end if;
        insert into xxfnd_communications (application_code, entity_name, pk1_value, rfi_id, direction, from_address,
                                          to_address, cc_address, subject, body, status, source, mail_id, in_reply_to_id,
                                          recorded_by)
        values (p_application_code, p_entity_name, p_pk1_value, p_rfi_id, 'OUT', l_from, p_to, p_cc,
                substr(p_subject, 1, 500), p_body, l_status, 'APEX_MAIL', l_mail_id, p_in_reply_to_id,
                xxfnd_util_pkg.current_user)
        returning communication_id into l_id;
        keep_file(l_id, p_temp_file_name, p_application_code);
        return l_id;
    end send_email;

    procedure record_sent(p_application_code in varchar2,
                          p_entity_name      in varchar2,
                          p_pk1_value        in varchar2,
                          p_to               in varchar2,
                          p_subject          in varchar2,
                          p_body             in clob,
                          p_rfi_id           in number default null,
                          p_mail_id          in number default null) is
    begin
        insert into xxfnd_communications (application_code, entity_name, pk1_value, rfi_id, direction, from_address,
                                          to_address, subject, body, status, source, mail_id, recorded_by)
        values (p_application_code, p_entity_name, p_pk1_value, p_rfi_id, 'OUT', common_setting('MAIL_FROM'),
                p_to, nvl(substr(p_subject, 1, 500), '-'), p_body, 'SENT', 'APEX_MAIL', p_mail_id,
                xxfnd_util_pkg.current_user);
    end record_sent;

    function record_received(p_application_code    in varchar2,
                             p_entity_name         in varchar2,
                             p_pk1_value           in varchar2,
                             p_from                in varchar2,
                             p_subject             in varchar2,
                             p_body                in clob,
                             p_received_date       in timestamp with time zone default systimestamp,
                             p_rfi_id              in number   default null,
                             p_in_reply_to_id      in number   default null,
                             p_source              in varchar2 default 'MANUAL',
                             p_external_message_id in varchar2 default null,
                             p_conversation_id     in varchar2 default null,
                             p_temp_file_name      in varchar2 default null) return number is
        l_error varchar2(4000) := email_error('IN', p_from, p_subject, p_body);
        l_id    number;
    begin
        if l_error is not null then
            raise_application_error(-20540, l_error);
        end if;
        insert into xxfnd_communications (application_code, entity_name, pk1_value, rfi_id, direction, from_address,
                                          subject, body, communication_date, status, source, external_message_id,
                                          conversation_id, in_reply_to_id, recorded_by)
        values (p_application_code, p_entity_name, p_pk1_value, p_rfi_id, 'IN', p_from, substr(p_subject, 1, 500), p_body,
                nvl(p_received_date, systimestamp), 'RECEIVED', p_source, p_external_message_id, p_conversation_id,
                p_in_reply_to_id, xxfnd_util_pkg.current_user)
        returning communication_id into l_id;
        keep_file(l_id, p_temp_file_name, p_application_code);
        return l_id;
    end record_received;

end xxfnd_notify_pkg;
/

create or replace package body xxfnd_workflow_pkg as
    ---------------------------------------------------------------- runtime

    function common_application_id return number is
        l_id number;
    begin
        select max(apex_application_id) into l_id from xxfnd_applications where application_code = 'COMMON';
        return l_id;
    end common_application_id;

    function start_process(p_static_id        in varchar2,
                           p_detail_pk        in varchar2,
                           p_initiator        in varchar2 default null,
                           p_application_id   in number   default null,
                           p_application_code in varchar2 default null) return number is
        l_id     number;
        l_params apex_workflow.t_workflow_parameters;
    begin
        if p_application_code is not null then
            l_params(1) := apex_workflow.t_workflow_parameter(static_id => 'APPLICATION_CODE',
                                                              string_value => upper(p_application_code));
        end if;
        xxfnd_vpd_pkg.begin_trusted;
        begin
            l_id := apex_workflow.start_workflow(
                        p_application_id => coalesce(p_application_id, to_number(v('APP_ID'))),
                        p_static_id      => p_static_id,
                        p_parameters     => l_params,
                        p_initiator      => coalesce(p_initiator, nullif(v('APP_USER'), 'nobody'), xxfnd_util_pkg.current_user),
                        p_detail_pk      => p_detail_pk);
        exception
            when others then
                xxfnd_vpd_pkg.end_trusted;
                raise;
        end;
        xxfnd_vpd_pkg.end_trusted;
        return l_id;
    end start_process;

    function workflow_application(p_workflow_id in number) return varchar2 is
        l_code varchar2(255);
    begin
        if p_workflow_id is null then
            return null;
        end if;
        begin
            l_code := apex_workflow.get_variable_value(p_instance_id => p_workflow_id, p_variable_static_id => 'APPLICATION_CODE');
        exception
            when others then
                l_code := null;   -- the workflow has no APPLICATION_CODE parameter
        end;
        if l_code is null then
            select max(a.application_code) into l_code
              from apex_workflows w join xxfnd_applications a on a.apex_application_id = w.application_id
             where w.workflow_id = p_workflow_id;
        end if;
        return upper(l_code);
    end workflow_application;

    function state(p_workflow_id in number) return varchar2 is
        l_state varchar2(30);
    begin
        if p_workflow_id is null then
            return null;
        end if;
        select max(state_code) into l_state from apex_workflows where workflow_id = p_workflow_id;
        return l_state;
    end state;

    function is_running(p_workflow_id in number) return varchar2 is
    begin
        return case when state(p_workflow_id) in ('ACTIVE', 'SUSPENDED', 'FAULTED') then 'Y' else 'N' end;
    end is_running;

    procedure end_process(p_workflow_id in number) is
    begin
        if is_running(p_workflow_id) = 'N' then
            return;
        end if;
        xxfnd_vpd_pkg.begin_trusted;
        begin
            apex_workflow.terminate(p_instance_id => p_workflow_id);
        exception
            when others then
                xxfnd_vpd_pkg.end_trusted;
                raise;
        end;
        xxfnd_vpd_pkg.end_trusted;
    end end_process;


    ---------------------------------------------------------------- switches

    function app_code(p_application_code in varchar2) return varchar2 is
        l_code xxfnd_applications.application_code%type;
    begin
        if p_application_code is not null then
            return upper(p_application_code);
        end if;
        select max(application_code) into l_code from xxfnd_applications
         where upper(apex_app_alias) = upper(v('APP_ALIAS'))
            or apex_application_id = to_number(v('APP_ID'));
        return l_code;
    end app_code;

    function workflow_enabled(p_process_code in varchar2, p_application_code in varchar2 default null) return varchar2 is
        l_flag xxfnd_workflow_processes.workflow_enabled_flag%type;
        l_app  xxfnd_applications.application_code%type := app_code(p_application_code);
    begin
        select max(workflow_enabled_flag) into l_flag from xxfnd_workflow_processes
         where application_code = l_app and process_code = upper(p_process_code);
        return nvl(l_flag, 'Y');
    end workflow_enabled;

    function email_enabled(p_process_code in varchar2 default null, p_application_code in varchar2 default null) return varchar2 is
        l_app  xxfnd_applications.application_code%type := app_code(p_application_code);
        l_inst varchar2(1);
        l_appf varchar2(1);
        l_proc varchar2(1);
    begin
        select max(email_enabled_flag) into l_inst from xxfnd_applications where application_code = 'COMMON';
        select max(email_enabled_flag) into l_appf from xxfnd_applications where application_code = l_app;
        if p_process_code is not null then
            select max(email_enabled_flag) into l_proc from xxfnd_workflow_processes
             where application_code = l_app and process_code = upper(p_process_code);
        end if;
        return case when nvl(l_inst, 'Y') = 'Y' and nvl(l_appf, 'Y') = 'Y' and nvl(l_proc, 'Y') = 'Y' then 'Y' else 'N' end;
    end email_enabled;

    function process_of_task(p_task_id in number) return varchar2 is
        l_code varchar2(255);
    begin
        select max(w.workflow_def_static_id) into l_code
          from apex_tasks t
          join apex_workflows w on w.workflow_id = t.workflow_id
         where t.task_id = p_task_id;
        return upper(l_code);
    end process_of_task;

    procedure sync_processes is
    begin
        merge into xxfnd_workflow_processes d
        using (select a.application_code, upper(w.static_id) process_code, max(w.name) process_name
                 from apex_appl_workflows w
                 join xxfnd_applications a on a.apex_application_id = w.application_id
                group by a.application_code, upper(w.static_id)
                -- release 82: the request for information process of every registered application
                union all
               select a.application_code, c_rfi_process, 'Request for Information'
                 from xxfnd_applications a
                where a.application_code <> 'COMMON'
                  and not exists (select 1 from apex_appl_workflows w
                                   where w.application_id = a.apex_application_id
                                     and upper(w.static_id) = c_rfi_process)) s
           on (d.application_code = s.application_code and d.process_code = s.process_code)
         when matched then update set d.process_name = s.process_name
                            where decode(d.process_name, s.process_name, 0, 1) = 1
         when not matched then insert (application_code, process_code, process_name)
                               values (s.application_code, s.process_code, s.process_name);
    end sync_processes;


    procedure set_workspace_email(p_enabled in varchar2) is
    begin
        if not xxfnd_privilege_pkg.has_privilege('WORKFLOW_SETUP', 'MANAGE') then
            raise_application_error(-20161, 'You are not allowed to change the e-mail switch (Workflow Setup - Manage).');
        end if;
        update xxfnd_applications set email_enabled_flag = case when p_enabled = 'Y' then 'Y' else 'N' end
         where application_code = 'COMMON';
    end set_workspace_email;

    ---------------------------------------------------------------- tasks

    function users_in_role(p_role_code in varchar2, p_exclude in varchar2 default null) return varchar2 is
        l_list varchar2(32767);
    begin
        select listagg(distinct ur.user_name, ',') within group (order by ur.user_name)
          into l_list
          from xxfnd_user_roles_v ur
         where ur.role_code = upper(p_role_code)
           and ur.active_flag = 'Y'
           and ur.user_name <> upper(nvl(p_exclude, '#'));
        return l_list;
    end users_in_role;

    function users_with_privilege(p_feature_code in varchar2, p_action in varchar2,
                                  p_exclude in varchar2 default null) return varchar2 is
        l_list varchar2(32767);
    begin
        select listagg(distinct ur.user_name, ',') within group (order by ur.user_name)
          into l_list
          from xxfnd_user_roles_v ur
          join xxfnd_role_privileges rp on rp.role_code = ur.role_code
         where rp.privilege_code = upper(p_feature_code) || '.' || upper(p_action)
           and ur.active_flag = 'Y'
           and ur.user_name <> upper(nvl(p_exclude, '#'));
        return l_list;
    end users_with_privilege;

    function business_admins return varchar2 is
    begin
        return users_with_privilege('WORKFLOW_MONITOR', 'MANAGE');
    end business_admins;

    function due_date(p_task_definition in varchar2) return timestamp with time zone is
        l_days number;
    begin
        select max(due_days) into l_days from xxfnd_task_settings where task_definition = p_task_definition;
        return case when l_days is not null then systimestamp + numtodsinterval(l_days, 'DAY') end;
    end due_date;

    function create_task(p_task_definition in varchar2,
                         p_detail_pk       in varchar2,
                         p_subject         in varchar2 default null,
                         p_parameters      in apex_human_task.t_task_parameters default c_no_parameters) return number is
    begin
        return apex_human_task.create_task(
                   p_application_id     => v('APP_ID'),
                   p_task_def_static_id => p_task_definition,
                   p_subject            => p_subject,
                   p_parameters         => p_parameters,
                   p_detail_pk          => p_detail_pk,
                   p_due_date           => due_date(p_task_definition));
    end create_task;

    procedure complete_open(p_task_definition in varchar2, p_detail_pk in varchar2, p_outcome in varchar2 default null,
                            p_application_id in number default null) is
    begin
        for t in (select task_id from apex_tasks
                   where task_def_static_id = p_task_definition
                     and detail_pk = p_detail_pk
                     and state_code in ('UNASSIGNED','ASSIGNED')
                     and application_id = coalesce(p_application_id, to_number(v('APP_ID')))) loop
            -- An unassigned task (several potential owners) is claimed and completed in one go.
            if apex_human_task.is_allowed(p_task_id => t.task_id, p_operation => apex_human_task.c_task_op_complete)
               or apex_human_task.is_allowed(p_task_id => t.task_id, p_operation => apex_human_task.c_task_op_claim) then
                apex_human_task.complete_task(p_task_id => t.task_id, p_outcome => p_outcome, p_autoclaim => true);
            end if;
        end loop;
    end complete_open;

    procedure cancel_open(p_task_definition in varchar2, p_detail_pk in varchar2, p_application_id in number default null) is
    begin
        for t in (select task_id from apex_tasks
                   where task_def_static_id = p_task_definition
                     and detail_pk = p_detail_pk
                     and state_code in ('UNASSIGNED','ASSIGNED','INFO_REQUESTED')
                     and application_id = coalesce(p_application_id, to_number(v('APP_ID')))) loop
            if apex_human_task.is_allowed(p_task_id => t.task_id, p_operation => apex_human_task.c_task_op_cancel) then
                apex_human_task.cancel_task(p_task_id => t.task_id);
            end if;
        end loop;
    end cancel_open;

    function last_comment(p_task_id in number) return varchar2 is
        l_text varchar2(4000);
    begin
        select max(substr(text, 1, 4000)) keep (dense_rank last order by created_on)
          into l_text
          from apex_task_comments
         where task_id = p_task_id;
        return l_text;
    end last_comment;

    function can_request_info(p_task_id in number) return varchar2 is
        l_initiator apex_tasks.initiator%type;
    begin
        select max(initiator) into l_initiator from apex_tasks where task_id = p_task_id;
        return case when l_initiator is not null and upper(l_initiator) <> upper(xxfnd_util_pkg.current_user)
                    then 'Y' else 'N' end;
    end can_request_info;

    function info_task(p_task_definition in varchar2, p_detail_pk in varchar2) return number is
        l_task_id number;
    begin
        select max(task_id) into l_task_id
          from apex_tasks
         where task_def_static_id = p_task_definition and detail_pk = p_detail_pk
           and state_code = 'INFO_REQUESTED' and upper(initiator) = upper(xxfnd_util_pkg.current_user);
        return l_task_id;
    end info_task;

    procedure vacation_rule(p_param  in  apex_human_task.t_vacation_rule_input,
                            p_result out apex_human_task.t_vacation_rule_result) is
        l_idx pls_integer := 0;
    begin
        for i in 1 .. p_param.original_participants.count loop
            if p_param.original_participants(i).type = apex_human_task.c_task_potential_owner
               and p_param.original_participants(i).identity = apex_human_task.c_task_identity_type_user then
                for d in (select d.delegate_user_name, d.reason
                            from xxfnd_wf_delegations d
                           where d.delegator_user_name = upper(p_param.original_participants(i).value)
                             and trunc(sysdate) between d.start_date and d.end_date
                             and (d.task_definition is null or d.task_definition = p_param.task_def_static_id)) loop
                    l_idx := l_idx + 1;
                    p_result.participant_changes(l_idx) :=
                        apex_human_task.t_task_participant_change(
                            apex_human_task.t_task_participant(apex_human_task.c_task_potential_owner,
                                                               apex_human_task.c_task_identity_type_user,
                                                               p_param.original_participants(i).value),
                            apex_human_task.t_task_participant(apex_human_task.c_task_potential_owner,
                                                               apex_human_task.c_task_identity_type_user,
                                                               d.delegate_user_name),
                            nvl(d.reason, d.delegate_user_name || ' covering for ' || p_param.original_participants(i).value));
                end loop;
            end if;
        end loop;
        p_result.has_participant_changes := l_idx > 0;
    end vacation_rule;

    -- the values of a task for the wording (#TOKEN#); the link comes from the event (release 84)
    function task_tokens(p_task_id in number) return clob is
        l_json      json_object_t := json_object_t();
        l_assignees varchar2(4000);
    begin
        for t in (select t.task_id, t.subject, t.due_on, t.initiator, t.actual_owner, t.outcome, t.detail_pk,
                         t.application_name
                    from apex_tasks t where t.task_id = p_task_id) loop
            l_json.put('TASK_ID', to_char(t.task_id));
            l_json.put('TASK_SUBJECT', t.subject);   -- release 82: plain (the layout escapes)
            l_json.put('DUE_DATE', nvl(to_char(t.due_on, 'DD-Mon-YYYY HH24:MI'), '-'));
            l_json.put('INITIATOR', t.initiator);
            l_json.put('OWNER', t.actual_owner);
            l_json.put('OUTCOME', t.outcome);
            l_json.put('RECORD_KEY', t.detail_pk);
            l_json.put('APPLICATION_NAME', t.application_name);
        end loop;
        l_json.put('COMMENT', last_comment(p_task_id));
        select listagg(participant, ', ') within group (order by participant)
          into l_assignees
          from apex_task_participants
         where task_id = p_task_id and participant_type = 'POTENTIAL_OWNER';
        l_json.put('ASSIGNEES', nvl(l_assignees, '-'));
        return l_json.to_clob;
    end task_tokens;

    procedure on_task_event(p_task_id in number, p_trigger in varchar2, p_outcome in varchar2 default null) is
        l_event varchar2(30) := xxfnd_notify_pkg.event_for(p_trigger, p_outcome);
        l_flag  varchar2(1);
        l_app   varchar2(30);
    begin
        if l_event is null then
            return;
        end if;
        for t in (select k.task_id, k.workflow_id, k.detail_pk, k.task_def_static_id, k.application_id
                    from apex_tasks k where k.task_id = p_task_id) loop
            if upper(p_trigger) = 'CREATE' then
                select nvl(max(notify_on_create_flag), 'Y') into l_flag
                  from xxfnd_task_settings where task_definition = t.task_def_static_id;
                continue when l_flag = 'N';
            end if;
            l_app := workflow_application(t.workflow_id);
            if l_app is null then
                select max(application_code) into l_app from xxfnd_applications where apex_application_id = t.application_id;
            end if;
            xxfnd_notify_pkg.raise_event(
                p_event_code       => l_event,
                p_application_code => l_app,
                p_process_code     => process_of_task(t.task_id),
                p_task_id          => t.task_id,
                p_workflow_id      => t.workflow_id,
                p_detail_pk        => t.detail_pk,
                p_tokens           => task_tokens(t.task_id));
        end loop;
    end on_task_event;

    procedure notify_created(p_task_id in number) is
    begin
        on_task_event(p_task_id, 'CREATE');
    end notify_created;

    procedure process_deadlines is
    begin
        -- Reminders before the due date (release 84: the tasks of every application; who is told: the event's rules).
        for t in (select k.task_id
                    from apex_tasks k
                    join xxfnd_task_settings s on s.task_definition = k.task_def_static_id
                   where k.state_code in ('UNASSIGNED','ASSIGNED')
                     and s.reminder_days_before is not null
                     and k.due_on is not null
                     and systimestamp >= k.due_on - numtodsinterval(s.reminder_days_before, 'DAY')
                     and systimestamp < k.due_on
                     and not exists (select 1 from xxfnd_task_alerts a where a.task_id = k.task_id and a.alert_type = 'REMINDER')) loop
            on_task_event(t.task_id, 'REMINDER');
            insert into xxfnd_task_alerts (task_id, alert_type) values (t.task_id, 'REMINDER');
        end loop;
        -- Escalation of overdue tasks (to the escalation role of the task definition: recipient type ESCALATION_ROLE).
        for t in (select k.task_id
                    from apex_tasks k
                    join xxfnd_task_settings s on s.task_definition = k.task_def_static_id
                   where k.state_code in ('UNASSIGNED','ASSIGNED')
                     and s.escalation_role_code is not null
                     and k.due_on < systimestamp
                     and not exists (select 1 from xxfnd_task_alerts a where a.task_id = k.task_id and a.alert_type = 'ESCALATION')) loop
            on_task_event(t.task_id, 'ESCALATION');
            insert into xxfnd_task_alerts (task_id, alert_type) values (t.task_id, 'ESCALATION');
        end loop;
        -- Forget alerts of tasks that no longer exist.
        delete from xxfnd_task_alerts a where not exists (select 1 from apex_tasks k where k.task_id = a.task_id);
    end process_deadlines;

    ---------------------------------------------------------------- My Tasks and Workflow Monitor (release 82)
    function open_task_count(p_user_name in varchar2 default null) return number is
        l_n number;
    begin
        select count(*) into l_n
          from table(apex_human_task.get_tasks(p_context        => 'MY_TASKS',
                                               p_user           => nvl(upper(p_user_name), v('APP_USER')),
                                               p_application_id => null))
         where state_code in ('UNASSIGNED', 'ASSIGNED', 'INFO_REQUESTED');
        return l_n;
    end open_task_count;

    procedure assert_monitor is
    begin
        if not xxfnd_privilege_pkg.has_privilege('WORKFLOW_MONITOR', 'MANAGE') then
            raise_application_error(-20164, 'You are not allowed to act in the Workflow Monitor (Workflow Monitor - Manage).');
        end if;
    end assert_monitor;

    procedure monitor_workflow(p_workflow_id in number, p_action in varchar2) is
    begin
        assert_monitor;
        xxfnd_vpd_pkg.begin_trusted;
        begin
            case upper(p_action)
                when 'SUSPEND'   then apex_workflow.suspend(p_instance_id => p_workflow_id);
                when 'RESUME'    then apex_workflow.resume(p_instance_id => p_workflow_id);
                when 'RETRY'     then apex_workflow.retry(p_instance_id => p_workflow_id);
                when 'TERMINATE' then apex_workflow.terminate(p_instance_id => p_workflow_id);
                else raise_application_error(-20165, 'Unknown Workflow Monitor action ' || p_action || '.');
            end case;
        exception
            when others then
                xxfnd_vpd_pkg.end_trusted;
                raise;
        end;
        xxfnd_vpd_pkg.end_trusted;
    end monitor_workflow;

    procedure monitor_task(p_task_id in number, p_action in varchar2, p_user_name in varchar2 default null) is
    begin
        assert_monitor;
        if upper(p_action) in ('REASSIGN', 'DELEGATE') and p_user_name is null then
            raise_application_error(-20166, 'Choose the user.');
        end if;
        xxfnd_vpd_pkg.begin_trusted;
        begin
            case upper(p_action)
                when 'REASSIGN' then apex_human_task.delegate_task(p_task_id => p_task_id, p_to_user => upper(p_user_name));
                when 'DELEGATE' then apex_human_task.add_task_potential_owner(p_task_id         => p_task_id,
                                                                              p_potential_owner => upper(p_user_name));
                when 'RELEASE'  then apex_human_task.release_task(p_task_id => p_task_id);
                else raise_application_error(-20165, 'Unknown Workflow Monitor action ' || p_action || '.');
            end case;
        exception
            when others then
                xxfnd_vpd_pkg.end_trusted;
                raise;
        end;
        xxfnd_vpd_pkg.end_trusted;
    end monitor_task;


    function task_record(p_task_id in number) return varchar2 is
        l_user varchar2(255) := upper(xxfnd_util_pkg.current_user);
        l_pk   varchar2(4000);
    begin
        select max(t.detail_pk) into l_pk
          from apex_tasks t
         where t.task_id = p_task_id
           and (upper(t.initiator) = l_user or upper(t.actual_owner) = l_user
                or exists (select 1 from apex_task_participants p
                            where p.task_id = t.task_id and p.identity_type = 'USER' and upper(p.participant) = l_user)
                or xxfnd_privilege_pkg.has_privilege_yn('WORKFLOW_MONITOR', 'MANAGE') = 'Y');
        return l_pk;
    end task_record;

    function task_messages return xxfnd_qa_tab pipelined is
    begin
        for c in (select a.application_code, t.task_def_static_id, t.detail_pk, t.task_id,
                         substr(c.text, 1, 4000) as text, c.created_by, c.created_on
                    from apex_tasks t
                    join apex_task_comments c on c.task_id = t.task_id
                    left join xxfnd_applications a on a.apex_application_id = t.application_id) loop
            pipe row (xxfnd_qa_row(c.application_code, c.task_def_static_id, 'TASK', c.detail_pk, c.task_id,
                                   c.text, c.created_by, c.created_on));
        end loop;
        return;
    end task_messages;

end xxfnd_workflow_pkg;
/

--------------------------------------------------------------------------------
-- Configuration changes (maker-checker): the row rules and the approval of a change, one package (release 84: the
-- approval is the COMMON workflow process CONFIG_CHANGE; this package keeps the rules)
-- (release 74: XXFND_CONFIG_APPROVAL_PKG merged into XXFND_APPROVAL_PKG; the body moved here from 06 because the
-- approval task needs XXFND_WORKFLOW_PKG above).
--------------------------------------------------------------------------------
begin
    execute immediate 'drop package xxfnd_config_approval_pkg';
exception
    when others then
        if sqlcode <> -4043 then
            raise;
        end if;
end;
/

create or replace package body xxfnd_approval_pkg as

    function pk_column(p_table_name in varchar2) return varchar2 is
        l_column xxfnd_config_tables.pk_column%type;
    begin
        -- release 48: the maker-checker tables each application registered (XXFND_CONFIG_TABLES)
        select max(pk_column) into l_column
          from xxfnd_config_tables
         where table_name = upper(p_table_name) and approval_flag = 'Y';
        return l_column;
    end pk_column;

    function is_controlled(p_table_name in varchar2) return boolean is
    begin
        return pk_column(p_table_name) is not null;
    end is_controlled;

    procedure set_status(p_table_name in varchar2, p_pk_value in varchar2, p_status in varchar2) is
        l_rows pls_integer;
    begin
        if not is_controlled(p_table_name) then
            raise_application_error(-20120, p_table_name || ' is not under maker-checker control.');
        end if;
        -- Table and column names come from the registry (XXFND_CONFIG_TABLES) only.
        -- release 54: owner-qualified - KYC tables are in the KYC schema
        execute immediate 'update ' || xxfnd_util_pkg.qualified(p_table_name)
                       || ' set approval_status = :s where ' || dbms_assert.simple_sql_name(pk_column(p_table_name)) || ' = :k'
            using p_status, p_pk_value;
        l_rows := sql%rowcount;
        if l_rows = 0 then
            raise_application_error(-20121, 'No ' || p_table_name || ' row with key ' || p_pk_value || '.');
        end if;
    end set_status;

    procedure submit(p_table_name in varchar2, p_pk_value in varchar2) is
    begin
        set_status(p_table_name, p_pk_value, 'PENDING_APPROVAL');
    end submit;

    procedure approve(p_table_name in varchar2, p_pk_value in varchar2) is
    begin
        set_status(p_table_name, p_pk_value, 'APPROVED');
    end approve;

    procedure reject(p_table_name in varchar2, p_pk_value in varchar2, p_reason in varchar2) is
    begin
        if p_reason is null then
            raise_application_error(-20122, 'Enter a reason for rejecting this change.');
        end if;
        xxfnd_audit_pkg.set_change_reason('Rejected: ' || p_reason);
        set_status(p_table_name, p_pk_value, 'REJECTED');
        xxfnd_audit_pkg.clear_change_reason;
    end reject;

    procedure apply_rules(p_inserting        in boolean,
                          p_old_status       in varchar2,
                          p_new_status       in out varchar2,
                          p_old_last_updated in varchar2,
                          p_approved_by      in out varchar2,
                          p_approved_date    in out timestamp) is
        l_user varchar2(255) := xxfnd_util_pkg.current_user;
    begin
        if p_inserting then
            -- Install scripts (no APEX session) may seed rows as APPROVED.
            if p_new_status = 'APPROVED' and xxfnd_util_pkg.in_apex_session then
                p_new_status := 'PENDING_APPROVAL';
            end if;
            if p_new_status = 'APPROVED' then
                p_approved_by   := l_user;
                p_approved_date := systimestamp;
            else
                p_approved_by   := null;
                p_approved_date := null;
            end if;
            return;
        end if;

        -- release 74: install and upgrade scripts (no APEX session) may also set a row back to approved (a seed fix)
        if p_new_status = 'APPROVED' and not xxfnd_util_pkg.in_apex_session then
            p_approved_by   := nvl(p_approved_by, l_user);
            p_approved_date := nvl(p_approved_date, systimestamp);
            return;
        end if;
        if p_new_status = 'APPROVED' and nvl(p_old_status, '#') <> 'APPROVED' then
            if p_old_status <> 'PENDING_APPROVAL' then
                raise_application_error(-20123, 'Only a change that is pending approval can be approved.');
            end if;
            if upper(l_user) = upper(p_old_last_updated) then
                raise_application_error(-20124, 'You made this change, so someone else must approve it.');
            end if;
            p_approved_by   := l_user;
            p_approved_date := systimestamp;
        elsif p_new_status = nvl(p_old_status, '#') then
            -- A content edit (status untouched): approved rows go back for approval.
            if p_old_status in ('APPROVED','REJECTED') then
                p_new_status := 'PENDING_APPROVAL';
            end if;
            p_approved_by   := null;
            p_approved_date := null;
        elsif p_new_status in ('PENDING_APPROVAL','REJECTED','DRAFT') then
            p_approved_by   := null;
            p_approved_date := null;
        end if;
    end apply_rules;

    function config_changes return xxfnd_config_change_tab pipelined is
        l_cur  sys_refcursor;
        l_rows xxfnd_config_change_tab;
    begin
        for v in (select distinct c.changes_view
                    from xxfnd_config_tables c
                   where c.approval_flag = 'Y' and c.changes_view is not null) loop
            begin
                open l_cur for 'select xxfnd_config_change_row(detail_pk, change_type, change_title, change_summary, '
                            || 'submitted_by, submitted_date) from ' || xxfnd_util_pkg.qualified(v.changes_view);
            exception
                when others then
                    -- a registered view that is not (yet) installed in this schema
                    continue;
            end;
            loop
                fetch l_cur bulk collect into l_rows limit 500;
                for i in 1 .. l_rows.count loop
                    pipe row (l_rows(i));
                end loop;
                exit when l_cur%notfound;
            end loop;
            close l_cur;
        end loop;
        return;
    end config_changes;

    ------------------------------------------------------------------------
    -- The approval task of a change
    ------------------------------------------------------------------------
    -- release 48: the rows behind an approval unit come from the registry (XXFND_CONFIG_TABLES): a table approved
    -- in units (UNIT_TABLE / UNIT_KEY_COLUMN, e.g. answer options of one question) or row by row.
    function registered(p_unit in varchar2) return xxfnd_config_tables%rowtype is
        l_row xxfnd_config_tables%rowtype;
    begin
        select * into l_row
          from xxfnd_config_tables
         where approval_flag = 'Y' and nvl(unit_table, table_name) = upper(p_unit)
           and rownum = 1;
        return l_row;
    exception
        when no_data_found then
            raise_application_error(-20124, p_unit || ' is not under maker-checker control.');
    end registered;

    function unit_rows(p_reg in xxfnd_config_tables%rowtype, p_key in varchar2, p_statuses in apex_t_varchar2)
        return apex_t_varchar2 is
        l_keys apex_t_varchar2;
    begin
        execute immediate 'select to_char(' || dbms_assert.simple_sql_name(p_reg.pk_column) || ') from '
                       || xxfnd_util_pkg.qualified(p_reg.table_name)
                       || ' where ' || dbms_assert.simple_sql_name(p_reg.unit_key_column) || ' = :k'
                       || ' and approval_status in (select column_value from table(:s))'
            bulk collect into l_keys using p_key, p_statuses;
        return l_keys;
    end unit_rows;

    procedure rows_of(p_detail_pk in varchar2, p_table out varchar2, p_keys out apex_t_varchar2) is
        l_unit varchar2(128) := substr(p_detail_pk, 1, instr(p_detail_pk, ':') - 1);
        l_key  varchar2(150) := substr(p_detail_pk, instr(p_detail_pk, ':') + 1);
        l_reg  xxfnd_config_tables%rowtype := registered(l_unit);
    begin
        p_table := l_reg.table_name;
        if l_reg.unit_table is not null then
            p_keys := unit_rows(l_reg, l_key, apex_t_varchar2('PENDING_APPROVAL'));
        else
            p_keys := apex_t_varchar2(l_key);
        end if;
    end rows_of;

    procedure request(p_table_name in varchar2, p_key in varchar2) is
        l_detail_pk varchar2(200) := upper(p_table_name) || ':' || p_key;
        l_type      varchar2(100);
        l_open      pls_integer;
        l_reg       xxfnd_config_tables%rowtype;
        l_keys      apex_t_varchar2;
        l_app       xxfnd_applications.application_code%type;
        l_wf        number;
    begin
        l_reg := registered(p_table_name);
        if l_reg.unit_table is not null then
            l_keys := unit_rows(l_reg, p_key, apex_t_varchar2('DRAFT', 'REJECTED'));
            for i in 1 .. l_keys.count loop
                submit(l_reg.table_name, l_keys(i));
            end loop;
        else
            submit(l_reg.table_name, p_key);
        end if;
        -- release 84: the change is approved in the COMMON workflow process CONFIG_CHANGE (one running per change)
        select count(*) into l_open
          from apex_workflows
         where workflow_def_static_id = 'CONFIG_CHANGE' and detail_pk = l_detail_pk
           and state_code in ('ACTIVE', 'SUSPENDED', 'FAULTED');
        if l_open = 0 then
            select max(change_type) into l_type from xxfnd_config_changes_v where detail_pk = l_detail_pk;
            if l_type is null then
                raise_application_error(-20125, 'There is nothing to approve for ' || l_detail_pk || '.');
            end if;
            select max(application_code) into l_app from xxfnd_applications where application_id = l_reg.application_id;
            l_wf := xxfnd_workflow_pkg.start_process(p_static_id        => 'CONFIG_CHANGE',
                                                     p_detail_pk        => l_detail_pk,
                                                     p_application_id   => xxfnd_workflow_pkg.common_application_id,
                                                     p_application_code => l_app);
        end if;
    end request;

    procedure approve_change(p_detail_pk in varchar2) is
        l_table varchar2(128);
        l_keys  apex_t_varchar2;
    begin
        xxfnd_vpd_pkg.begin_trusted;   -- release 84: the task action of the authorised approver
        if is_pending(p_detail_pk) = 'N' then
            raise_application_error(-20126, 'This change is no longer waiting for approval. Ask a workflow administrator to cancel the task.');
        end if;
        rows_of(p_detail_pk, l_table, l_keys);
        for i in 1 .. l_keys.count loop
            approve(l_table, l_keys(i));
        end loop;
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end approve_change;

    procedure reject_change(p_detail_pk in varchar2, p_reason in varchar2) is
        l_table varchar2(128);
        l_keys  apex_t_varchar2;
    begin
        xxfnd_vpd_pkg.begin_trusted;   -- release 84: the task action of the authorised approver
        rows_of(p_detail_pk, l_table, l_keys);
        for i in 1 .. l_keys.count loop
            reject(l_table, l_keys(i), nvl(p_reason, 'Rejected by the approver.'));
        end loop;
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end reject_change;

    function is_pending(p_detail_pk in varchar2) return varchar2 is
        l_count pls_integer;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select count(*) into l_count from xxfnd_config_changes_v where detail_pk = p_detail_pk;
        xxfnd_vpd_pkg.end_trusted;
        return case when l_count > 0 then 'Y' else 'N' end;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end is_pending;

    function task_change(p_task_id in number) return xxfnd_config_change_tab pipelined is
        l_pk   varchar2(4000) := xxfnd_workflow_pkg.task_record(p_task_id);
        l_rows xxfnd_config_change_tab;
    begin
        if l_pk is null then
            return;
        end if;
        xxfnd_vpd_pkg.begin_trusted;
        begin
            select xxfnd_config_change_row(detail_pk, change_type, change_title, change_summary, submitted_by, submitted_date)
              bulk collect into l_rows
              from xxfnd_config_changes_v where detail_pk = l_pk;
        exception
            when others then
                xxfnd_vpd_pkg.end_trusted;
                raise;
        end;
        xxfnd_vpd_pkg.end_trusted;
        for i in 1 .. l_rows.count loop
            pipe row (l_rows(i));
        end loop;
        return;
    end task_change;

end xxfnd_approval_pkg;
/


--------------------------------------------------------------------------------
-- Release 82: the merged packages are dropped (checked step; DDL and dependents kept in XXFND_DROPPED_OBJECTS).
-- Their callers use XXFND_WORKFLOW_PKG and XXFND_NOTIFY_PKG; old callers break on purpose (D15).
--------------------------------------------------------------------------------
begin
    xxfnd_ddl_pkg.drop_object('XXFND_TASK_PKG', 'PACKAGE');
    xxfnd_ddl_pkg.drop_object('XXFND_WORKFLOW_SWITCH_PKG', 'PACKAGE');
    xxfnd_ddl_pkg.drop_object('XXFND_COMMUNICATION_PKG', 'PACKAGE');
end;
/
