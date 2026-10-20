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

    -- release 94 (UI issue 8): approver types as in AME / BPM - USER (in use now), ROLE, REQUESTER, and the HCM-based
    -- types kept as placeholders until the HCM data is loaded: POSITION, MANAGER, SUP_HIER (supervisor hierarchy),
    -- POS_HIER (position hierarchy), AOR (area of responsibility), QUERY (a query returning the approvers);
    -- APPROVER_VALUE holds their setting (position, levels, query); DUE_DAYS = the step's deadline (days)
    xxfnd_ddl_pkg.add_column('XXFND_APPROVAL_RULE_STEPS', 'APPROVER_VALUE', 'varchar2(4000)');
    xxfnd_ddl_pkg.add_column('XXFND_APPROVAL_RULE_STEPS', 'DUE_DAYS', 'number');
    xxfnd_ddl_pkg.add_column('XXFND_APPROVAL_TXN_STEPS', 'DUE_DAYS', 'number');
    xxfnd_ddl_pkg.drop_constraint('XXFND_APPROVAL_RULE_STEPS', 'XXFND_APPROVAL_RULE_STEPS_CK1');
    xxfnd_ddl_pkg.drop_constraint('XXFND_APPROVAL_RULE_STEPS', 'XXFND_APPROVAL_RULE_STEPS_CK2');
    xxfnd_ddl_pkg.add_constraint('XXFND_APPROVAL_RULE_STEPS', 'XXFND_APPROVAL_RULE_STEPS_CK3',
        q'~check (approver_type in ('ROLE','USER','REQUESTER','POSITION','MANAGER','SUP_HIER','POS_HIER','AOR','QUERY'))~');
    xxfnd_ddl_pkg.add_constraint('XXFND_APPROVAL_RULE_STEPS', 'XXFND_APPROVAL_RULE_STEPS_CK4',
        q'~check ((approver_type = 'ROLE' and role_code is not null) or (approver_type = 'USER' and user_name is not null)
                  or approver_type in ('REQUESTER','POSITION','MANAGER','SUP_HIER','POS_HIER','AOR','QUERY'))~');
    xxfnd_ddl_pkg.add_constraint('XXFND_APPROVAL_RULE_STEPS', 'XXFND_APPROVAL_RULE_STEPS_CK5', 'check (due_days > 0)');
end;
/
