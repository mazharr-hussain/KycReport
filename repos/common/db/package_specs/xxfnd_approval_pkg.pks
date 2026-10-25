

--------------------------------------------------------------------------------
create or replace package xxfnd_approval_pkg authid definer as
    -- Tables under maker-checker control.
    function is_controlled(p_table_name in varchar2) return boolean;

    procedure submit(p_table_name in varchar2, p_pk_value in varchar2);
    procedure approve(p_table_name in varchar2, p_pk_value in varchar2);
    procedure reject(p_table_name in varchar2, p_pk_value in varchar2, p_reason in varchar2);

    -- Called from the BEFORE UPDATE/INSERT trigger on each controlled table.
    -- Editing an approved row sends it back for approval; approving your own
    -- change is refused.
    procedure apply_rules(p_inserting        in boolean,
                          p_old_status       in varchar2,
                          p_new_status       in out varchar2,
                          p_old_last_updated in varchar2,
                          p_approved_by      in out varchar2,
                          p_approved_date    in out timestamp);

    -- release 48: the pending changes of every application, one row per approval unit, from the views the
    -- applications registered (XXFND_CONFIG_TABLES.CHANGES_VIEW). Read through XXFND_CONFIG_CHANGES_V.
    function config_changes return xxfnd_config_change_tab pipelined;
    -- release 74 (one package per component): the approval task of a change (was XXFND_CONFIG_APPROVAL_PKG).
    -- Submits a change for approval and starts its COMMON CONFIG_CHANGE approval workflow (release 84; one running
    -- workflow per change; the workflow creates the CONFIG_CHANGE approval task).
    -- P_TABLE_NAME / P_KEY: a registered maker-checker table and its key, or a unit table and its key for all draft
    -- or rejected rows of that unit (XXFND_CONFIG_TABLES, e.g. XXCMP_QUESTIONS / question id = its answer options).
    procedure request(p_table_name in varchar2, p_key in varchar2);
    -- Task actions (the approver's session): apply or reject every row of the change.
    procedure approve_change(p_detail_pk in varchar2);
    procedure reject_change(p_detail_pk in varchar2, p_reason in varchar2);
    -- Y while the change behind a task is still waiting for approval.
    function is_pending(p_detail_pk in varchar2) return varchar2;
    -- Release 84: the change behind an approval task, for its task page (COMMON 144), when the signed-in user takes
    -- part in the task (XXFND_WORKFLOW_PKG.TASK_RECORD). The task actions and this read run in trusted mode: APEX has
    -- authorised the approver, whose administration scope may not include the changed setup.
    function task_change(p_task_id in number) return xxfnd_config_change_tab pipelined;
    -- Release 86: an application registers one of its configuration tables (audit, maker-checker approval: see
    -- XXFND_CONFIG_TABLES), added when missing (an administrator's change is kept). ORA-20180 when the application is
    -- not registered; ORA-20186 when the table is another application's.
    procedure register_config_table(p_application_code in varchar2,
                                    p_table_name       in varchar2,
                                    p_audit_flag       in varchar2 default 'Y',
                                    p_approval_flag    in varchar2 default 'N',
                                    p_pk_column        in varchar2 default null,
                                    p_unit_table       in varchar2 default null,
                                    p_unit_key_column  in varchar2 default null,
                                    p_changes_view     in varchar2 default null,
                                    p_description      in varchar2 default null);
end xxfnd_approval_pkg;
/
