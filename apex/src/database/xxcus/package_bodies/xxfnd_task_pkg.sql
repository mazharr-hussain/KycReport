create or replace package body xxcus.xxfnd_task_pkg as

    function users_in_role (
        p_role_code in varchar2,
        p_exclude   in varchar2 default null
    ) return varchar2 is
        l_list varchar2(32767);
    begin
        select
            listagg(distinct ur.user_name, ',') within group(
            order by
                ur.user_name
            )
        into l_list
        from
            xxfnd_user_roles_v ur
        where
                ur.role_code = upper(p_role_code)
            and ur.active_flag = 'Y'
            and ur.user_name <> upper(nvl(p_exclude, '#'));

        return l_list;
    end users_in_role;

    function users_with_privilege (
        p_feature_code in varchar2,
        p_action       in varchar2,
        p_exclude      in varchar2 default null
    ) return varchar2 is
        l_list varchar2(32767);
    begin
        select
            listagg(distinct ur.user_name, ',') within group(
            order by
                ur.user_name
            )
        into l_list
        from
                 xxfnd_user_roles_v ur
            join xxfnd_role_privileges rp on rp.role_code = ur.role_code
        where
                rp.privilege_code = upper(p_feature_code)
                                    || '.'
                                    || upper(p_action)
            and ur.active_flag = 'Y'
            and ur.user_name <> upper(nvl(p_exclude, '#'));

        return l_list;
    end users_with_privilege;

    function business_admins return varchar2 is
    begin
        return users_with_privilege('WORKFLOW_MONITOR', 'MANAGE');
    end business_admins;

    function due_date (
        p_task_definition in varchar2
    ) return timestamp with time zone is
        l_days number;
    begin
        select
            max(due_days)
        into l_days
        from
            xxfnd_task_settings
        where
            task_definition = p_task_definition;

        return
            case
                when l_days is not null then
                    systimestamp + numtodsinterval(l_days, 'DAY')
            end;
    end due_date;

    function create_task (
        p_task_definition in varchar2,
        p_detail_pk       in varchar2,
        p_subject         in varchar2 default null,
        p_parameters      in apex_human_task.t_task_parameters default c_no_parameters
    ) return number is
    begin
        return apex_human_task.create_task(
            p_application_id     => v('APP_ID'),
            p_task_def_static_id => p_task_definition,
            p_subject            => p_subject,
            p_parameters         => p_parameters,
            p_detail_pk          => p_detail_pk,
            p_due_date           => due_date(p_task_definition)
        );
    end create_task;

    procedure complete_open (
        p_task_definition in varchar2,
        p_detail_pk       in varchar2,
        p_outcome         in varchar2 default null
    ) is
    begin
        for t in (
            select
                task_id
            from
                apex_tasks
            where
                    task_def_static_id = p_task_definition
                and detail_pk = p_detail_pk
                and state_code in ( 'UNASSIGNED', 'ASSIGNED' )
                and application_id = v('APP_ID')
        ) loop
            -- An unassigned task (several potential owners) is claimed and completed in one go.
            if apex_human_task.is_allowed(
                p_task_id   => t.task_id,
                p_operation => apex_human_task.c_task_op_complete
            )
            or apex_human_task.is_allowed(
                p_task_id   => t.task_id,
                p_operation => apex_human_task.c_task_op_claim
            ) then
                apex_human_task.complete_task(
                    p_task_id   => t.task_id,
                    p_outcome   => p_outcome,
                    p_autoclaim => true
                );

            end if;
        end loop;
    end complete_open;

    procedure cancel_open (
        p_task_definition in varchar2,
        p_detail_pk       in varchar2
    ) is
    begin
        for t in (
            select
                task_id
            from
                apex_tasks
            where
                    task_def_static_id = p_task_definition
                and detail_pk = p_detail_pk
                and state_code in ( 'UNASSIGNED', 'ASSIGNED', 'INFO_REQUESTED' )
                and application_id = v('APP_ID')
        ) loop
            if apex_human_task.is_allowed(
                p_task_id   => t.task_id,
                p_operation => apex_human_task.c_task_op_cancel
            ) then
                apex_human_task.cancel_task(p_task_id => t.task_id);
            end if;
        end loop;
    end cancel_open;

    function last_comment (
        p_task_id in number
    ) return varchar2 is
        l_text varchar2(4000);
    begin
        select
            max(substr(text, 1, 4000)) keep(dense_rank last order by created_on)
        into l_text
        from
            apex_task_comments
        where
            task_id = p_task_id;

        return l_text;
    end last_comment;

    procedure vacation_rule (
        p_param  in apex_human_task.t_vacation_rule_input,
        p_result out apex_human_task.t_vacation_rule_result
    ) is
        l_idx pls_integer := 0;
    begin
        for i in 1..p_param.original_participants.count loop
            if
                p_param.original_participants(i).type = apex_human_task.c_task_potential_owner
                and p_param.original_participants(i).identity = apex_human_task.c_task_identity_type_user
            then
                for d in (
                    select
                        d.delegate_user_name,
                        d.reason
                    from
                        xxfnd_wf_delegations d
                    where
                            d.delegator_user_name = upper(p_param.original_participants(i).value)
                        and trunc(sysdate) between d.start_date and d.end_date
                        and ( d.task_definition is null
                              or d.task_definition = p_param.task_def_static_id )
                ) loop
                    l_idx := l_idx + 1;
                    p_result.participant_changes(l_idx) := apex_human_task.t_task_participant_change(
                        apex_human_task.t_task_participant(apex_human_task.c_task_potential_owner,
                                                           apex_human_task.c_task_identity_type_user,
                                                           p_param.original_participants(i).value),
                        apex_human_task.t_task_participant(apex_human_task.c_task_potential_owner, apex_human_task.c_task_identity_type_user
                        , d.delegate_user_name),
                        nvl(d.reason,
                            d.delegate_user_name
                            || ' covering for '
                            || p_param.original_participants(i).value)
                    );

                end loop;

            end if;
        end loop;

        p_result.has_participant_changes := l_idx > 0;
    end vacation_rule;

    function task_tokens (
        p_task_id in number
    ) return clob is
        l_json      json_object_t := json_object_t();
        l_url       varchar2(4000);
        l_assignees varchar2(4000);
    begin
        for t in (
            select
                subject,
                due_on
            from
                apex_tasks
            where
                task_id = p_task_id
        ) loop
            l_json.put('TASK_SUBJECT',
                       apex_escape.html(t.subject));
            l_json.put('DUE_DATE',
                       nvl(
                    to_char(t.due_on, 'DD-Mon-YYYY HH24:MI'),
                    'no due date'
                ));

        end loop;

        begin
            l_url := apex_page.get_url(
                p_page      => 40,
                p_plain_url => true
            );
        exception
            when others then
                l_url := null;   -- no APEX session (e.g. called from SQL*Plus)
        end;

        l_json.put('TASK_URL', l_url);
        select
            listagg(participant, ', ') within group(
            order by
                participant
            )
        into l_assignees
        from
            apex_task_participants
        where
                task_id = p_task_id
            and participant_type = 'POTENTIAL_OWNER';

        l_json.put('ASSIGNEES',
                   apex_escape.html(nvl(l_assignees, '-')));

        return l_json.to_clob;
    end task_tokens;

    function potential_owners (
        p_task_id in number
    ) return varchar2 is
        l_list varchar2(32767);
    begin
        select
            listagg(distinct participant, ',') within group(
            order by
                participant
            )
        into l_list
        from
            apex_task_participants
        where
                task_id = p_task_id
            and participant_type = 'POTENTIAL_OWNER'
            and identity_type = 'USER';

        return l_list;
    end potential_owners;

    procedure notify_created (
        p_task_id in number
    ) is
        l_flag varchar2(1);
    begin
        select
            nvl(
                max(s.notify_on_create_flag),
                'Y'
            )
        into l_flag
        from
            apex_tasks          t
            left join xxfnd_task_settings s on s.task_definition = t.task_def_static_id
        where
            t.task_id = p_task_id;

        if l_flag = 'Y' then
            xxfnd_notify_pkg.send_to_users('TASK_ASSIGNED',
                                           potential_owners(p_task_id),
                                           task_tokens(p_task_id));
        end if;

    end notify_created;

    procedure process_deadlines is
    begin
        -- Reminders to the owners before the due date.
        for t in (
            select
                k.task_id,
                k.actual_owner
            from
                     apex_tasks k
                join xxfnd_task_settings s on s.task_definition = k.task_def_static_id
            where
                    k.application_id = v('APP_ID')
                and k.state_code in ( 'UNASSIGNED', 'ASSIGNED' )
                and s.reminder_days_before is not null
                and k.due_on is not null
                and systimestamp >= k.due_on - numtodsinterval(s.reminder_days_before, 'DAY')
                and systimestamp < k.due_on
                and not exists (
                    select
                        1
                    from
                        xxfnd_task_alerts a
                    where
                            a.task_id = k.task_id
                        and a.alert_type = 'REMINDER'
                )
        ) loop
            xxfnd_notify_pkg.send_to_users('TASK_REMINDER',
                                           nvl(t.actual_owner,
                                               potential_owners(t.task_id)),
                                           task_tokens(t.task_id));

            insert into xxfnd_task_alerts (
                task_id,
                alert_type
            ) values
                ( t.task_id,
                  'REMINDER' );

        end loop;
        -- Escalation of overdue tasks to the escalation role.
        for t in (
            select
                k.task_id,
                s.escalation_role_code
            from
                     apex_tasks k
                join xxfnd_task_settings s on s.task_definition = k.task_def_static_id
            where
                    k.application_id = v('APP_ID')
                and k.state_code in ( 'UNASSIGNED', 'ASSIGNED' )
                and s.escalation_role_code is not null
                and k.due_on < systimestamp
                and not exists (
                    select
                        1
                    from
                        xxfnd_task_alerts a
                    where
                            a.task_id = k.task_id
                        and a.alert_type = 'ESCALATION'
                )
        ) loop
            xxfnd_notify_pkg.send_to_users('TASK_ESCALATED',
                                           users_in_role(t.escalation_role_code),
                                           task_tokens(t.task_id));

            insert into xxfnd_task_alerts (
                task_id,
                alert_type
            ) values
                ( t.task_id,
                  'ESCALATION' );

        end loop;
        -- Forget alerts of tasks that no longer exist.
        delete from xxfnd_task_alerts a
        where
            not exists (
                select
                    1
                from
                    apex_tasks k
                where
                    k.task_id = a.task_id
            );

    end process_deadlines;

end xxfnd_task_pkg;
/


-- sqlcl_snapshot {"hash":"3e4a38734795eef4e0b0901b22875cf7c8dea6a3","type":"PACKAGE_BODY","name":"XXFND_TASK_PKG","schemaName":"XXCUS","sxml":""}