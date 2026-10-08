--------------------------------------------------------------------------------
-- 15_workflow.sql  (release R12)
-- Processes and tasks run on native APEX Workflow and Task Definitions
-- (APEX_WORKFLOW, APEX_HUMAN_TASK); My Tasks is the APEX Unified Task List.
-- This script holds only what APEX leaves to the application:
--   XXFND_TASK_SETTINGS       deadlines and escalation per task definition (admin screen)
--   XXFND_TASK_ALERTS         reminders/escalations already sent (sent once)
--   XXFND_NOTIFY_PKG          e-mail from the admin-maintained notification templates
--   XXFND_TASK_PKG            participants, due dates, vacation rule, notifications, deadlines
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
-- Notifications
--------------------------------------------------------------------------------
create or replace package xxfnd_notify_pkg authid definer as
    -- Sends notification template P_TEMPLATE_CODE (in the user's language when translated)
    -- to P_TO, replacing #TOKEN# placeholders from the JSON object P_TOKENS.
    -- Does nothing when the template is disabled or the MAIL_FROM application setting is empty.
    procedure send(p_template_code in varchar2, p_to in varchar2, p_tokens in clob default null);
    -- Same, once per application user (comma-separated user names) that has an e-mail address.
    procedure send_to_users(p_template_code in varchar2, p_user_names in varchar2, p_tokens in clob default null);
end xxfnd_notify_pkg;
/

create or replace package body xxfnd_notify_pkg as

    procedure send(p_template_code in varchar2, p_to in varchar2, p_tokens in clob default null) is
        l_from    varchar2(320) := apex_app_setting.get_value('MAIL_FROM');
        l_subject varchar2(4000);
        l_body    clob;
        l_mail_id number;
    begin
        if p_to is null or l_from is null
           or xxfnd_app_function_pkg.is_enabled('NOTIFICATIONS') = 'N' then   -- release 72: switched off (COMMON)
            return;
        end if;
        begin
            select nvl(t.subject, n.subject), nvl(t.body_html, n.body_html)
              into l_subject, l_body
              from xxfnd_notification_templates n
              left join xxfnd_notification_templates_tl t
                on t.template_code = n.template_code and t.language_code = xxfnd_util_pkg.current_lang
             where n.template_code = p_template_code
               and n.enabled_flag = 'Y';
        exception
            when no_data_found then
                return;
        end;
        if p_tokens is not null then
            l_subject := dbms_lob.substr(xxfnd_util_pkg.replace_tokens(l_subject, p_tokens), 4000, 1);
            l_body    := xxfnd_util_pkg.replace_tokens(l_body, p_tokens);
        end if;
        l_mail_id := apex_mail.send(
                         p_to        => p_to,
                         p_from      => l_from,
                         p_subj      => substr(l_subject, 1, 500),
                         p_body      => regexp_replace(l_body, '<[^>]+>', ''),
                         p_body_html => l_body);
    end send;

    procedure send_to_users(p_template_code in varchar2, p_user_names in varchar2, p_tokens in clob default null) is
    begin
        for u in (select distinct e.email_address
                    from xxfnd_employees e
                   where e.user_name in (select upper(trim(column_value)) from table(apex_string.split(p_user_names, ',')))
                     and e.enabled_flag = 'Y'
                     and e.email_address is not null) loop
            send(p_template_code, u.email_address, p_tokens);
        end loop;
    end send_to_users;

end xxfnd_notify_pkg;
/

--------------------------------------------------------------------------------
-- Task helpers
--------------------------------------------------------------------------------
create or replace package xxfnd_task_pkg authid definer as

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
    procedure complete_open(p_task_definition in varchar2, p_detail_pk in varchar2, p_outcome in varchar2 default null);
    -- Cancels the open tasks of a definition for a record (initiator or business administrator).
    procedure cancel_open(p_task_definition in varchar2, p_detail_pk in varchar2);

    -- Most recent comment on a task (e.g. the reason given when rejecting).
    function last_comment(p_task_id in number) return varchar2;

    -- Task vacation rule procedure (set on every task definition): while a delegation in
    -- XXFND_WF_DELEGATIONS is active, the delegate is offered the delegator's tasks too.
    procedure vacation_rule(p_param  in  apex_human_task.t_vacation_rule_input,
                            p_result out apex_human_task.t_vacation_rule_result);

    -- Task definition action "on create": e-mails the potential owners (template TASK_ASSIGNED)
    -- unless NOTIFY_ON_CREATE_FLAG is N for the task definition.
    procedure notify_created(p_task_id in number);

    -- Daily Automation: reminder REMINDER_DAYS_BEFORE the due date (to the owners) and
    -- escalation once overdue (to the escalation role). Each is sent once per task.
    procedure process_deadlines;

end xxfnd_task_pkg;
/

create or replace package body xxfnd_task_pkg as

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

    procedure complete_open(p_task_definition in varchar2, p_detail_pk in varchar2, p_outcome in varchar2 default null) is
    begin
        for t in (select task_id from apex_tasks
                   where task_def_static_id = p_task_definition
                     and detail_pk = p_detail_pk
                     and state_code in ('UNASSIGNED','ASSIGNED')
                     and application_id = v('APP_ID')) loop
            -- An unassigned task (several potential owners) is claimed and completed in one go.
            if apex_human_task.is_allowed(p_task_id => t.task_id, p_operation => apex_human_task.c_task_op_complete)
               or apex_human_task.is_allowed(p_task_id => t.task_id, p_operation => apex_human_task.c_task_op_claim) then
                apex_human_task.complete_task(p_task_id => t.task_id, p_outcome => p_outcome, p_autoclaim => true);
            end if;
        end loop;
    end complete_open;

    procedure cancel_open(p_task_definition in varchar2, p_detail_pk in varchar2) is
    begin
        for t in (select task_id from apex_tasks
                   where task_def_static_id = p_task_definition
                     and detail_pk = p_detail_pk
                     and state_code in ('UNASSIGNED','ASSIGNED','INFO_REQUESTED')
                     and application_id = v('APP_ID')) loop
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

    function task_tokens(p_task_id in number) return clob is
        l_json      json_object_t := json_object_t();
        l_url       varchar2(4000);
        l_assignees varchar2(4000);
    begin
        for t in (select subject, due_on from apex_tasks where task_id = p_task_id) loop
            l_json.put('TASK_SUBJECT', apex_escape.html(t.subject));
            l_json.put('DUE_DATE', nvl(to_char(t.due_on, 'DD-Mon-YYYY HH24:MI'), 'no due date'));
        end loop;
        begin
            l_url := apex_page.get_url(p_page => 40, p_plain_url => true);
        exception
            when others then
                l_url := null;   -- no APEX session (e.g. called from SQL*Plus)
        end;
        l_json.put('TASK_URL', l_url);
        select listagg(participant, ', ') within group (order by participant)
          into l_assignees
          from apex_task_participants
         where task_id = p_task_id and participant_type = 'POTENTIAL_OWNER';
        l_json.put('ASSIGNEES', apex_escape.html(nvl(l_assignees, '-')));
        return l_json.to_clob;
    end task_tokens;

    function potential_owners(p_task_id in number) return varchar2 is
        l_list varchar2(32767);
    begin
        select listagg(distinct participant, ',') within group (order by participant)
          into l_list
          from apex_task_participants
         where task_id = p_task_id
           and participant_type = 'POTENTIAL_OWNER'
           and identity_type = 'USER';
        return l_list;
    end potential_owners;

    procedure notify_created(p_task_id in number) is
        l_flag varchar2(1);
    begin
        select nvl(max(s.notify_on_create_flag), 'Y')
          into l_flag
          from apex_tasks t
          left join xxfnd_task_settings s on s.task_definition = t.task_def_static_id
         where t.task_id = p_task_id;
        if l_flag = 'Y' then
            xxfnd_notify_pkg.send_to_users('TASK_ASSIGNED', potential_owners(p_task_id), task_tokens(p_task_id));
        end if;
    end notify_created;

    procedure process_deadlines is
    begin
        -- Reminders to the owners before the due date.
        for t in (select k.task_id, k.actual_owner
                    from apex_tasks k
                    join xxfnd_task_settings s on s.task_definition = k.task_def_static_id
                   where k.application_id = v('APP_ID')
                     and k.state_code in ('UNASSIGNED','ASSIGNED')
                     and s.reminder_days_before is not null
                     and k.due_on is not null
                     and systimestamp >= k.due_on - numtodsinterval(s.reminder_days_before, 'DAY')
                     and systimestamp < k.due_on
                     and not exists (select 1 from xxfnd_task_alerts a where a.task_id = k.task_id and a.alert_type = 'REMINDER')) loop
            xxfnd_notify_pkg.send_to_users('TASK_REMINDER', nvl(t.actual_owner, potential_owners(t.task_id)), task_tokens(t.task_id));
            insert into xxfnd_task_alerts (task_id, alert_type) values (t.task_id, 'REMINDER');
        end loop;
        -- Escalation of overdue tasks to the escalation role.
        for t in (select k.task_id, s.escalation_role_code
                    from apex_tasks k
                    join xxfnd_task_settings s on s.task_definition = k.task_def_static_id
                   where k.application_id = v('APP_ID')
                     and k.state_code in ('UNASSIGNED','ASSIGNED')
                     and s.escalation_role_code is not null
                     and k.due_on < systimestamp
                     and not exists (select 1 from xxfnd_task_alerts a where a.task_id = k.task_id and a.alert_type = 'ESCALATION')) loop
            xxfnd_notify_pkg.send_to_users('TASK_ESCALATED', users_in_role(t.escalation_role_code), task_tokens(t.task_id));
            insert into xxfnd_task_alerts (task_id, alert_type) values (t.task_id, 'ESCALATION');
        end loop;
        -- Forget alerts of tasks that no longer exist.
        delete from xxfnd_task_alerts a where not exists (select 1 from apex_tasks k where k.task_id = a.task_id);
    end process_deadlines;

end xxfnd_task_pkg;
/

--------------------------------------------------------------------------------
-- Configuration changes (maker-checker) as APEX approval tasks
--------------------------------------------------------------------------------
create or replace package xxfnd_config_approval_pkg authid definer as
    -- Submits a change for approval and creates its CONFIG_CHANGE approval task (one open
    -- task per change). P_TABLE_NAME / P_KEY: a registered maker-checker table and its key, or a unit table
    -- and its key for all draft or rejected rows of that unit (XXFND_CONFIG_TABLES, e.g. XXCMP_QUESTIONS /
    -- question id = its answer options).
    procedure request(p_table_name in varchar2, p_key in varchar2);
    -- Task actions (the approver's session): apply or reject every row of the change.
    procedure approve(p_detail_pk in varchar2);
    procedure reject(p_detail_pk in varchar2, p_reason in varchar2);
    -- Y while the change behind a task is still waiting for approval.
    function is_pending(p_detail_pk in varchar2) return varchar2;
end xxfnd_config_approval_pkg;
/

create or replace package body xxfnd_config_approval_pkg as

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
        l_title     varchar2(4000);
        l_type      varchar2(100);
        l_task_id   number;
        l_open      pls_integer;
        l_reg       xxfnd_config_tables%rowtype;
        l_keys      apex_t_varchar2;
    begin
        l_reg := registered(p_table_name);
        if l_reg.unit_table is not null then
            l_keys := unit_rows(l_reg, p_key, apex_t_varchar2('DRAFT', 'REJECTED'));
            for i in 1 .. l_keys.count loop
                xxfnd_approval_pkg.submit(l_reg.table_name, l_keys(i));
            end loop;
        else
            xxfnd_approval_pkg.submit(l_reg.table_name, p_key);
        end if;
        select count(*) into l_open
          from apex_tasks
         where task_def_static_id = 'CONFIG_CHANGE' and detail_pk = l_detail_pk
           and state_code in ('UNASSIGNED','ASSIGNED','INFO_REQUESTED');
        if l_open = 0 then
            select max(change_type), max(change_title) into l_type, l_title
              from xxfnd_config_changes_v where detail_pk = l_detail_pk;
            if l_type is null then
                raise_application_error(-20125, 'There is nothing to approve for ' || l_detail_pk || '.');
            end if;
            l_task_id := xxfnd_task_pkg.create_task(
                             p_task_definition => 'CONFIG_CHANGE',
                             p_detail_pk       => l_detail_pk,
                             p_subject         => substr(l_type || ': ' || l_title, 1, 1000));
        end if;
    end request;

    procedure approve(p_detail_pk in varchar2) is
        l_table varchar2(128);
        l_keys  apex_t_varchar2;
    begin
        if is_pending(p_detail_pk) = 'N' then
            raise_application_error(-20126, 'This change is no longer waiting for approval. Ask a workflow administrator to cancel the task.');
        end if;
        rows_of(p_detail_pk, l_table, l_keys);
        for i in 1 .. l_keys.count loop
            xxfnd_approval_pkg.approve(l_table, l_keys(i));
        end loop;
    end approve;

    procedure reject(p_detail_pk in varchar2, p_reason in varchar2) is
        l_table varchar2(128);
        l_keys  apex_t_varchar2;
    begin
        rows_of(p_detail_pk, l_table, l_keys);
        for i in 1 .. l_keys.count loop
            xxfnd_approval_pkg.reject(l_table, l_keys(i), nvl(p_reason, 'Rejected by the approver.'));
        end loop;
    end reject;

    function is_pending(p_detail_pk in varchar2) return varchar2 is
        l_count pls_integer;
    begin
        select count(*) into l_count from xxfnd_config_changes_v where detail_pk = p_detail_pk;
        return case when l_count > 0 then 'Y' else 'N' end;
    end is_pending;

end xxfnd_config_approval_pkg;
/
