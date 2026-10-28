
create or replace package body xxfnd_approval_rule_pkg as

    function txn(p_type in varchar2, p_txn_id in varchar2) return xxfnd_approval_txns%rowtype is
        l xxfnd_approval_txns%rowtype;
    begin
        select * into l from xxfnd_approval_txns where approval_type_code = upper(p_type) and txn_id = p_txn_id;
        return l;
    exception
        when no_data_found then
            return l;
    end txn;

    function step(p_type in varchar2, p_txn_id in varchar2) return xxfnd_approval_txn_steps%rowtype is
        l_txn xxfnd_approval_txns%rowtype := txn(p_type, p_txn_id);
        l     xxfnd_approval_txn_steps%rowtype;
    begin
        select * into l from xxfnd_approval_txn_steps
         where approval_type_code = upper(p_type) and txn_id = p_txn_id and step_seq = l_txn.current_seq;
        return l;
    exception
        when no_data_found then
            return l;
    end step;

    procedure register_type(p_type in varchar2, p_application_code in varchar2, p_name in varchar2,
                            p_description in varchar2 default null, p_attributes in apex_t_varchar2 default null) is
        l_parts  apex_t_varchar2;
        l_lookup varchar2(30);
    begin
        merge into xxfnd_approval_types d
        using (select upper(p_type) code from dual) s
           on (d.approval_type_code = s.code)
         when matched then update set d.approval_type_name = p_name, d.description = nvl(p_description, d.description)
         when not matched then insert (approval_type_code, application_code, approval_type_name, description)
                               values (s.code, upper(p_application_code), p_name, p_description);
        if p_attributes is not null then
            for i in 1 .. p_attributes.count loop
                l_parts  := apex_string.split(p_attributes(i), '=');
                l_lookup := case when l_parts.count > 2 then l_parts(3) end;
                merge into xxfnd_approval_type_attrs d
                using (select upper(p_type) t, upper(l_parts(1)) a from dual) s
                   on (d.approval_type_code = s.t and d.attribute_code = s.a)
                 when not matched then insert (approval_type_code, attribute_code, attribute_name, lookup_type,
                                               display_sequence)
                                       values (s.t, s.a, l_parts(2), l_lookup, i * 10);
            end loop;
        end if;
    end register_type;

    function matching_rule(p_type in varchar2, p_attributes in apex_t_varchar2) return number is
        l_rule number;
    begin
        -- a rule matches when each of its attributes has the transaction's value among its values; the most
        -- specific match wins (most attributes), then the lowest priority
        with vals as (
            select upper(substr(column_value, 1, instr(column_value, '=') - 1)) attribute_code,
                   substr(column_value, instr(column_value, '=') + 1) attribute_value
              from table(p_attributes))
        select max(r.rule_id) keep (dense_rank first order by
                   (select count(distinct c.attribute_code) from xxfnd_approval_rule_conds c where c.rule_id = r.rule_id) desc,
                   r.priority, r.rule_name)
          into l_rule
          from xxfnd_approval_rules r
         where r.approval_type_code = upper(p_type) and r.enabled_flag = 'Y'
           -- release 76 (A-11): a rule without steps matches too (the deliberate "no approval" rule)
           and not exists (select 1 from xxfnd_approval_rule_conds c
                            where c.rule_id = r.rule_id
                              and not exists (select 1 from xxfnd_approval_rule_conds c2
                                               join vals v on v.attribute_code = c2.attribute_code
                                                          and v.attribute_value = c2.attribute_value
                                              where c2.rule_id = r.rule_id and c2.attribute_code = c.attribute_code));
        return l_rule;
    end matching_rule;

    function approval_error(p_type in varchar2, p_attributes in apex_t_varchar2) return varchar2 is
        l_rule number := matching_rule(p_type, p_attributes);
    begin
        if l_rule is null then
            return xxfnd_error_pkg.message('XXFND_APPROVAL_NO_RULE', apex_t_varchar2(p_type));
        end if;
        -- release 94: a placeholder approver type cannot route yet (its HCM data is not loaded)
        for s in (select step_name, approver_type from xxfnd_approval_rule_steps
                   where rule_id = l_rule and approver_type_available(approver_type) = 'N' order by step_no) loop
            return 'Step "' || s.step_name || '" uses the approver type ' || approver_label(s.approver_type, null, null)
                || ', which is not available yet. Change the step in Approval Setup to a user (or a role).';
        end loop;
        for s in (select step_name, approver_type, role_code from xxfnd_approval_rule_steps
                   where rule_id = l_rule and approver_type in ('ROLE', 'GROUP') order by step_no) loop
            -- release 113: a group needs at least one user (its users and the active users of its roles)
            if (s.approver_type = 'ROLE' and xxfnd_workflow_pkg.users_in_role(s.role_code) is null)
               or (s.approver_type = 'GROUP' and group_users(s.role_code) is null) then
                return xxfnd_error_pkg.message('XXFND_APPROVAL_NO_APPROVER',
                                               apex_t_varchar2(s.step_name, approver_label(s.approver_type, s.role_code, null)));
            end if;
        end loop;
        return null;
    end approval_error;

    function start_approval(p_type in varchar2, p_txn_id in varchar2, p_attributes in apex_t_varchar2,
                            p_requester in varchar2) return varchar2 is
        l_rule  number := matching_rule(p_type, p_attributes);
        l_name  xxfnd_approval_rules.rule_name%type;
        l_first number;
        l_error varchar2(4000) := approval_error(p_type, p_attributes);
    begin
        if l_rule is null then
            xxfnd_error_pkg.raise_error('XXFND_APPROVAL_NO_RULE', apex_t_varchar2(p_type));
        elsif l_error is not null then
            raise_application_error(-20535, l_error);
        end if;
        select rule_name into l_name from xxfnd_approval_rules where rule_id = l_rule;
        delete from xxfnd_approval_txns where approval_type_code = upper(p_type) and txn_id = p_txn_id;
        insert into xxfnd_approval_txns (approval_type_code, txn_id, rule_id, rule_name, requester)
        values (upper(p_type), p_txn_id, l_rule, l_name, upper(p_requester));
        insert into xxfnd_approval_txn_steps (approval_type_code, txn_id, step_seq, step_name, approver_type, role_code,
                                              user_name, source, due_days)
        select upper(p_type), p_txn_id, row_number() over (order by step_no) * 10, step_name, approver_type, role_code,
               user_name, 'RULE', due_days
          from xxfnd_approval_rule_steps where rule_id = l_rule;
        select min(step_seq) into l_first from xxfnd_approval_txn_steps
         where approval_type_code = upper(p_type) and txn_id = p_txn_id;
        update xxfnd_approval_txns
           set current_seq = l_first,
               approval_status = case when l_first is null then 'COMPLETED' else approval_status end   -- release 76
         where approval_type_code = upper(p_type) and txn_id = p_txn_id;
        return l_name;
    end start_approval;

    function is_started(p_type in varchar2, p_txn_id in varchar2) return varchar2 is
    begin
        return case when txn(p_type, p_txn_id).approval_status = 'IN_PROGRESS' then 'Y' else 'N' end;
    end is_started;

    function current_step_name(p_type in varchar2, p_txn_id in varchar2) return varchar2 is
    begin
        return step(p_type, p_txn_id).step_name;
    end current_step_name;

    function current_role(p_type in varchar2, p_txn_id in varchar2) return varchar2 is
        l xxfnd_approval_txn_steps%rowtype := step(p_type, p_txn_id);
    begin
        return case when l.approver_type = 'ROLE' then l.role_code end;
    end current_role;

    function current_approvers(p_type in varchar2, p_txn_id in varchar2) return varchar2 is
        l xxfnd_approval_txn_steps%rowtype := step(p_type, p_txn_id);
    begin
        return case l.approver_type when 'USER'      then upper(l.user_name)
                                    when 'ROLE'      then xxfnd_workflow_pkg.users_in_role(l.role_code)
                                    when 'GROUP'     then group_users(l.role_code)
                                    when 'REQUESTER' then txn(p_type, p_txn_id).requester end;
    end current_approvers;

    function current_position(p_type in varchar2, p_txn_id in varchar2) return number is
        l_txn xxfnd_approval_txns%rowtype := txn(p_type, p_txn_id);
        l_n   number;
    begin
        select count(*) into l_n from xxfnd_approval_txn_steps
         where approval_type_code = upper(p_type) and txn_id = p_txn_id and step_seq <= l_txn.current_seq;
        return l_n;
    end current_position;

    function step_count(p_type in varchar2, p_txn_id in varchar2) return number is
        l_n number;
    begin
        select count(*) into l_n from xxfnd_approval_txn_steps where approval_type_code = upper(p_type) and txn_id = p_txn_id;
        return l_n;
    end step_count;

    function next_step(p_type in varchar2, p_txn_id in varchar2) return varchar2 is
        l_txn  xxfnd_approval_txns%rowtype := txn(p_type, p_txn_id);
        l_next number;
    begin
        select min(step_seq) into l_next from xxfnd_approval_txn_steps
         where approval_type_code = upper(p_type) and txn_id = p_txn_id and step_seq > l_txn.current_seq;
        update xxfnd_approval_txns
           set current_seq = nvl(l_next, current_seq),
               approval_status = case when l_next is null then 'COMPLETED' else approval_status end
         where approval_type_code = upper(p_type) and txn_id = p_txn_id;
        return case when l_next is null then 'N' else 'Y' end;
    end next_step;

    procedure add_approver(p_type in varchar2, p_txn_id in varchar2, p_approver_type in varchar2,
                           p_role_code in varchar2 default null, p_user_name in varchar2 default null,
                           p_position in varchar2 default 'NEXT', p_comment in varchar2 default null,
                           p_force in varchar2 default 'N') is
        l_txn  xxfnd_approval_txns%rowtype := txn(p_type, p_txn_id);
        l_me   varchar2(255) := upper(xxfnd_util_pkg.current_user);
        l_next number;
        l_seq  number;
    begin
        if l_txn.approval_status is null or l_txn.approval_status <> 'IN_PROGRESS' then
            xxfnd_error_pkg.raise_error('XXFND_APPROVAL_NOT_IN_PROGRESS');
        end if;
        if nvl(p_force, 'N') <> 'Y' and l_me <> nvl(l_txn.requester, '#')
           and instr(',' || current_approvers(p_type, p_txn_id) || ',', ',' || l_me || ',') = 0 then
            xxfnd_error_pkg.raise_error('XXFND_APPROVAL_ADD_NOT_ALLOWED');
        end if;
        if p_approver_type not in ('ROLE', 'USER') or (p_approver_type = 'ROLE' and p_role_code is null)
           or (p_approver_type = 'USER' and p_user_name is null) then
            xxfnd_error_pkg.raise_error('XXFND_APPROVAL_APPROVER_REQUIRED');
        end if;
        select min(step_seq) into l_next from xxfnd_approval_txn_steps
         where approval_type_code = upper(p_type) and txn_id = p_txn_id and step_seq > l_txn.current_seq;
        if p_position = 'END' or l_next is null then
            select max(step_seq) + 10 into l_seq from xxfnd_approval_txn_steps
             where approval_type_code = upper(p_type) and txn_id = p_txn_id;
        else
            l_seq := (l_txn.current_seq + l_next) / 2;   -- right after the current approver
        end if;
        insert into xxfnd_approval_txn_steps (approval_type_code, txn_id, step_seq, step_name, approver_type, role_code,
                                              user_name, source, added_by, added_comment, added_date)
        values (upper(p_type), p_txn_id, l_seq, 'Additional approval', p_approver_type, p_role_code, upper(p_user_name),
                'ADHOC', l_me, substr(p_comment, 1, 4000), systimestamp);
    end add_approver;

    procedure cancel(p_type in varchar2, p_txn_id in varchar2) is
    begin
        update xxfnd_approval_txns set approval_status = 'CANCELLED'
         where approval_type_code = upper(p_type) and txn_id = p_txn_id and approval_status = 'IN_PROGRESS';
    end cancel;

    function open_count(p_rule_id in number) return number is
        l_n number;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select count(*) into l_n from xxfnd_approval_txns where rule_id = p_rule_id and approval_status = 'IN_PROGRESS';
        xxfnd_vpd_pkg.end_trusted;
        return l_n;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end open_count;

    function approver_type_available(p_approver_type in varchar2) return varchar2 is
    begin
        -- release 94: the HCM-based types are placeholders; their resolvers come with the HCM tables
        return case when upper(p_approver_type) in ('USER', 'ROLE', 'GROUP', 'REQUESTER') then 'Y' else 'N' end;
    end approver_type_available;

    function step_due_date(p_type in varchar2, p_txn_id in varchar2) return timestamp with time zone is
        l xxfnd_approval_txn_steps%rowtype := step(p_type, p_txn_id);
    begin
        return case when l.due_days is not null then systimestamp + numtodsinterval(l.due_days, 'DAY') end;
    end step_due_date;

    function approver_label(p_approver_type in varchar2, p_role_code in varchar2, p_user_name in varchar2) return varchar2 is
        l_name xxfnd_roles.role_name%type;
    begin
        if p_approver_type = 'USER' then
            select max(nvl(full_name, user_name)) into l_name from xxhr_employees where user_name = upper(p_user_name);
            return nvl(l_name, p_user_name);
        elsif p_approver_type = 'REQUESTER' then
            return 'Requester';
        elsif p_approver_type = 'GROUP' then
            -- release 113: an approval group (its code in ROLE_CODE)
            select max(group_name) into l_name from xxfnd_approval_groups where group_code = p_role_code;
            return 'Group: ' || nvl(l_name, p_role_code);
        elsif p_approver_type in ('POSITION', 'MANAGER', 'SUP_HIER', 'POS_HIER', 'AOR', 'QUERY') then
            return case p_approver_type when 'POSITION' then 'Position' when 'MANAGER' then 'Manager'
                                        when 'SUP_HIER' then 'Supervisor hierarchy' when 'POS_HIER' then 'Position hierarchy'
                                        when 'AOR' then 'Area of responsibility' else 'Query' end
                   || ' (not available yet)';
        end if;
        select max(role_name) into l_name from xxfnd_roles where role_code = p_role_code;
        return nvl(l_name, p_role_code);
    end approver_label;

    function steps(p_type in varchar2, p_txn_id in varchar2, p_attributes in apex_t_varchar2 default null)
        return xxfnd_approval_step_tab pipelined is
        l_txn  xxfnd_approval_txns%rowtype := txn(p_type, p_txn_id);
        l_rule number;
        l_pos  number := 0;
    begin
        if l_txn.approval_type_code is not null then
            for s in (select * from xxfnd_approval_txn_steps
                       where approval_type_code = upper(p_type) and txn_id = p_txn_id order by step_seq) loop
                l_pos := l_pos + 1;
                pipe row (xxfnd_approval_step_row(l_pos, s.step_name, s.approver_type, s.role_code, s.user_name, s.source,
                              s.added_by, s.added_comment,
                              case when l_txn.approval_status = 'COMPLETED' or s.step_seq < l_txn.current_seq then 'DONE'
                                   when l_txn.approval_status = 'CANCELLED' then 'CANCELLED'
                                   when s.step_seq = l_txn.current_seq then 'CURRENT'
                                   else 'WAITING' end));
            end loop;
        elsif p_attributes is not null then
            l_rule := matching_rule(p_type, p_attributes);
            for s in (select * from xxfnd_approval_rule_steps where rule_id = l_rule order by step_no) loop
                l_pos := l_pos + 1;
                pipe row (xxfnd_approval_step_row(l_pos, s.step_name, s.approver_type, s.role_code, s.user_name, 'RULE',
                              null, null, 'EXPECTED'));
            end loop;
        end if;
        return;
    end steps;

    function decide_task(p_task_id       in number,
                         p_decision      in varchar2,
                         p_comment       in varchar2 default null,
                         p_approval_type in varchar2 default null,
                         p_txn_id        in varchar2 default null,
                         p_add_user      in varchar2 default null) return varchar2 is
        l_decision varchar2(30) := upper(p_decision);
    begin
        if l_decision not in ('APPROVE', 'REJECT', 'REQUEST_INFO', 'SUBMIT_INFO', 'ADD_APPROVER', 'COMMENT') then
            raise_application_error(-20536, 'Unknown task decision ' || p_decision || '.');
        end if;
        if p_comment is not null and l_decision in ('APPROVE', 'REJECT', 'ADD_APPROVER', 'COMMENT') then
            apex_human_task.add_task_comment(p_task_id => p_task_id, p_text => p_comment);
        end if;
        case l_decision
            when 'APPROVE' then
                apex_human_task.approve_task(p_task_id => p_task_id, p_autoclaim => true);
            when 'REJECT' then
                apex_human_task.reject_task(p_task_id => p_task_id, p_autoclaim => true);
            when 'REQUEST_INFO' then
                -- the question goes to the task initiator; an unclaimed task is claimed first
                for t in (select 1 from apex_tasks where task_id = p_task_id and state_code = 'UNASSIGNED') loop
                    apex_human_task.claim_task(p_task_id => p_task_id);
                end loop;
                if xxfnd_workflow_pkg.can_request_info(p_task_id) = 'N' then
                    return 'N';
                end if;
                apex_human_task.request_more_information(p_task_id => p_task_id, p_text => p_comment);
            when 'SUBMIT_INFO' then
                apex_human_task.submit_information(p_task_id => p_task_id, p_text => p_comment);
            when 'ADD_APPROVER' then
                if p_add_user is null then
                    xxfnd_error_pkg.raise_error('XXFND_APPROVAL_APPROVER_REQUIRED');
                end if;
                add_approver(p_approval_type, p_txn_id, 'USER', p_user_name => p_add_user,
                             p_position => 'NEXT', p_comment => p_comment);
            else
                null;   -- COMMENT: recorded above
        end case;
        return 'Y';
    end decide_task;

    -- release 86: registration (release 88: shared by REGISTER_DEFAULT_RULE and REGISTER_RULE)
    procedure add_rule(p_application_code in varchar2,
                       p_type             in varchar2,
                       p_rule_name        in varchar2,
                       p_steps            in apex_t_varchar2,
                       p_conditions       in apex_t_varchar2,
                       p_priority         in number,
                       p_description      in varchar2,
                       p_first_only       in boolean) is
        l_code  xxfnd_applications.application_code%type := xxfnd_application_pkg.registered_code(p_application_code);
        l_type  xxfnd_approval_types.approval_type_code%type := upper(p_type);
        l_owner xxfnd_approval_types.application_code%type;
        l_n     pls_integer;
        l_rule  number;
        l_parts apex_t_varchar2;
        l_kind  varchar2(30);
        l_who   varchar2(255);
    begin
        select count(*), max(application_code) into l_n, l_owner from xxfnd_approval_types where approval_type_code = l_type;
        if l_n = 0 then
            xxfnd_error_pkg.raise_error('XXFND_REG_UNKNOWN', apex_t_varchar2('Approval type', l_type));
        end if;
        xxfnd_application_pkg.assert_same_application('Approval type', l_type, l_owner, l_code);
        select count(*) into l_n from xxfnd_approval_rules
         where approval_type_code = l_type
           and (p_first_only or upper(rule_name) = upper(trim(p_rule_name)));
        if l_n > 0 then
            return;   -- the type has its rules (or this rule): the administrators own them
        end if;
        -- every step is checked before anything is written
        if p_steps is not null then
            for i in 1 .. p_steps.count loop
                l_parts := apex_string.split(p_steps(i), '=');
                l_kind  := case when l_parts.count >= 2 then upper(trim(l_parts(2))) end;
                if trim(l_parts(1)) is null
                   or nvl(l_kind, '#') not in ('ROLE', 'USER', 'REQUESTER')
                   or (l_kind in ('ROLE', 'USER') and (l_parts.count < 3 or trim(l_parts(3)) is null)) then
                    xxfnd_error_pkg.raise_error('XXFND_REG_RULE_STEP', apex_t_varchar2(p_steps(i)));
                end if;
            end loop;
        end if;
        insert into xxfnd_approval_rules (approval_type_code, rule_name, priority, description)
        values (l_type, p_rule_name, nvl(p_priority, 100), p_description)
        returning rule_id into l_rule;
        if p_conditions is not null then
            for i in 1 .. p_conditions.count loop
                l_parts := apex_string.split(p_conditions(i), '=');
                merge into xxfnd_approval_rule_conds d
                using (select l_rule r, upper(trim(l_parts(1))) a, trim(substr(p_conditions(i), instr(p_conditions(i), '=') + 1)) v
                         from dual) s
                   on (d.rule_id = s.r and d.attribute_code = s.a and d.attribute_value = s.v)
                 when not matched then insert (rule_id, attribute_code, attribute_value) values (s.r, s.a, s.v);
            end loop;
        end if;
        if p_steps is not null then
            for i in 1 .. p_steps.count loop
                l_parts := apex_string.split(p_steps(i), '=');
                l_kind  := upper(trim(l_parts(2)));
                l_who   := case when l_kind in ('ROLE', 'USER') then upper(trim(l_parts(3))) end;
                insert into xxfnd_approval_rule_steps (rule_id, step_no, step_name, approver_type, role_code, user_name)
                values (l_rule, i, trim(l_parts(1)), l_kind,
                        case when l_kind = 'ROLE' then l_who end,
                        case when l_kind = 'USER' then l_who end);
            end loop;
        end if;
    end add_rule;

    procedure register_default_rule(p_application_code in varchar2,
                                    p_type             in varchar2,
                                    p_rule_name        in varchar2,
                                    p_steps            in apex_t_varchar2 default null,
                                    p_conditions       in apex_t_varchar2 default null,
                                    p_priority         in number   default 100,
                                    p_description      in varchar2 default null) is
    begin
        add_rule(p_application_code, p_type, p_rule_name, p_steps, p_conditions, p_priority, p_description, true);
    end register_default_rule;

    procedure register_rule(p_application_code in varchar2,
                            p_type             in varchar2,
                            p_rule_name        in varchar2,
                            p_steps            in apex_t_varchar2 default null,
                            p_conditions       in apex_t_varchar2 default null,
                            p_priority         in number   default 100,
                            p_description      in varchar2 default null) is
    begin
        add_rule(p_application_code, p_type, p_rule_name, p_steps, p_conditions, p_priority, p_description, false);
    end register_rule;

    -- release 88 (C8, C9)
    procedure unregister_rule(p_application_code in varchar2, p_type in varchar2, p_rule_name in varchar2) is
    begin
        xxfnd_application_pkg.remove_registered(p_application_code, 'Approval rule', 'XXFND_APPROVAL_RULES', apex_t_varchar2('APPROVAL_TYPE_CODE', 'RULE_NAME'),
            apex_t_varchar2(upper(trim(p_type)), p_rule_name),
            '(select y.application_code from xxfnd_approval_types y where y.approval_type_code = t.approval_type_code)');
    end unregister_rule;

    procedure unregister_type(p_application_code in varchar2, p_type in varchar2) is
    begin
        xxfnd_application_pkg.remove_registered(p_application_code, 'Approval type', 'XXFND_APPROVAL_TYPES', apex_t_varchar2('APPROVAL_TYPE_CODE'),
            apex_t_varchar2(upper(trim(p_type))));
    end unregister_type;

    procedure unregister_application(p_application_code in varchar2) is
    begin
        xxfnd_application_pkg.remove_all_registered(p_application_code, 'Approval types', 'XXFND_APPROVAL_TYPES');
    end unregister_application;

    ---------------------------------------------------------------- release 113: approval groups
    procedure check_group_type(p_application_code in varchar2, p_type in varchar2) is
        l_n     pls_integer;
        l_owner xxfnd_approval_types.application_code%type;
    begin
        select count(*), max(application_code) into l_n, l_owner from xxfnd_approval_types
         where approval_type_code = upper(p_type);
        if l_n = 0 then
            xxfnd_error_pkg.raise_error('XXFND_REG_UNKNOWN', apex_t_varchar2('Approval type', upper(p_type)));
        end if;
        xxfnd_application_pkg.assert_same_application('Approval type', upper(p_type), l_owner,
                                                      xxfnd_application_pkg.registered_code(p_application_code));
    end check_group_type;

    function group_type(p_group_code in varchar2) return varchar2 is
        l_type xxfnd_approval_groups.approval_type_code%type;
    begin
        select max(approval_type_code) into l_type from xxfnd_approval_groups where group_code = upper(p_group_code);
        if l_type is null then
            xxfnd_error_pkg.raise_error('XXFND_REG_UNKNOWN', apex_t_varchar2('Approval group', upper(p_group_code)));
        end if;
        return l_type;
    end group_type;

    procedure save_group(p_application_code in varchar2,
                         p_type             in varchar2,
                         p_group_code       in varchar2,
                         p_group_name       in varchar2,
                         p_description      in varchar2 default null,
                         p_enabled_flag     in varchar2 default 'Y') is
        l_type xxfnd_approval_groups.approval_type_code%type;
    begin
        check_group_type(p_application_code, p_type);
        select max(approval_type_code) into l_type from xxfnd_approval_groups where group_code = upper(trim(p_group_code));
        if l_type is not null and l_type <> upper(p_type) then
            raise_application_error(-20538, 'Approval group ' || upper(trim(p_group_code))
                || ' already belongs to the process ' || l_type || '.');
        end if;
        merge into xxfnd_approval_groups t
        using (select upper(trim(p_group_code)) group_code from dual) s
           on (t.group_code = s.group_code)
         when matched then update set t.group_name = p_group_name, t.description = p_description,
                                      t.enabled_flag = nvl(p_enabled_flag, 'Y')
         when not matched then insert (group_code, approval_type_code, group_name, description, enabled_flag)
              values (s.group_code, upper(p_type), p_group_name, p_description, nvl(p_enabled_flag, 'Y'));
    end save_group;

    procedure set_group_members(p_application_code in varchar2, p_group_code in varchar2,
                                p_roles in varchar2, p_users in varchar2) is
        l_code varchar2(30) := upper(trim(p_group_code));
    begin
        check_group_type(p_application_code, group_type(l_code));
        delete from xxfnd_approval_group_members m
         where m.group_code = l_code
           and not ((m.member_type = 'ROLE' and m.member_code in (select column_value from table(apex_string.split(p_roles, ':'))))
                 or (m.member_type = 'USER' and m.member_code in (select upper(column_value) from table(apex_string.split(p_users, ':')))));
        insert into xxfnd_approval_group_members (group_code, member_type, member_code)
        select l_code, x.member_type, x.member_code
          from (select 'ROLE' member_type, column_value member_code from table(apex_string.split(p_roles, ':'))
                union
                select 'USER', upper(column_value) from table(apex_string.split(p_users, ':'))) x
         where x.member_code is not null
           and not exists (select 1 from xxfnd_approval_group_members m
                            where m.group_code = l_code and m.member_type = x.member_type and m.member_code = x.member_code);
    end set_group_members;

    procedure delete_group(p_application_code in varchar2, p_group_code in varchar2) is
        l_code varchar2(30) := upper(trim(p_group_code));
        l_n    pls_integer;
    begin
        check_group_type(p_application_code, group_type(l_code));
        select count(*) into l_n from xxfnd_approval_rule_steps where approver_type = 'GROUP' and role_code = l_code;
        if l_n > 0 then
            raise_application_error(-20537, 'Approval group ' || l_code || ' is used by ' || l_n
                || ' rule level(s): change them first, or disable the group.');
        end if;
        delete from xxfnd_approval_groups where group_code = l_code;
    end delete_group;

    function group_users(p_group_code in varchar2) return varchar2 is
        l_list varchar2(32767);
    begin
        select listagg(distinct u.user_name, ',') within group (order by u.user_name)
          into l_list
          from (select m.member_code as user_name
                  from xxfnd_approval_group_members m
                 where m.group_code = upper(p_group_code) and m.member_type = 'USER'
                union
                select ur.user_name
                  from xxfnd_approval_group_members m
                  join xxfnd_user_roles_v ur on ur.role_code = m.member_code and ur.active_flag = 'Y'
                 where m.group_code = upper(p_group_code) and m.member_type = 'ROLE') u
         where exists (select 1 from xxfnd_approval_groups g where g.group_code = upper(p_group_code) and g.enabled_flag = 'Y');
        return l_list;
    end group_users;

end xxfnd_approval_rule_pkg;
/
