-- Patch 23 - page cleanup and Edit on the request view (release 38): database changes.
-- Run as the parsing schema. Removes the feature-page rows of the deleted pages 42 and 212. Idempotent.
set define off

-- ==== 18b-security-framework-seed.sql
--------------------------------------------------------------------------------
-- C02 Security framework - seed (release R10). Runs after the roles are seeded.
--------------------------------------------------------------------------------
declare
    -- Variables must precede the local subprograms.
    c_staff  constant varchar2(200) := 'COMPLIANCE_OFFICER,COMPLIANCE_MANAGER,HEAD_OF_COMPLIANCE';
    c_rules  constant varchar2(200) := 'COMPLIANCE_MANAGER,HEAD_OF_COMPLIANCE,SYSTEM_ADMIN';
    c_all    constant varchar2(200) := 'REQUESTER,COMPLIANCE_OFFICER,COMPLIANCE_MANAGER,HEAD_OF_COMPLIANCE,SYSTEM_ADMIN';
    c_amp    constant varchar2(1)   := chr(38);   -- no literal ampersand: script runners substitute it

    procedure feature(p_code in varchar2, p_name in varchar2, p_group in varchar2, p_seq in number,
                      p_admin in varchar2, p_actions in varchar2) is
    begin
        merge into xxfnd_features t using (select p_code c from dual) s on (t.feature_code = s.c)
         when not matched then insert (feature_code, feature_name, feature_group, display_sequence, admin_flag)
                               values (p_code, p_name, p_group, p_seq, p_admin);
        for a in (select column_value action from table(apex_string.split(p_actions, ','))) loop
            merge into xxfnd_privileges t using (select p_code || '.' || a.action pc from dual) s
               on (t.privilege_code = s.pc)
             when not matched then insert (privilege_code, feature_code, action_code, privilege_name)
                                   values (s.pc, p_code, a.action,
                                           p_name || ' - ' || initcap(a.action));
        end loop;
    end feature;

    procedure pages(p_feature in varchar2, p_pages in varchar2) is
    begin
        for p in (select to_number(column_value) page_id from table(apex_string.split(p_pages, ','))) loop
            merge into xxfnd_feature_pages t using (select 'KYC' app_alias, p.page_id page_id from dual) s
               on (t.app_alias = s.app_alias and t.page_id = s.page_id)
             when not matched then insert (app_alias, page_id, feature_code) values ('KYC', p.page_id, p_feature);
        end loop;
    end pages;

    procedure grant_priv(p_roles in varchar2, p_privileges in varchar2) is
    begin
        for r in (select column_value role_code from table(apex_string.split(p_roles, ','))) loop
            for p in (select column_value privilege_code from table(apex_string.split(p_privileges, ','))) loop
                merge into xxfnd_role_privileges t
                using (select r.role_code rc, p.privilege_code pc from dual) s
                   on (t.role_code = s.rc and t.privilege_code = s.pc)
                 when not matched then insert (role_code, privilege_code) values (s.rc, s.pc);
            end loop;
        end loop;
    end grant_priv;

    procedure rule(p_role in varchar2, p_table in varchar2, p_type in varchar2, p_column in varchar2 default null) is
    begin
        merge into xxfnd_data_security_rules t
        using (select p_role r, p_table tb, p_type ty from dual) s
           on (t.role_code = s.r and t.table_name = s.tb and t.rule_type = s.ty)
         when not matched then insert (role_code, table_name, rule_type, column_name)
                               values (p_role, p_table, p_type, p_column);
    end rule;
begin
    xxfnd_util_pkg.set_install_mode(true);
    -- Business features
    feature('HOME',             'Home',                   'BUSINESS', 10, 'N', 'VIEW');
    feature('MY_TASKS',         'My Tasks',               'BUSINESS', 20, 'N', 'VIEW');
    feature('KYC_REQUESTS',     'KYC Requests',           'BUSINESS', 30, 'N', 'VIEW,CREATE,MANAGE');
    feature('PARTIES',          'Parties',                'BUSINESS', 40, 'N', 'VIEW,CREATE,MANAGE');
    feature('CASES',            'Cases',                  'BUSINESS', 50, 'N', 'VIEW,CREATE,MANAGE');
    feature('MONITORING',       'Monitoring Watchlist',   'BUSINESS', 60, 'N', 'VIEW,MANAGE');
    feature('DASHBOARD',        'Executive Dashboard',    'BUSINESS', 70, 'N', 'VIEW');
    -- Admin: Basic Setup
    feature('LOOKUPS',          'Lookups',                'BASIC_SETUP', 110, 'Y', 'VIEW,CREATE,MANAGE');
    feature('FLEXFIELDS',       'Flexfields (DFF)',       'BASIC_SETUP', 120, 'Y', 'VIEW,CREATE,MANAGE');
    feature('KYC_RULES',        'KYC Rules',              'BASIC_SETUP', 130, 'Y', 'VIEW,CREATE,MANAGE');
    feature('ATTACHMENTS',      'Attachments',            'BASIC_SETUP', 140, 'Y', 'VIEW,CREATE,MANAGE');
    feature('NOTIFICATIONS',    'Notifications',          'BASIC_SETUP', 150, 'Y', 'VIEW,CREATE,MANAGE');
    feature('RETENTION',        'Retention',              'BASIC_SETUP', 160, 'Y', 'VIEW,CREATE,MANAGE');
    -- Admin: Workflow and Integration
    feature('WORKFLOW_SETUP',   'Workflow Setup',         'WORKFLOW_INTEGRATION', 210, 'Y', 'VIEW,CREATE,MANAGE');
    feature('ALERT_RULES',      'Alert Rules',            'WORKFLOW_INTEGRATION', 220, 'Y', 'VIEW,CREATE,MANAGE');
    feature('WORKFLOW_MONITOR', 'Workflow Monitor',       'WORKFLOW_INTEGRATION', 230, 'Y', 'VIEW,MANAGE');
    feature('INTEGRATIONS',     'Integrations',           'WORKFLOW_INTEGRATION', 240, 'Y', 'VIEW,CREATE,MANAGE');
    -- Admin: Security
    feature('USERS_ACCESS',     'Users ' || c_amp || ' Access',     'SECURITY', 310, 'Y', 'VIEW,CREATE,MANAGE');
    feature('ROLES_PRIVILEGES', 'Roles ' || c_amp || ' Privileges', 'SECURITY', 320, 'Y', 'VIEW,CREATE,MANAGE');
    feature('DATA_SECURITY',    'Data Security',          'SECURITY', 330, 'Y', 'VIEW,CREATE,MANAGE');
    feature('AUDIT_LOG',        'Audit Log',              'SECURITY', 340, 'Y', 'VIEW');
    -- Admin: Application
    feature('APP_SETTINGS',     'Application Settings',   'APPLICATION', 410, 'Y', 'VIEW,MANAGE');
    feature('USAGE_FEEDBACK',   'Usage ' || c_amp || ' Feedback',   'APPLICATION', 420, 'Y', 'VIEW,MANAGE');
    -- Transitional: replaced by approval tasks in My Tasks (Chunk 4).
    feature('CHANGE_APPROVALS', 'Configuration Change Approvals', 'BASIC_SETUP', 190, 'Y', 'VIEW,MANAGE');

    -- Current pages -> features
    pages('HOME',             '1,10010,10050,90,91');
    pages('MY_TASKS',         '30,31,40');
    pages('PARTIES',          '20,21,22,23,24,25');
    pages('CASES',            '32');
    pages('LOOKUPS',          '101,102');
    pages('FLEXFIELDS',       '150,151,152,153');
    pages('KYC_RULES',        '160,161,162,163,164');
    pages('ATTACHMENTS',      '130,131,132,133,134,135,136,137,138,139');
    pages('NOTIFICATIONS',    '109,110');
    pages('RETENTION',        '112,113');
    pages('WORKFLOW_SETUP',   '114,115,165,166');
    pages('WORKFLOW_MONITOR', '41');
    pages('INTEGRATIONS',     '120,121,122,123,124,125');
    pages('USERS_ACCESS',     '103,104');
    pages('ROLES_PRIVILEGES', '105,106,107,108');
    pages('AUDIT_LOG',        '111');
    pages('APP_SETTINGS',     '10020,10021');
    pages('USAGE_FEEDBACK',   '10030,10031,10032,10033,10051,10052');

    -- Grants that reproduce the previous role-based access
    grant_priv(c_all,   'HOME.VIEW,MY_TASKS.VIEW');
    grant_priv(c_staff, 'PARTIES.VIEW,PARTIES.CREATE,PARTIES.MANAGE,CASES.VIEW,CASES.CREATE,CASES.MANAGE');
    grant_priv(c_rules, 'KYC_RULES.VIEW,KYC_RULES.CREATE,KYC_RULES.MANAGE,'
                     || 'ATTACHMENTS.VIEW,ATTACHMENTS.CREATE,ATTACHMENTS.MANAGE,'
                     || 'WORKFLOW_SETUP.VIEW,WORKFLOW_SETUP.CREATE,WORKFLOW_SETUP.MANAGE,'
                     || 'CHANGE_APPROVALS.VIEW,CHANGE_APPROVALS.MANAGE');
    grant_priv('HEAD_OF_COMPLIANCE,SYSTEM_ADMIN', 'AUDIT_LOG.VIEW');
    grant_priv('SYSTEM_ADMIN',
               'LOOKUPS.VIEW,LOOKUPS.CREATE,LOOKUPS.MANAGE,FLEXFIELDS.VIEW,FLEXFIELDS.CREATE,FLEXFIELDS.MANAGE,'
            || 'NOTIFICATIONS.VIEW,NOTIFICATIONS.CREATE,NOTIFICATIONS.MANAGE,RETENTION.VIEW,RETENTION.CREATE,RETENTION.MANAGE,'
            || 'ALERT_RULES.VIEW,ALERT_RULES.CREATE,ALERT_RULES.MANAGE,WORKFLOW_MONITOR.VIEW,WORKFLOW_MONITOR.MANAGE,'
            || 'INTEGRATIONS.VIEW,INTEGRATIONS.CREATE,INTEGRATIONS.MANAGE,'
            || 'USERS_ACCESS.VIEW,USERS_ACCESS.CREATE,USERS_ACCESS.MANAGE,'
            || 'ROLES_PRIVILEGES.VIEW,ROLES_PRIVILEGES.CREATE,ROLES_PRIVILEGES.MANAGE,'
            || 'DATA_SECURITY.VIEW,DATA_SECURITY.CREATE,DATA_SECURITY.MANAGE,'
            || 'APP_SETTINGS.VIEW,APP_SETTINGS.MANAGE,USAGE_FEEDBACK.VIEW,USAGE_FEEDBACK.MANAGE');

    -- Row access: compliance staff and administrators see everything; a requester
    -- sees only the requests for information addressed to them.
    for r in (select column_value role_code from table(apex_string.split(c_staff || ',SYSTEM_ADMIN', ','))) loop
        rule(r.role_code, 'XXCMP_PARTIES', 'ALL_ROWS');
        rule(r.role_code, 'XXCMP_RFIS',    'ALL_ROWS');
    end loop;
    rule('REQUESTER', 'XXCMP_RFIS', 'OWN_RECORDS', 'RECIPIENT_USER_NAME');

    xxfnd_util_pkg.set_install_mode(false);
    commit;
    xxfnd_vpd_pkg.apply_policies;
end;
/

begin
    xxfnd_ddl_pkg.mark_release('R10', 'Release 10: security framework (features, privileges, data security)');
    commit;
end;
/


-- ==== 18d-workflow-platform.sql
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

    -- release 38: Task Details (42) and Case Decision (212) are removed; tasks open their own screens
    delete from xxfnd_feature_pages where app_alias = 'KYC' and page_id in (42, 212);

    xxfnd_util_pkg.set_install_mode(false);
    xxfnd_ddl_pkg.mark_release('R12', 'Release 12: native APEX workflow platform (tasks, My Tasks, monitor, setup)');
    commit;
end;
/


-- Invalid objects (expect no rows)
select object_type, object_name from user_objects where status <> 'VALID' order by 1, 2;
