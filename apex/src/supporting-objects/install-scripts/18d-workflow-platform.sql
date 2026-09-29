--------------------------------------------------------------------------------
-- 18d Workflow platform - seed (release R12)
-- Pages of the native APEX workflow screens, retired pages of the former engine,
-- tabs of Workflow Setup and Workflow Monitor, default deadlines per task.
-- Idempotent; values an administrator changed are kept.
--------------------------------------------------------------------------------
declare
    procedure page(p_feature in varchar2, p_page in number, p_tab in varchar2 default null, p_seq in number default null) is
    begin
        merge into xxfnd_feature_pages d
        using (select 'KYC' app_alias, p_page page_id from dual) s
           on (d.app_alias = s.app_alias and d.page_id = s.page_id)
         when matched then update set d.feature_code = p_feature,
                                      d.tab_label    = nvl(d.tab_label, p_tab),
                                      d.tab_sequence = nvl(d.tab_sequence, p_seq)
         when not matched then insert (app_alias, page_id, feature_code, tab_label, tab_sequence)
                               values ('KYC', p_page, p_feature, p_tab, p_seq);
    end page;

    procedure task_setting(p_task in varchar2, p_due in number, p_reminder in number, p_role in varchar2, p_desc in varchar2) is
    begin
        merge into xxfnd_task_settings t using (select p_task task_definition from dual) s
           on (t.task_definition = s.task_definition)
         when not matched then insert (task_definition, due_days, reminder_days_before, escalation_role_code, description)
                               values (p_task, p_due, p_reminder, p_role, p_desc);
    end task_setting;
begin
    xxfnd_util_pkg.set_install_mode(true);

    -- Pages of the former custom engine and of the change-approval queue.
    delete from xxfnd_feature_pages
     where app_alias = 'KYC' and page_id in (43, 140, 141, 142, 143, 170);

    -- My Tasks: Unified Task List (40), task details (42), configuration change review (172).
    page('MY_TASKS', 40);
    page('MY_TASKS', 42);
    page('MY_TASKS', 172);
    -- Workflow Monitor: tasks (41) and workflows (44) as tabs, workflow details (45).
    page('WORKFLOW_MONITOR', 41, 'Tasks', 10);
    page('WORKFLOW_MONITOR', 44, 'Workflows', 20);
    page('WORKFLOW_MONITOR', 45);
    -- Workflow Setup tabs.
    page('WORKFLOW_SETUP', 165, 'Approval Matrix', 10);
    page('WORKFLOW_SETUP', 114, 'Delegations', 20);
    page('WORKFLOW_SETUP', 115);
    page('WORKFLOW_SETUP', 145, 'Deadlines ' || chr(38) || ' Escalation', 30);
    page('WORKFLOW_SETUP', 146);
    page('WORKFLOW_SETUP', 147, 'Process Catalogue', 40);

    -- Configuration changes are now approval tasks in My Tasks: the feature stays only
    -- as the privilege that routes those tasks, without a menu entry of its own.
    update xxfnd_features
       set feature_name = 'Configuration Change Approver',
           home_page_id = null,
           description  = 'Holders of Manage receive configuration change approval tasks in My Tasks.'
     where feature_code = 'CHANGE_APPROVALS' and (home_page_id = 170 or home_page_id is null);

    task_setting('CONFIG_CHANGE', 3, 1, 'HEAD_OF_COMPLIANCE', 'Second-person approval of a configuration change.');
    task_setting('RFI_RESPONSE',  7, 2, 'COMPLIANCE_MANAGER', 'Requesting department answers a request for information.');
    task_setting('RFI_REVIEW',    3, 1, 'COMPLIANCE_MANAGER', 'Compliance reviews the answer to a request for information.');

    xxfnd_util_pkg.set_install_mode(false);
    xxfnd_ddl_pkg.mark_release('R12', 'Release 12: native APEX workflow platform (tasks, My Tasks, monitor, setup)');
    commit;
end;
/
