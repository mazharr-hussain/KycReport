--------------------------------------------------------------------------------
-- 24 Workflow module (release 82, C5). COMMON only (XXFUSION), after 21b (the processes are synced there).
--   - XXFND_WORKFLOW_PROCESSES.PARTICIPANTS_TYPE (added in 09e, before XXFND_WORKFLOW_PKG): RULE or CHOSEN.
--   - RFI is a process of every registered application (XXFND_WORKFLOW_PKG.SYNC_PROCESSES adds it): its workflow
--     switch (off = no review task) and e-mail switch are set in the Process Catalogue like any other process.
--   - The Approval Setup type "Case request for information" (CASE_RFI) is disabled: the recipient of a request for
--     information is chosen by the person who raises it, the requester by default (no approval rule). Its rows stay.
-- Idempotent: checked steps; a re-run changes nothing.
--------------------------------------------------------------------------------
begin
    xxfnd_util_pkg.set_install_mode(true);
    begin
        xxfnd_workflow_pkg.sync_processes;   -- adds the RFI process of every application
    exception
        when others then
            -- the package was recompiled earlier in this install session (its state is discarded once): call again
            if sqlcode in (-4068, -4061, -4065, -6508) then
                xxfnd_workflow_pkg.sync_processes;
            else
                raise;
            end if;
    end;
    update xxfnd_workflow_processes set participants_type = 'CHOSEN'
     where process_code = xxfnd_workflow_pkg.c_rfi_process and participants_type <> 'CHOSEN';
    update xxfnd_approval_types set enabled_flag = 'N'
     where approval_type_code = 'CASE_RFI' and enabled_flag = 'Y';
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/

--------------------------------------------------------------------------------
-- My Tasks across applications (D20, COMMON page 40) and the Workflow Monitor (D19, COMMON pages 141 / 142).
--   MY_TASKS is shared with the applications (KYC registers it too): COMMON adds it when missing, with VIEW and
--   MANAGE, and every role may view its own tasks. WORKFLOW_MONITOR (19c) gets its pages.
-- Notifications: the wording is plain text (MESSAGE_TEXT, filled once from the HTML of older rows); RFI_RESPONDED
--   and CONFIG_CHANGE_PENDING are disabled (their rows stay).
--------------------------------------------------------------------------------
declare
    l_app number;
    procedure page(p_feature in varchar2, p_page in number, p_label in varchar2 default null, p_seq in number default null) is
    begin
        merge into xxfnd_feature_pages d
        using (select 'COMMON' app_alias, p_page page_id from dual) s
           on (d.app_alias = s.app_alias and d.page_id = s.page_id)
         when not matched then insert (app_alias, page_id, feature_code, tab_label, tab_sequence)
                               values ('COMMON', p_page, p_feature, p_label, p_seq);
    end page;
begin
    xxfnd_util_pkg.set_install_mode(true);
    select application_id into l_app from xxfnd_applications where application_code = 'COMMON';

    merge into xxfnd_features t using (select 'MY_TASKS' c from dual) s on (t.feature_code = s.c)
     when not matched then insert (feature_code, feature_name, feature_group, display_sequence, admin_flag,
                                   application_id, home_page_id, icon_css, description)
                           values ('MY_TASKS', 'My Tasks', 'BUSINESS', 20, 'N', l_app, 40, 'fa-inbox',
                                   'The tasks of the signed-in user from every application.');
    merge into xxfnd_privileges t
    using (select 'MY_TASKS.' || column_value pc, column_value act from table(apex_t_varchar2('VIEW', 'MANAGE'))) s
       on (t.privilege_code = s.pc)
     when not matched then insert (privilege_code, feature_code, action_code, privilege_name)
                           values (s.pc, 'MY_TASKS', s.act, 'My Tasks - ' || initcap(s.act));
    -- every role sees and works its own tasks (APEX checks who may act on each task)
    merge into xxfnd_role_privileges t
    using (select r.role_code, p.column_value pc
             from xxfnd_roles r cross join table(apex_t_varchar2('MY_TASKS.VIEW', 'MY_TASKS.MANAGE')) p) s
       on (t.role_code = s.role_code and t.privilege_code = s.pc)
     when not matched then insert (role_code, privilege_code) values (s.role_code, s.pc);
    page('MY_TASKS', 40);

    update xxfnd_features set home_page_id = 141 where feature_code = 'WORKFLOW_MONITOR' and home_page_id is null;
    page('WORKFLOW_MONITOR', 141);
    page('WORKFLOW_MONITOR', 142);

    -- notifications: wording only
    update xxfnd_notification_templates
       set message_text = regexp_replace(regexp_replace(body_html, '<br\s*/?>|</p>|</div>|</li>', chr(10), 1, 0, 'i'), '<[^>]+>', '')
     where message_text is null and body_html is not null;
    update xxfnd_notification_templates_tl
       set message_text = regexp_replace(regexp_replace(body_html, '<br\s*/?>|</p>|</div>|</li>', chr(10), 1, 0, 'i'), '<[^>]+>', '')
     where message_text is null and body_html is not null;
    -- release 84: only before the notification events exist (release 84 tells the RFI's requester with RFI_RESPONDED;
    -- an administrator's later choice is kept)
    update xxfnd_notification_templates set enabled_flag = 'N'
     where enabled_flag = 'Y'
       and (template_code = 'CONFIG_CHANGE_PENDING'
            or (template_code = 'RFI_RESPONDED'
                and not exists (select 1 from xxfnd_notify_events where event_code = 'RFI_ANSWERED')));

    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
