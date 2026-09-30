create or replace package xxcus.xxfnd_task_pkg authid definer as

    -- Empty parameter list for CREATE_TASK.
    c_no_parameters apex_human_task.t_task_parameters;

    -- Task participants: comma-separated user names (task definition participant expressions).
    function users_in_role (
        p_role_code in varchar2,
        p_exclude   in varchar2 default null
    ) return varchar2;

    function users_with_privilege (
        p_feature_code in varchar2,
        p_action       in varchar2,
        p_exclude      in varchar2 default null
    ) return varchar2;
    -- Business administrators of every task: holders of WORKFLOW_MONITOR.MANAGE.
    function business_admins return varchar2;

    -- Due date from XXFND_TASK_SETTINGS (null = no deadline).
    function due_date (
        p_task_definition in varchar2
    ) return timestamp with time zone;

    -- Creates a task of the current application with the configured due date.
    function create_task (
        p_task_definition in varchar2,
        p_detail_pk       in varchar2,
        p_subject         in varchar2 default null,
        p_parameters      in apex_human_task.t_task_parameters default c_no_parameters
    ) return number;

    -- Completes the open tasks of a definition for a record that the current user may complete.
    procedure complete_open (
        p_task_definition in varchar2,
        p_detail_pk       in varchar2,
        p_outcome         in varchar2 default null
    );
    -- Cancels the open tasks of a definition for a record (initiator or business administrator).
    procedure cancel_open (
        p_task_definition in varchar2,
        p_detail_pk       in varchar2
    );

    -- Most recent comment on a task (e.g. the reason given when rejecting).
    function last_comment (
        p_task_id in number
    ) return varchar2;

    -- Task vacation rule procedure (set on every task definition): while a delegation in
    -- XXFND_WF_DELEGATIONS is active, the delegate is offered the delegator's tasks too.
    procedure vacation_rule (
        p_param  in apex_human_task.t_vacation_rule_input,
        p_result out apex_human_task.t_vacation_rule_result
    );

    -- Task definition action "on create": e-mails the potential owners (template TASK_ASSIGNED)
    -- unless NOTIFY_ON_CREATE_FLAG is N for the task definition.
    procedure notify_created (
        p_task_id in number
    );

    -- Daily Automation: reminder REMINDER_DAYS_BEFORE the due date (to the owners) and
    -- escalation once overdue (to the escalation role). Each is sent once per task.
    procedure process_deadlines;

end xxfnd_task_pkg;
/


-- sqlcl_snapshot {"hash":"08a15706685346e72da3907ee2c886a6b1addd25","type":"PACKAGE_SPEC","name":"XXFND_TASK_PKG","schemaName":"XXCUS","sxml":""}