
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
