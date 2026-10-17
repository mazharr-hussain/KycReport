
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

    ---------------------------------------------------------------- release 86: registration and the process switch
    -- The deadline settings of a task definition of the application (added when missing; an administrator's change
    -- is kept). ORA-20180 when the application is not registered.
    procedure register_task_setting(p_application_code      in varchar2,
                                    p_task_definition       in varchar2,
                                    p_due_days              in number   default null,
                                    p_reminder_days_before  in number   default null,
                                    p_escalation_role_code  in varchar2 default null,
                                    p_notify_on_create_flag in varchar2 default 'Y',
                                    p_description           in varchar2 default null);
    -- The approval workflow of a process of an application on (Y) or off (N, the record is auto-approved). In an APEX
    -- session: Applications - Manage or Workflow Setup - Manage. ORA-20187 for a process not in the catalogue.
    procedure set_process_enabled(p_application_code in varchar2, p_process_code in varchar2, p_enabled_flag in varchar2);

    -- Release 88 (C8, C9): removes what the application registered (its own rows only, through
    -- XXFND_APPLICATION_PKG.REMOVE_REGISTERED: ORA-20187 not registered, ORA-20186 another application's, ORA-20196 in use).
    -- a configuration table no longer changed through approvals
    procedure unregister_config_table(p_application_code in varchar2, p_table_name in varchar2);
    procedure unregister_application(p_application_code in varchar2);
end xxfnd_workflow_pkg;
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
        -- release 84: the APEX workflow engine needs an APEX session (a page, an automation, or a script that opened one
        -- with APEX_SESSION.CREATE_SESSION)
        if v('APP_SESSION') is null then
            raise_application_error(-20167, 'A workflow process starts in an APEX session only (open one with APEX_SESSION.CREATE_SESSION).');
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
         -- release 86: the RFI process's participants are chosen by the user (as 24 sets for the existing rows)
         when not matched then insert (application_code, process_code, process_name, participants_type)
                               values (s.application_code, s.process_code, s.process_name,
                                       case when s.process_code = c_rfi_process then 'CHOSEN' else 'RULE' end);
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

    ---------------------------------------------------------------- release 86: registration and the process switch
    procedure register_task_setting(p_application_code      in varchar2,
                                    p_task_definition       in varchar2,
                                    p_due_days              in number   default null,
                                    p_reminder_days_before  in number   default null,
                                    p_escalation_role_code  in varchar2 default null,
                                    p_notify_on_create_flag in varchar2 default 'Y',
                                    p_description           in varchar2 default null) is
        l_code xxfnd_applications.application_code%type := xxfnd_application_pkg.registered_code(p_application_code);
    begin
        merge into xxfnd_task_settings t
        using (select trim(p_task_definition) task_definition from dual) s
           on (t.task_definition = s.task_definition)
         when not matched then insert (task_definition, due_days, reminder_days_before, escalation_role_code,
                                       notify_on_create_flag, description)
                               values (s.task_definition, p_due_days, p_reminder_days_before, upper(p_escalation_role_code),
                                       nvl(p_notify_on_create_flag, 'Y'), p_description);
    end register_task_setting;

    procedure set_process_enabled(p_application_code in varchar2, p_process_code in varchar2, p_enabled_flag in varchar2) is
        l_code xxfnd_applications.application_code%type := xxfnd_application_pkg.registered_code(p_application_code);
    begin
        if xxfnd_util_pkg.in_apex_session
           and not (xxfnd_privilege_pkg.has_privilege('APPLICATIONS', 'MANAGE')
                    or xxfnd_privilege_pkg.has_privilege('WORKFLOW_SETUP', 'MANAGE')) then
            xxfnd_error_pkg.raise_error('XXFND_NOT_ALLOWED');
        end if;
        update xxfnd_workflow_processes
           set workflow_enabled_flag = case when p_enabled_flag = 'Y' then 'Y' else 'N' end
         where application_code = l_code and process_code = upper(p_process_code);
        if sql%rowcount = 0 then
            xxfnd_error_pkg.raise_error('XXFND_REG_UNKNOWN', apex_t_varchar2('Process', l_code || ' ' || upper(p_process_code)));
        end if;
    end set_process_enabled;

    -- release 88 (C8, C9)
    procedure unregister_config_table(p_application_code in varchar2, p_table_name in varchar2) is
    begin
        xxfnd_application_pkg.remove_registered(p_application_code, 'Configuration table', 'XXFND_CONFIG_TABLES', apex_t_varchar2('TABLE_NAME'),
            apex_t_varchar2(upper(trim(p_table_name))),
            '(select a.application_code from xxfnd_applications a where a.application_id = t.application_id)');
    end unregister_config_table;

    procedure unregister_application(p_application_code in varchar2) is
    begin
        xxfnd_application_pkg.remove_all_registered(p_application_code, 'Configuration tables', 'XXFND_CONFIG_TABLES', '(select a.application_code from xxfnd_applications a where a.application_id = t.application_id)');
    end unregister_application;

end xxfnd_workflow_pkg;
/
