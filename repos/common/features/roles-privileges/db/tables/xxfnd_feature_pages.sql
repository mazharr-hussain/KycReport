
create table if not exists xxfnd_feature_pages (
    app_alias              varchar2(255)  not null,
    page_id                number         not null,
    feature_code           varchar2(30)   not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_feature_pages_pk primary key (app_alias, page_id),
    constraint xxfnd_feature_pages_fk1 foreign key (feature_code) references xxfnd_features (feature_code)
);
comment on table xxfnd_feature_pages is 'Which feature an APEX page belongs to. Page authorization checks the privilege of this feature.';
comment on column xxfnd_feature_pages.tab_label is 'Tab shown on every list page of the same feature; null = not a tab (forms, dialogs).';

-- the Setup Types pages belong to the Applications feature (tabs Applications / Setup Types)
begin
    xxfnd_util_pkg.set_install_mode(true);
    update xxfnd_feature_pages set tab_label = 'Applications', tab_sequence = 10
     where app_alias = 'COMMON' and page_id = 160 and feature_code = 'APPLICATIONS' and tab_label is null;
    merge into xxfnd_feature_pages d
    using (select 162 page_id, 'Setup Types' tab_label, 20 tab_sequence from dual union all
           select 163, null, null from dual) s
       on (d.app_alias = 'COMMON' and d.page_id = s.page_id)
     when not matched then insert (app_alias, page_id, feature_code, tab_label, tab_sequence)
                           values ('COMMON', s.page_id, 'APPLICATIONS', s.tab_label, s.tab_sequence);
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

--------------------------------------------------------------------------------
-- The screens of the release: privileges and pages (every page has View and Manage; data security on the rows).
--   My Tasks: Notifications (43) and the task pages Information Request (143) and Configuration Change (144).
--   Notifications (setup): Notification Delivery (116) and Notification Log (117).
--   Communications (new): the e-mails of a record (45) and the E-mail dialog (46).
--------------------------------------------------------------------------------
declare
    l_app number;
    l_n   number;
    procedure page(p_feature in varchar2, p_page in number) is
    begin
        merge into xxfnd_feature_pages d
        using (select 'COMMON' app_alias, p_page page_id from dual) s
           on (d.app_alias = s.app_alias and d.page_id = s.page_id)
         when not matched then insert (app_alias, page_id, feature_code, tab_label, tab_sequence)
                               values ('COMMON', p_page, p_feature, null, null);
    end page;
begin
    xxfnd_util_pkg.set_install_mode(true);
    select application_id into l_app from xxfnd_applications where application_code = 'COMMON';
    merge into xxfnd_features t using (select 'COMMUNICATIONS' c from dual) s on (t.feature_code = s.c)
     when not matched then insert (feature_code, feature_name, feature_group, display_sequence, admin_flag,
                                   application_id, home_page_id, icon_css, description)
                           values ('COMMUNICATIONS', 'Communications', 'BUSINESS', 30, 'N', l_app, 45, 'fa-envelope-o',
                                   'The e-mails with outside people of a record of any application: send, record a received one, history.');
    merge into xxfnd_privileges t
    using (select 'COMMUNICATIONS.' || column_value pc, column_value act from table(apex_t_varchar2('VIEW', 'CREATE', 'MANAGE'))) s
       on (t.privilege_code = s.pc)
     when not matched then insert (privilege_code, feature_code, action_code, privilege_name)
                           values (s.pc, 'COMMUNICATIONS', s.act, 'Communications - ' || initcap(s.act));
    -- every role sees and sends the e-mails of the records it may see (data security of the application's record);
    -- recording a received e-mail (MANAGE): the roles that manage the notifications
    merge into xxfnd_role_privileges t
    using (select r.role_code, p.column_value pc
             from xxfnd_roles r cross join table(apex_t_varchar2('COMMUNICATIONS.VIEW', 'COMMUNICATIONS.CREATE')) p
           union
           select rp.role_code, 'COMMUNICATIONS.MANAGE' from xxfnd_role_privileges rp
            where rp.privilege_code = 'NOTIFICATIONS.MANAGE') s
       on (t.role_code = s.role_code and t.privilege_code = s.pc)
     when not matched then insert (role_code, privilege_code) values (s.role_code, s.pc);
    -- the approvers of configuration changes (COMMON process CONFIG_CHANGE): the privilege, when COMMON runs alone, granted
    -- once to the roles that manage the Approval Setup
    select count(*) into l_n from xxfnd_features where feature_code = 'CHANGE_APPROVALS';
    if l_n = 0 then
        insert into xxfnd_features (feature_code, feature_name, feature_group, display_sequence, admin_flag, application_id,
                                    icon_css, description)
        values ('CHANGE_APPROVALS', 'Configuration Change Approvals', 'WORKFLOW', 70, 'Y', l_app, 'fa-check-square-o',
                'Who approves the configuration changes of every application (maker-checker, process CONFIG_CHANGE).');
        insert into xxfnd_privileges (privilege_code, feature_code, action_code, privilege_name)
        select 'CHANGE_APPROVALS.' || column_value, 'CHANGE_APPROVALS', column_value,
               'Configuration Change Approvals - ' || initcap(column_value)
          from table(apex_t_varchar2('VIEW', 'MANAGE'))
         where not exists (select 1 from xxfnd_privileges where privilege_code = 'CHANGE_APPROVALS.' || column_value);
        insert into xxfnd_role_privileges (role_code, privilege_code)
        select rp.role_code, 'CHANGE_APPROVALS.' || a.column_value
          from xxfnd_role_privileges rp cross join table(apex_t_varchar2('VIEW', 'MANAGE')) a
         where rp.privilege_code = 'APPROVAL_SETUP.MANAGE'
           and not exists (select 1 from xxfnd_role_privileges x
                            where x.role_code = rp.role_code and x.privilege_code = 'CHANGE_APPROVALS.' || a.column_value);
    end if;
    -- the records of COMMON that keep files (an e-mail's file; an RFI's answer documents) and the category of a file
    -- kept with an e-mail: registered by COMMON itself (before release 84 only the KYC seed did)
    merge into xxfnd_document_entities t
    using (select 'XXFND_COMMUNICATIONS' entity_name, 'XXFND_COMMUNICATIONS' table_name, 'COMMUNICATION_ID' pk from dual
           union all select 'XXFND_RFIS', 'XXFND_RFIS', 'RFI_ID' from dual) s
       on (t.entity_name = s.entity_name)
     when not matched then insert (entity_name, application_code, table_name, pk1_column, enabled_flag)
                           values (s.entity_name, 'COMMON', s.table_name, s.pk, 'Y');
    merge into xxfnd_document_entities_tl t
    using (select 'XXFND_COMMUNICATIONS' entity_name, 'E-mail' user_name from dual
           union all select 'XXFND_RFIS', 'Request for Information' from dual) s
       on (t.entity_name = s.entity_name and t.language_code = 'en')
     when not matched then insert (entity_name, language_code, user_entity_name) values (s.entity_name, 'en', s.user_name);
    merge into xxfnd_document_categories t using (select 'OTHER' category_code from dual) s
       on (t.category_code = s.category_code)
     when not matched then insert (category_code, application_code, category_name, default_datatype_code, has_expiry_flag)
                           values ('OTHER', 'COMMON', 'Other Document', 'FILE', 'N');
    page('MY_TASKS', 43);
    page('MY_TASKS', 143);
    page('MY_TASKS', 144);
    page('NOTIFICATIONS', 116);
    page('NOTIFICATIONS', 117);
    page('COMMUNICATIONS', 45);
    page('COMMUNICATIONS', 46);
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
--------------------------------------------------------------------------------
-- 30 Application journey (release 86, part C). COMMON only (XXFUSION), after 29.
--   Applications are registered and maintained through one guided journey:
--   - page 165 Application Journey (create = register, edit = any step): Universal Theme wizard, steps Application,
--     Roles, Users, Shared functions, Setup types, Processes, Notifications, Document storage, Integrations, Review;
--   - page 166 Application (review): header card with the actions (Edit, Disable / Enable, Delete) and one section per
--     journey step; the sections are Global Page regions shared by 165 and 166.
--   Both pages belong to the feature APPLICATIONS (View for 166, Create for the journey on create, Manage for the
--   edit, disable and delete). Page 161 (the old Application form) is removed from the application; its
--   XXFND_FEATURE_PAGES row is left as it is (no data is deleted): a feature page that the application does not have
--   is never shown (menus, tabs and module lists join APEX_APPLICATION_PAGES) and grants nothing.
-- Idempotent: rows are added only when missing; a re-run changes nothing.
--------------------------------------------------------------------------------
declare
    procedure page(p_feature in varchar2, p_page in number) is
    begin
        -- the page belongs to the feature (its privileges decide who may open it), added when missing
        merge into xxfnd_feature_pages d
        using (select 'COMMON' app_alias, p_page page_id from dual) s
           on (d.app_alias = s.app_alias and d.page_id = s.page_id)
         when not matched then insert (app_alias, page_id, feature_code) values ('COMMON', p_page, p_feature);
    end page;
begin
    xxfnd_util_pkg.set_install_mode(true);
    page('APPLICATIONS', 165);   -- Application Journey (create and edit)
    page('APPLICATIONS', 166);   -- Application (review)
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
