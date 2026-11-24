begin

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
end;
/
