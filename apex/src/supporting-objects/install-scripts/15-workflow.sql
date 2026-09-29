--------------------------------------------------------------------------------
-- 08_xxfnd_wf_pkg.sql
-- Workflow engine runtime (0.2). One generic engine; each business process
-- (KYC case, RFI, ...) is a separate item type + process definition, as in
-- EBS Workflow / Fusion BPM. The engine knows nothing about KYC.
--
--   Activity types
--     START         entry point; advances immediately on result DEFAULT
--     NOTIFICATION  queues an FYI email to the performer role, then advances on DEFAULT
--     TASK/APPROVAL waits for a person holding PERFORMER_ROLE_CODE (or their delegate)
--     WAIT          waits for the application to call COMPLETE_ACTIVITY (e.g. RFI answered)
--     END           completes the item
--   A WAIT/TASK/APPROVAL with TIMEOUT_HOURS moves on result TIMEOUT when a
--   TIMEOUT transition exists (job XXFND_WF_MAILER checks).
--
--   Notifications are only queued here; XXFND_WF_PKG.SEND_QUEUED (scheduler
--   job, every 5 minutes) sends them, so a mail outage never blocks a save.
--------------------------------------------------------------------------------

create or replace package xxfnd_wf_pkg authid definer as

    c_default constant varchar2(30) := 'DEFAULT';
    c_timeout constant varchar2(30) := 'TIMEOUT';

    -- Starts the active version of a process for one business record.
    -- P_TOKENS_JSON adds #TOKEN# values for the notification templates.
    function start_item(p_item_type    in varchar2,
                        p_process_code in varchar2,
                        p_entity_name  in varchar2,
                        p_pk1_value    in varchar2,
                        p_tokens_json  in clob default null) return number;

    -- Records the current user's decision and moves the item on.
    -- P_EXPECTED_ACTIVITY_ID guards against acting from a stale screen.
    procedure complete_activity(p_wf_item_id           in number,
                                p_result_code          in varchar2,
                                p_notes                in varchar2 default null,
                                p_expected_activity_id in number   default null,
                                p_tokens_json          in clob     default null);

    -- Y/N for button conditions: may the current user act on the item now?
    function can_act(p_wf_item_id in number, p_user_name in varchar2 default null) return varchar2;
    -- Reason the user may not act, or null.
    function cannot_act_reason(p_wf_item_id in number, p_user_name in varchar2 default null) return varchar2;

    -- Result codes available from the item's current activity (for a select list).
    function available_results(p_wf_item_id in number) return apex_t_varchar2;

    -- Current active item for a record, or null.
    function active_item(p_entity_name in varchar2, p_pk1_value in varchar2,
                         p_item_type in varchar2 default null) return number;

    -- Makes one process version the active one (the others are deactivated first,
    -- so the one-active-version index is never violated). Running items stay on
    -- the version they started on.
    procedure activate_version(p_item_type in varchar2, p_process_code in varchar2, p_version_number in number);

    -- Administrator actions (Workflow Monitor).
    procedure suspend_item(p_wf_item_id in number, p_reason in varchar2);
    procedure resume_item (p_wf_item_id in number);
    procedure cancel_item (p_wf_item_id in number, p_reason in varchar2);
    -- Moves a stuck item to another activity of the same process version.
    procedure reassign_activity(p_wf_item_id in number, p_activity_code in varchar2, p_reason in varchar2);

    -- Scheduler job: timeouts, then send queued notifications through APEX_MAIL.
    procedure send_queued(p_workspace in varchar2, p_app_alias in varchar2, p_max_rows in pls_integer default 500);
    procedure process_timeouts;

end xxfnd_wf_pkg;
/

create or replace package body xxfnd_wf_pkg as

    ----------------------------------------------------------------------------
    -- helpers
    ----------------------------------------------------------------------------
    function norm(p_user in varchar2) return varchar2 is
    begin
        return upper(nvl(p_user, xxfnd_util_pkg.current_user));
    end norm;

    function get_activity(p_activity_id in number) return xxfnd_wf_activities%rowtype is
        l_act xxfnd_wf_activities%rowtype;
    begin
        select * into l_act from xxfnd_wf_activities where activity_id = p_activity_id;
        return l_act;
    end get_activity;

    function get_item(p_wf_item_id in number, p_lock in boolean default false) return xxfnd_wf_items%rowtype is
        l_item xxfnd_wf_items%rowtype;
    begin
        if p_lock then
            select * into l_item from xxfnd_wf_items where wf_item_id = p_wf_item_id for update;
        else
            select * into l_item from xxfnd_wf_items where wf_item_id = p_wf_item_id;
        end if;
        return l_item;
    exception
        when no_data_found then
            raise_application_error(-20400, 'Workflow item ' || p_wf_item_id || ' does not exist.');
    end get_item;

    -- Person the user is acting for: themselves when they hold the role, else a
    -- delegator (active vacation rule) who holds it. Null when neither.
    function acting_for(p_role_code in varchar2, p_item_type in varchar2, p_user in varchar2) return varchar2 is
        l_delegator varchar2(255);
    begin
        if p_role_code is null or xxfnd_security_pkg.has_role(p_role_code, p_user) then
            return p_user;
        end if;
        select min(d.delegator_user_name)
          into l_delegator
          from xxfnd_wf_delegations d
         where upper(d.delegate_user_name) = p_user
           and (d.item_type is null or d.item_type = p_item_type)
           and trunc(sysdate) between d.start_date and d.end_date
           and xxfnd_security_pkg.has_role_yn(p_role_code, d.delegator_user_name) = 'Y';
        return upper(l_delegator);
    end acting_for;

    function standard_tokens(p_item in xxfnd_wf_items%rowtype, p_act in xxfnd_wf_activities%rowtype,
                             p_extra in clob) return clob is
        l_obj json_object_t := case when p_extra is null then json_object_t() else json_object_t.parse(p_extra) end;
    begin
        l_obj.put('WF_ITEM_ID',    p_item.wf_item_id);
        l_obj.put('ITEM_TYPE',     p_item.item_type);
        l_obj.put('ENTITY_NAME',   p_item.entity_name);
        l_obj.put('PK1_VALUE',     p_item.pk1_value);
        l_obj.put('ACTIVITY_NAME', p_act.activity_name);
        l_obj.put('DUE_DATE', case when p_act.timeout_hours is not null
                                   then to_char(systimestamp + numtodsinterval(p_act.timeout_hours, 'HOUR'),
                                                'DD-Mon-YYYY HH24:MI') end);
        return l_obj.to_clob;
    end standard_tokens;

    -- Queue one notification per holder of the performer role, redirected to
    -- the active delegate where a vacation rule exists.
    procedure queue_notifications(p_item in xxfnd_wf_items%rowtype, p_act in xxfnd_wf_activities%rowtype,
                                  p_tokens in clob) is
        l_subject varchar2(500);
        l_body    clob;
        l_tokens  clob;
    begin
        if p_act.notification_template_code is null or p_act.performer_role_code is null then
            return;
        end if;
        begin
            select nvl(t.subject, n.subject), nvl(t.body_html, n.body_html)
              into l_subject, l_body
              from xxfnd_notification_templates n
              left join xxfnd_notification_templates_tl t
                on t.template_code = n.template_code
               and t.language_code = 'en'
             where n.template_code = p_act.notification_template_code
               and n.enabled_flag = 'Y';
        exception
            when no_data_found then
                return;   -- template disabled: the task still appears in the worklist
        end;
        l_tokens  := standard_tokens(p_item, p_act, p_tokens);
        l_subject := dbms_lob.substr(xxfnd_util_pkg.replace_tokens(l_subject, l_tokens), 500, 1);
        l_body    := xxfnd_util_pkg.replace_tokens(l_body, l_tokens);

        for r in (select v.user_name,
                         (select upper(min(d.delegate_user_name))
                            from xxfnd_wf_delegations d
                           where upper(d.delegator_user_name) = v.user_name
                             and (d.item_type is null or d.item_type = p_item.item_type)
                             and trunc(sysdate) between d.start_date and d.end_date) delegate_user
                    from xxfnd_user_roles_v v
                   where v.role_code = p_act.performer_role_code
                     and v.active_flag = 'Y')
        loop
            insert into xxfnd_wf_notifications (wf_item_id, activity_id, recipient_user_name, original_recipient,
                                                template_code, status_code, subject, body_html, due_date)
            values (p_item.wf_item_id, p_act.activity_id, nvl(r.delegate_user, r.user_name),
                    case when r.delegate_user is not null then r.user_name end,
                    p_act.notification_template_code, 'QUEUED', l_subject, l_body,
                    case when p_act.timeout_hours is not null
                         then systimestamp + numtodsinterval(p_act.timeout_hours, 'HOUR') end);
        end loop;
    end queue_notifications;

    procedure enter_activity(p_item in out nocopy xxfnd_wf_items%rowtype, p_activity_id in number,
                             p_tokens in clob);

    -- Moves along the transition for p_result, then keeps going through
    -- automatic activities (START, NOTIFICATION, END).
    procedure transition(p_item in out nocopy xxfnd_wf_items%rowtype, p_result in varchar2, p_tokens in clob) is
        l_next number;
    begin
        begin
            select to_activity_id into l_next
              from xxfnd_wf_transitions
             where from_activity_id = p_item.current_activity_id
               and result_code = p_result;
        exception
            when no_data_found then
                raise_application_error(-20401, 'The process has no path for result ' || p_result
                    || ' from activity ' || get_activity(p_item.current_activity_id).activity_code || '.');
        end;
        enter_activity(p_item, l_next, p_tokens);
    end transition;

    procedure enter_activity(p_item in out nocopy xxfnd_wf_items%rowtype, p_activity_id in number,
                             p_tokens in clob) is
        l_act xxfnd_wf_activities%rowtype := get_activity(p_activity_id);
    begin
        p_item.current_activity_id := p_activity_id;
        update xxfnd_wf_items set current_activity_id = p_activity_id where wf_item_id = p_item.wf_item_id;
        insert into xxfnd_wf_activity_history (wf_item_id, activity_id) values (p_item.wf_item_id, p_activity_id);

        case l_act.activity_type
            when 'END' then
                update xxfnd_wf_activity_history
                   set exited_date = systimestamp, result_code = c_default, actioned_by = 'SYSTEM'
                 where wf_item_id = p_item.wf_item_id and activity_id = p_activity_id and exited_date is null;
                update xxfnd_wf_items
                   set item_status = 'COMPLETE', completed_date = systimestamp
                 where wf_item_id = p_item.wf_item_id;
                p_item.item_status := 'COMPLETE';
            when 'NOTIFICATION' then
                queue_notifications(p_item, l_act, p_tokens);
                update xxfnd_wf_activity_history
                   set exited_date = systimestamp, result_code = c_default, actioned_by = 'SYSTEM'
                 where wf_item_id = p_item.wf_item_id and activity_id = p_activity_id and exited_date is null;
                transition(p_item, c_default, p_tokens);
            when 'START' then
                update xxfnd_wf_activity_history
                   set exited_date = systimestamp, result_code = c_default, actioned_by = 'SYSTEM'
                 where wf_item_id = p_item.wf_item_id and activity_id = p_activity_id and exited_date is null;
                transition(p_item, c_default, p_tokens);
            else  -- TASK, APPROVAL, WAIT: stop here and tell the performers
                queue_notifications(p_item, l_act, p_tokens);
        end case;
    end enter_activity;

    ----------------------------------------------------------------------------
    -- public
    ----------------------------------------------------------------------------
    function start_item(p_item_type    in varchar2,
                        p_process_code in varchar2,
                        p_entity_name  in varchar2,
                        p_pk1_value    in varchar2,
                        p_tokens_json  in clob default null) return number is
        l_version number;
        l_start   number;
        l_item    xxfnd_wf_items%rowtype;
    begin
        begin
            select version_number into l_version
              from xxfnd_wf_processes
             where item_type = p_item_type and process_code = p_process_code and active_flag = 'Y';
            select activity_id into l_start
              from xxfnd_wf_activities
             where item_type = p_item_type and process_code = p_process_code
               and version_number = l_version and start_flag = 'Y';
        exception
            when no_data_found then
                raise_application_error(-20402, 'Process ' || p_item_type || '/' || p_process_code
                    || ' has no active version with a start activity.');
        end;

        insert into xxfnd_wf_items (item_type, process_code, version_number, entity_name, pk1_value,
                                    current_activity_id, item_status)
        values (p_item_type, p_process_code, l_version, p_entity_name, p_pk1_value, l_start, 'ACTIVE')
        returning wf_item_id into l_item.wf_item_id;
        l_item := get_item(l_item.wf_item_id);

        enter_activity(l_item, l_start, p_tokens_json);
        return l_item.wf_item_id;
    exception
        when dup_val_on_index then
            raise_application_error(-20403, 'This record already has an active ' || p_item_type || ' workflow.');
    end start_item;

    function cannot_act_reason(p_wf_item_id in number, p_user_name in varchar2 default null) return varchar2 is
        l_item xxfnd_wf_items%rowtype := get_item(p_wf_item_id);
        l_act  xxfnd_wf_activities%rowtype := get_activity(l_item.current_activity_id);
        l_user varchar2(255) := norm(p_user_name);
        l_for  varchar2(255);
    begin
        if l_item.item_status <> 'ACTIVE' then
            return 'This item is ' || lower(l_item.item_status) || '.';
        end if;
        if l_act.activity_type not in ('TASK','APPROVAL','WAIT') then
            return 'The current step does not take a decision.';
        end if;
        l_for := acting_for(l_act.performer_role_code, l_item.item_type, l_user);
        if l_for is null then
            return 'You do not hold the role for this step.';
        end if;
        if l_act.performer_role_code is not null
           and (xxfnd_security_pkg.sod_conflict(p_wf_item_id, l_act.performer_role_code, l_user)
                or (l_for <> l_user and xxfnd_security_pkg.sod_conflict(p_wf_item_id, l_act.performer_role_code, l_for))) then
            return 'Segregation of duties: you already acted on this item in a conflicting role.';
        end if;
        return null;
    end cannot_act_reason;

    function can_act(p_wf_item_id in number, p_user_name in varchar2 default null) return varchar2 is
    begin
        return case when cannot_act_reason(p_wf_item_id, p_user_name) is null then 'Y' else 'N' end;
    end can_act;

    function available_results(p_wf_item_id in number) return apex_t_varchar2 is
        l_results apex_t_varchar2;
    begin
        select t.result_code bulk collect into l_results
          from xxfnd_wf_items i
          join xxfnd_wf_transitions t on t.from_activity_id = i.current_activity_id
         where i.wf_item_id = p_wf_item_id
           and t.result_code <> c_timeout
         order by t.result_code;
        return l_results;
    end available_results;

    procedure complete_activity(p_wf_item_id           in number,
                                p_result_code          in varchar2,
                                p_notes                in varchar2 default null,
                                p_expected_activity_id in number   default null,
                                p_tokens_json          in clob     default null) is
        l_item   xxfnd_wf_items%rowtype := get_item(p_wf_item_id, p_lock => true);
        l_act    xxfnd_wf_activities%rowtype := get_activity(l_item.current_activity_id);
        l_user   varchar2(255) := norm(null);
        l_for    varchar2(255);
        l_reason varchar2(4000);
    begin
        if p_expected_activity_id is not null and p_expected_activity_id <> l_item.current_activity_id then
            raise_application_error(-20404, 'Someone else has already moved this item on. Refresh the page.');
        end if;
        -- WAIT steps may be completed by the system (e.g. an RFI answered by an external party).
        if not (l_act.activity_type = 'WAIT' and l_act.performer_role_code is null) then
            l_reason := cannot_act_reason(p_wf_item_id, l_user);
            if l_reason is not null then
                raise_application_error(-20405, l_reason);
            end if;
        end if;
        l_for := acting_for(l_act.performer_role_code, l_item.item_type, l_user);

        update xxfnd_wf_activity_history
           set exited_date  = systimestamp,
               result_code  = p_result_code,
               actioned_by  = l_user,
               on_behalf_of = case when l_for <> l_user then l_for end,
               notes        = p_notes
         where wf_item_id = p_wf_item_id
           and activity_id = l_item.current_activity_id
           and exited_date is null;

        update xxfnd_wf_notifications
           set status_code    = case when recipient_user_name = l_user then 'RESPONDED' else 'CANCELLED' end,
               responded_date = case when recipient_user_name = l_user then systimestamp end
         where wf_item_id = p_wf_item_id
           and activity_id = l_item.current_activity_id
           and status_code in ('QUEUED','SENT');

        transition(l_item, p_result_code, p_tokens_json);
    end complete_activity;

    function active_item(p_entity_name in varchar2, p_pk1_value in varchar2,
                         p_item_type in varchar2 default null) return number is
        l_id number;
    begin
        select max(wf_item_id) into l_id
          from xxfnd_wf_items
         where entity_name = p_entity_name and pk1_value = p_pk1_value
           and (p_item_type is null or item_type = p_item_type)
           and item_status in ('ACTIVE','SUSPENDED');
        return l_id;
    end active_item;

    procedure activate_version(p_item_type in varchar2, p_process_code in varchar2, p_version_number in number) is
        l_starts pls_integer;
    begin
        select count(*) into l_starts
          from xxfnd_wf_activities
         where item_type = p_item_type and process_code = p_process_code
           and version_number = p_version_number and start_flag = 'Y';
        if l_starts = 0 then
            raise_application_error(-20410, 'This version has no start activity.');
        end if;
        update xxfnd_wf_processes set active_flag = 'N'
         where item_type = p_item_type and process_code = p_process_code
           and version_number <> p_version_number and active_flag = 'Y';
        update xxfnd_wf_processes set active_flag = 'Y'
         where item_type = p_item_type and process_code = p_process_code and version_number = p_version_number;
    end activate_version;

    procedure admin_note(p_wf_item_id in number, p_activity_id in number, p_note in varchar2) is
        l_user varchar2(255) := norm(null);   -- NORM is private: not callable inside SQL (PLS-00231)
    begin
        insert into xxfnd_wf_activity_history (wf_item_id, activity_id, actioned_by, result_code, notes, exited_date)
        values (p_wf_item_id, p_activity_id, l_user, 'ADMIN', p_note, systimestamp);
    end admin_note;

    procedure suspend_item(p_wf_item_id in number, p_reason in varchar2) is
        l_item xxfnd_wf_items%rowtype := get_item(p_wf_item_id, true);
    begin
        if l_item.item_status <> 'ACTIVE' then
            raise_application_error(-20406, 'Only an active item can be suspended.');
        end if;
        update xxfnd_wf_items set item_status = 'SUSPENDED' where wf_item_id = p_wf_item_id;
        admin_note(p_wf_item_id, l_item.current_activity_id, 'Suspended: ' || p_reason);
    end suspend_item;

    procedure resume_item(p_wf_item_id in number) is
        l_item xxfnd_wf_items%rowtype := get_item(p_wf_item_id, true);
    begin
        if l_item.item_status <> 'SUSPENDED' then
            raise_application_error(-20407, 'Only a suspended item can be resumed.');
        end if;
        update xxfnd_wf_items set item_status = 'ACTIVE' where wf_item_id = p_wf_item_id;
        admin_note(p_wf_item_id, l_item.current_activity_id, 'Resumed');
    end resume_item;

    procedure cancel_item(p_wf_item_id in number, p_reason in varchar2) is
        l_item xxfnd_wf_items%rowtype := get_item(p_wf_item_id, true);
    begin
        if l_item.item_status not in ('ACTIVE','SUSPENDED') then
            raise_application_error(-20408, 'This item is already closed.');
        end if;
        if p_reason is null then
            raise_application_error(-20409, 'Enter a reason for cancelling.');
        end if;
        update xxfnd_wf_items set item_status = 'CANCELLED', completed_date = systimestamp
         where wf_item_id = p_wf_item_id;
        update xxfnd_wf_activity_history set exited_date = systimestamp, result_code = 'CANCELLED'
         where wf_item_id = p_wf_item_id and exited_date is null;
        update xxfnd_wf_notifications set status_code = 'CANCELLED'
         where wf_item_id = p_wf_item_id and status_code in ('QUEUED','SENT');
        admin_note(p_wf_item_id, l_item.current_activity_id, 'Cancelled: ' || p_reason);
    end cancel_item;

    procedure reassign_activity(p_wf_item_id in number, p_activity_code in varchar2, p_reason in varchar2) is
        l_item   xxfnd_wf_items%rowtype := get_item(p_wf_item_id, true);
        l_target number;
        l_user   varchar2(255) := norm(null);   -- NORM is private: not callable inside SQL (PLS-00231)
    begin
        if p_reason is null then
            raise_application_error(-20409, 'Enter a reason for moving this item.');
        end if;
        select activity_id into l_target
          from xxfnd_wf_activities
         where item_type = l_item.item_type and process_code = l_item.process_code
           and version_number = l_item.version_number and activity_code = p_activity_code;
        update xxfnd_wf_activity_history set exited_date = systimestamp, result_code = 'ADMIN_MOVED',
                                             actioned_by = l_user, notes = p_reason
         where wf_item_id = p_wf_item_id and exited_date is null;
        update xxfnd_wf_notifications set status_code = 'CANCELLED'
         where wf_item_id = p_wf_item_id and status_code in ('QUEUED','SENT');
        enter_activity(l_item, l_target, null);
    end reassign_activity;

    procedure process_timeouts is
    begin
        for r in (select i.wf_item_id
                    from xxfnd_wf_items i
                    join xxfnd_wf_activities a on a.activity_id = i.current_activity_id
                    join xxfnd_wf_activity_history h
                      on h.wf_item_id = i.wf_item_id and h.activity_id = i.current_activity_id and h.exited_date is null
                   where i.item_status = 'ACTIVE'
                     and a.timeout_hours is not null
                     and h.entered_date + numtodsinterval(a.timeout_hours, 'HOUR') < systimestamp
                     and exists (select 1 from xxfnd_wf_transitions t
                                  where t.from_activity_id = a.activity_id and t.result_code = c_timeout))
        loop
            declare
                l_item xxfnd_wf_items%rowtype;
            begin
                l_item := get_item(r.wf_item_id, true);
                update xxfnd_wf_activity_history
                   set exited_date = systimestamp, result_code = c_timeout, actioned_by = 'SYSTEM'
                 where wf_item_id = r.wf_item_id and exited_date is null;
                update xxfnd_wf_notifications set status_code = 'EXPIRED'
                 where wf_item_id = r.wf_item_id and activity_id = l_item.current_activity_id
                   and status_code in ('QUEUED','SENT');
                transition(l_item, c_timeout, null);
                commit;
            exception
                when others then
                    rollback;   -- one broken item must not stop the others
            end;
        end loop;
    end process_timeouts;

    procedure send_queued(p_workspace in varchar2, p_app_alias in varchar2, p_max_rows in pls_integer default 500) is
        l_app_id number;
        l_from   varchar2(320);
        l_email  varchar2(320);
        l_sent   pls_integer := 0;
        l_error  varchar2(4000);
    begin
        process_timeouts;

        -- APEX_MAIL needs an APEX session; the application's settings supply the sender.
        select application_id into l_app_id
          from apex_applications
         where workspace = upper(p_workspace) and upper(alias) = upper(p_app_alias)
           and application_id = (select max(application_id) from apex_applications
                                  where workspace = upper(p_workspace) and upper(alias) = upper(p_app_alias));
        apex_session.create_session(p_app_id => l_app_id, p_page_id => 1, p_username => 'XXFND_WF_MAILER');
        l_from := apex_app_setting.get_value('MAIL_FROM');
        if l_from is null then
            apex_session.delete_session;   -- not configured yet: leave notifications queued
            return;
        end if;

        for n in (select notification_id, recipient_user_name, subject, body_html
                    from xxfnd_wf_notifications
                   where status_code = 'QUEUED'
                   order by queued_date
                   fetch first p_max_rows rows only)
        loop
            begin
                select email_address into l_email
                  from xxfnd_employees
                 where user_name = n.recipient_user_name and enabled_flag = 'Y';
                apex_mail.send(p_to => l_email, p_from => l_from, p_subj => n.subject,
                               p_body => apex_escape.striphtml(n.body_html), p_body_html => n.body_html);
                update xxfnd_wf_notifications set status_code = 'SENT', sent_date = systimestamp, error_message = null
                 where notification_id = n.notification_id;
                l_sent := l_sent + 1;
            exception
                when others then
                    l_error := substr(sqlerrm, 1, 4000);   -- SQLERRM cannot be used inside SQL (ORA-00904)
                    update xxfnd_wf_notifications set status_code = 'FAILED', error_message = l_error
                     where notification_id = n.notification_id;
            end;
        end loop;
        commit;
        if l_sent > 0 then
            apex_mail.push_queue;
        end if;
        apex_session.delete_session;
    exception
        when others then
            rollback;
            if apex_application.g_instance is not null then
                apex_session.delete_session;
            end if;
            raise;
    end send_queued;

end xxfnd_wf_pkg;
/
