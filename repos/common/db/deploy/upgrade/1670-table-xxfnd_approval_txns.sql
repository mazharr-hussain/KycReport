begin

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
end;
/
