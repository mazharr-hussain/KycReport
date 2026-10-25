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
end;
/
