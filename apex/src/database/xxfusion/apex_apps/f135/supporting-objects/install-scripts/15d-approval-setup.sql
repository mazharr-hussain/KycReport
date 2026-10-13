--------------------------------------------------------------------------------
-- 15d Approval Setup (release 74, AME style). COMMON only (XXFUSION); every application uses it.
--   One setup for every approval process of every application:
--   - XXFND_APPROVAL_TYPES          a transaction type (e.g. KYC_REQUEST, KYC_CASE, CASE_RFI), one row each
--   - XXFND_APPROVAL_TYPE_ATTRS     the attributes its rules can test (e.g. department, risk tier)
--   - XXFND_APPROVAL_RULES          rules of a type; the rule whose conditions match most attributes applies
--   - XXFND_APPROVAL_RULE_CONDS     conditions: attribute = value (several values of one attribute = any of them)
--   - XXFND_APPROVAL_RULE_STEPS     the approvers of a rule, in order: a role, a user or the requester
--   - XXFND_APPROVAL_TXNS / _TXN_STEPS  the approvers of one transaction (copied from the rule when it starts),
--     where ad-hoc approvers are added
--   APEX Workflow and Human Tasks run the approval; this package only answers "who approves now" and "is there a
--   next approver". The component (request, case ...) gives the attribute values and starts / steps its workflow.
-- Idempotent (CREATE_TABLE only when missing; changes as checked steps).
--------------------------------------------------------------------------------
begin
    if xxfnd_ddl_pkg.create_table('XXFND_APPROVAL_TYPES', q'~create table xxfnd_approval_types (
    approval_type_code     varchar2(30)   not null,
    application_code       varchar2(30)   not null,
    approval_type_name     varchar2(100)  not null,
    description            varchar2(1000),
    enabled_flag           varchar2(1)    default 'Y' not null,
    created_by             varchar2(255)  not null,
    creation_date          timestamp      not null,
    last_updated_by        varchar2(255)  not null,
    last_update_date       timestamp      not null,
    last_update_login      varchar2(255),
    object_version_number  number         default 1 not null,
    constraint xxfnd_approval_types_pk primary key (approval_type_code),
    constraint xxfnd_approval_types_ck1 check (enabled_flag in ('Y','N'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_approval_types is 'Approval Setup: one transaction type per approval process of an application.'~');
    end if;
    xxfnd_schema_pkg.create_who_trigger('XXFND_APPROVAL_TYPES');

    if xxfnd_ddl_pkg.create_table('XXFND_APPROVAL_TYPE_ATTRS', q'~create table xxfnd_approval_type_attrs (
    approval_type_code     varchar2(30)   not null,
    attribute_code         varchar2(30)   not null,
    attribute_name         varchar2(100)  not null,
    lookup_type            varchar2(30),
    display_sequence       number         default 10 not null,
    created_by             varchar2(255)  not null,
    creation_date          timestamp      not null,
    last_updated_by        varchar2(255)  not null,
    last_update_date       timestamp      not null,
    last_update_login      varchar2(255),
    object_version_number  number         default 1 not null,
    constraint xxfnd_approval_type_attrs_pk primary key (approval_type_code, attribute_code),
    constraint xxfnd_approval_type_attrs_fk1 foreign key (approval_type_code)
        references xxfnd_approval_types (approval_type_code) on delete cascade
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_approval_type_attrs is 'Approval Setup: the attributes a transaction type gives its rules (values from LOOKUP_TYPE when set).'~');
    end if;
    xxfnd_schema_pkg.create_who_trigger('XXFND_APPROVAL_TYPE_ATTRS');

    if xxfnd_ddl_pkg.create_table('XXFND_APPROVAL_RULES', q'~create table xxfnd_approval_rules (
    rule_id                number         not null,
    approval_type_code     varchar2(30)   not null,
    rule_name              varchar2(100)  not null,
    priority               number         default 100 not null,
    description            varchar2(1000),
    enabled_flag           varchar2(1)    default 'Y' not null,
    created_by             varchar2(255)  not null,
    creation_date          timestamp      not null,
    last_updated_by        varchar2(255)  not null,
    last_update_date       timestamp      not null,
    last_update_login      varchar2(255),
    object_version_number  number         default 1 not null,
    constraint xxfnd_approval_rules_pk primary key (rule_id),
    constraint xxfnd_approval_rules_uk1 unique (approval_type_code, rule_name),
    constraint xxfnd_approval_rules_fk1 foreign key (approval_type_code)
        references xxfnd_approval_types (approval_type_code) on delete cascade,
    constraint xxfnd_approval_rules_ck1 check (enabled_flag in ('Y','N'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_approval_rules is 'Approval Setup: rules of a transaction type. The enabled rule whose conditions match most attributes applies; then the lowest priority.'~');
    end if;
    xxfnd_schema_pkg.create_who_trigger('XXFND_APPROVAL_RULES');

    if xxfnd_ddl_pkg.create_table('XXFND_APPROVAL_RULE_CONDS', q'~create table xxfnd_approval_rule_conds (
    condition_id           number generated by default on null as identity,
    rule_id                number         not null,
    attribute_code         varchar2(30)   not null,
    attribute_value        varchar2(240)  not null,
    created_by             varchar2(255)  not null,
    creation_date          timestamp      not null,
    last_updated_by        varchar2(255)  not null,
    last_update_date       timestamp      not null,
    last_update_login      varchar2(255),
    object_version_number  number         default 1 not null,
    constraint xxfnd_approval_rule_conds_pk primary key (condition_id),
    constraint xxfnd_approval_rule_conds_uk1 unique (rule_id, attribute_code, attribute_value),
    constraint xxfnd_approval_rule_conds_fk1 foreign key (rule_id) references xxfnd_approval_rules (rule_id) on delete cascade
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_approval_rule_conds is 'Approval Setup: rule conditions (attribute = value; several values of one attribute = any of them).'~');
    end if;
    xxfnd_schema_pkg.create_who_trigger('XXFND_APPROVAL_RULE_CONDS');

    if xxfnd_ddl_pkg.create_table('XXFND_APPROVAL_RULE_STEPS', q'~create table xxfnd_approval_rule_steps (
    rule_step_id           number generated by default on null as identity,
    rule_id                number         not null,
    step_no                number         not null,
    step_name              varchar2(100)  not null,
    approver_type          varchar2(10)   default 'ROLE' not null,
    role_code              varchar2(30),
    user_name              varchar2(255),
    created_by             varchar2(255)  not null,
    creation_date          timestamp      not null,
    last_updated_by        varchar2(255)  not null,
    last_update_date       timestamp      not null,
    last_update_login      varchar2(255),
    object_version_number  number         default 1 not null,
    constraint xxfnd_approval_rule_steps_pk primary key (rule_step_id),
    constraint xxfnd_approval_rule_steps_uk1 unique (rule_id, step_no),
    constraint xxfnd_approval_rule_steps_fk1 foreign key (rule_id) references xxfnd_approval_rules (rule_id) on delete cascade,
    constraint xxfnd_approval_rule_steps_ck1 check (approver_type in ('ROLE','USER','REQUESTER')),
    constraint xxfnd_approval_rule_steps_ck2 check ((approver_type = 'ROLE' and role_code is not null)
                                                 or (approver_type = 'USER' and user_name is not null)
                                                 or approver_type = 'REQUESTER')
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_approval_rule_steps is 'Approval Setup: the approvers of a rule, in order (a role, a user or the requester).'~');
    end if;
    xxfnd_schema_pkg.create_who_trigger('XXFND_APPROVAL_RULE_STEPS');

    if xxfnd_ddl_pkg.create_table('XXFND_APPROVAL_TXNS', q'~create table xxfnd_approval_txns (
    approval_type_code     varchar2(30)   not null,
    txn_id                 varchar2(150)  not null,
    rule_id                number,
    rule_name              varchar2(100),
    requester              varchar2(255),
    current_seq            number,
    approval_status        varchar2(30)   default 'IN_PROGRESS' not null,
    started_date           timestamp      default systimestamp not null,
    constraint xxfnd_approval_txns_pk primary key (approval_type_code, txn_id),
    constraint xxfnd_approval_txns_ck1 check (approval_status in ('IN_PROGRESS','COMPLETED','CANCELLED'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_approval_txns is 'The approval of one transaction: the rule that applied and the approver whose turn it is (CURRENT_SEQ).'~');
    end if;

    if xxfnd_ddl_pkg.create_table('XXFND_APPROVAL_TXN_STEPS', q'~create table xxfnd_approval_txn_steps (
    approval_type_code     varchar2(30)   not null,
    txn_id                 varchar2(150)  not null,
    step_seq               number         not null,
    step_name              varchar2(100)  not null,
    approver_type          varchar2(10)   not null,
    role_code              varchar2(30),
    user_name              varchar2(255),
    source                 varchar2(10)   default 'RULE' not null,
    added_by               varchar2(255),
    added_comment          varchar2(4000),
    added_date             timestamp,
    constraint xxfnd_approval_txn_steps_pk primary key (approval_type_code, txn_id, step_seq),
    constraint xxfnd_approval_txn_steps_fk1 foreign key (approval_type_code, txn_id)
        references xxfnd_approval_txns (approval_type_code, txn_id) on delete cascade,
    constraint xxfnd_approval_txn_steps_ck1 check (source in ('RULE','ADHOC'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_approval_txn_steps is 'The approvers of one transaction in order: copied from its rule, plus the ad-hoc approvers added on the way.'~');
    end if;

    xxfnd_ddl_pkg.ensure_sequence('XXFND_APPROVAL_RULE_S', 'create sequence xxfnd_approval_rule_s');
end;
/

create or replace trigger xxfnd_approval_rules_bi
    before insert on xxfnd_approval_rules
    for each row
    when (new.rule_id is null)
begin
    :new.rule_id := xxfnd_approval_rule_s.nextval;
end;
/

create or replace type xxfnd_approval_step_row force as object (
    position       number,
    step_name      varchar2(100),
    approver_type  varchar2(10),
    role_code      varchar2(30),
    user_name      varchar2(255),
    source         varchar2(10),
    added_by       varchar2(255),
    added_comment  varchar2(4000),
    step_state     varchar2(10)
);
/
create or replace type xxfnd_approval_step_tab force as table of xxfnd_approval_step_row;
/

create or replace package xxfnd_approval_rule_pkg authid definer as
    -- Registers (or renames) a transaction type and its attributes ('CODE=Name[=LOOKUP_TYPE]' items).
    procedure register_type(p_type in varchar2, p_application_code in varchar2, p_name in varchar2,
                            p_description in varchar2 default null, p_attributes in apex_t_varchar2 default null);
    -- The rule a transaction matches. p_attributes: 'CODE=value' items.
    function matching_rule(p_type in varchar2, p_attributes in apex_t_varchar2) return number;
    -- Release 76 (A-11): why a transaction could not start its approval, or null. No matching rule (XXFND_APPROVAL_NO_RULE),
    -- or a step of the matching rule that nobody can approve: no active user holds its role (XXFND_APPROVAL_NO_APPROVER).
    -- A component calls it on Submit, so the user gets the message instead of a workflow that faults later.
    function approval_error(p_type in varchar2, p_attributes in apex_t_varchar2) return varchar2;
    -- Starts the approval of a transaction: copies the matching rule's approvers; returns the rule name.
    -- A transaction already started is started again (a resubmitted request). Release 76: a rule without steps is the
    -- deliberate "no approval" rule - the approval is complete at once (STEP_COUNT = 0, the component approves it);
    -- APPROVAL_ERROR is raised as an error.
    function start_approval(p_type in varchar2, p_txn_id in varchar2, p_attributes in apex_t_varchar2,
                            p_requester in varchar2) return varchar2;
    -- Y while the transaction has an approval in progress.
    function is_started(p_type in varchar2, p_txn_id in varchar2) return varchar2;
    -- The step whose turn it is: its name, and its approvers (comma-separated user names).
    function current_step_name(p_type in varchar2, p_txn_id in varchar2) return varchar2;
    function current_approvers(p_type in varchar2, p_txn_id in varchar2) return varchar2;
    -- Role of the current step (null for a user / requester step).
    function current_role(p_type in varchar2, p_txn_id in varchar2) return varchar2;
    -- Position (1, 2, ...) and number of steps.
    function current_position(p_type in varchar2, p_txn_id in varchar2) return number;
    function step_count(p_type in varchar2, p_txn_id in varchar2) return number;
    -- Moves to the next approver: Y when there is one, N when the approval is complete.
    function next_step(p_type in varchar2, p_txn_id in varchar2) return varchar2;
    -- Ad-hoc approver after the current step (p_position NEXT) or at the end (END). Allowed to the requester and
    -- the current approvers (p_force Y: the component checked it).
    procedure add_approver(p_type in varchar2, p_txn_id in varchar2, p_approver_type in varchar2,
                           p_role_code in varchar2 default null, p_user_name in varchar2 default null,
                           p_position in varchar2 default 'NEXT', p_comment in varchar2 default null,
                           p_force in varchar2 default 'N');
    procedure cancel(p_type in varchar2, p_txn_id in varchar2);

    -- Release 82: the one task decision every application calls (no copies of the APEX task calls on pages).
    -- p_decision: APPROVE | REJECT | REQUEST_INFO | SUBMIT_INFO | ADD_APPROVER | COMMENT. A comment (p_comment) is
    -- recorded on the task first for APPROVE, REJECT, ADD_APPROVER and COMMENT; it is the question for REQUEST_INFO
    -- and the answer for SUBMIT_INFO. ADD_APPROVER adds p_add_user after the current approver of p_approval_type /
    -- p_txn_id. Returns Y when done; N for REQUEST_INFO when the task cannot ask its initiator (the approver is the
    -- initiator): the application then returns the record to its requester in its own way.
    function decide_task(p_task_id       in number,
                         p_decision      in varchar2,
                         p_comment       in varchar2 default null,
                         p_approval_type in varchar2 default null,
                         p_txn_id        in varchar2 default null,
                         p_add_user      in varchar2 default null) return varchar2;
    -- The approvers of a transaction in order, with their state (DONE, CURRENT, WAITING); before its approval
    -- started, the matching rule's approvers (state EXPECTED) for the attributes given.
    function steps(p_type in varchar2, p_txn_id in varchar2, p_attributes in apex_t_varchar2 default null)
        return xxfnd_approval_step_tab pipelined;
    -- Release 76 (F-05): the number of approvals in progress started from a rule (the rule screen's impact preview; a
    -- count only, whatever the administrator's data security on the transactions).
    function open_count(p_rule_id in number) return number;
    -- Display name of an approver (role name, user name or "Requester").
    function approver_label(p_approver_type in varchar2, p_role_code in varchar2, p_user_name in varchar2) return varchar2;
end xxfnd_approval_rule_pkg;
/

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
        for s in (select step_name, role_code from xxfnd_approval_rule_steps
                   where rule_id = l_rule and approver_type = 'ROLE' order by step_no) loop
            if xxfnd_workflow_pkg.users_in_role(s.role_code) is null then
                return xxfnd_error_pkg.message('XXFND_APPROVAL_NO_APPROVER',
                                               apex_t_varchar2(s.step_name, approver_label('ROLE', s.role_code, null)));
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
                                              user_name, source)
        select upper(p_type), p_txn_id, row_number() over (order by step_no) * 10, step_name, approver_type, role_code,
               user_name, 'RULE'
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

    function approver_label(p_approver_type in varchar2, p_role_code in varchar2, p_user_name in varchar2) return varchar2 is
        l_name xxfnd_roles.role_name%type;
    begin
        if p_approver_type = 'USER' then
            select max(nvl(full_name, user_name)) into l_name from xxfnd_employees where user_name = upper(p_user_name);
            return nvl(l_name, p_user_name);
        elsif p_approver_type = 'REQUESTER' then
            return 'Requester';
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

end xxfnd_approval_rule_pkg;
/

-- messages (administrators may change the texts; existing rows are kept)
merge into xxfnd_messages d
using (select 'XXFND_APPROVAL_NO_RULE' code, 'No approval rule applies to this {1} transaction. Ask the administrator to add a rule in Approval Setup.' txt, -20531 num from dual
       union all select 'XXFND_APPROVAL_NOT_IN_PROGRESS', 'This approval is not in progress.', -20532 from dual
       union all select 'XXFND_APPROVAL_ADD_NOT_ALLOWED', 'Only the requester or the current approver can add an approver.', -20533 from dual
       union all select 'XXFND_APPROVAL_APPROVER_REQUIRED', 'Choose the role or the user to add as approver.', -20534 from dual
       -- release 76 (A-11)
       union all select 'XXFND_APPROVAL_NO_APPROVER', 'The approval step "{1}" has no approver: no active user holds the role {2}. Ask the administrator to give the role to a user or to change the rule in Approval Setup.', -20535 from dual) s
   on (d.message_code = s.code and d.language_code = 'en')
 when not matched then insert (message_code, language_code, message_text, error_number) values (s.code, 'en', s.txt, s.num);
commit;
