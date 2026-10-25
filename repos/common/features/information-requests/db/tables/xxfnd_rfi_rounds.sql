declare
    l_n pls_integer;
begin

    if xxfnd_ddl_pkg.create_table('XXFND_RFI_ROUNDS', q'~create table xxfnd_rfi_rounds (
    rfi_id                 number         not null,
    round_no               number         not null,
    question               varchar2(4000) not null,
    asked_by               varchar2(255),
    asked_date             timestamp      default systimestamp not null,
    response_text          clob,
    responded_by           varchar2(255),
    responded_date         timestamp,
    review_outcome         varchar2(30),
    review_notes           varchar2(4000),
    reviewed_by            varchar2(255),
    reviewed_date          timestamp,
    constraint xxfnd_rfi_rounds_pk primary key (rfi_id, round_no),
    constraint xxfnd_rfi_rounds_fk1 foreign key (rfi_id) references xxfnd_rfis (rfi_id) on delete cascade,
    constraint xxfnd_rfi_rounds_ck1 check (review_outcome in ('RESOLVED', 'ASKED_AGAIN', 'REJECTED_RETURNED', 'CANCELLED'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_rfi_rounds is 'Each question of an RFI and its answer and review: the RFI loops (asked again) until resolved.'~');
    end if;
end;
/
