--------------------------------------------------------------------------------
-- 15c Request for Information workflow (release 74). COMMON only (XXFUSION); every application uses it.
--   Release 84: the RFI runs as the APEX workflow process RFI of COMMON (Shared Components > Workflows): it creates
--   the RFI_RESPONSE task (a user answers; one per provider), waits for an outside person's answer through the
--   one-time link (public page Provide Information; the answer continues the workflow), then the RFI_REVIEW task;
--   asked again, it loops. This package keeps the data (questions, answers, one-time link) and the rules; it no
--   longer creates tasks itself.
--   An application raises an RFI on one of its records (entity + key) to a person: a user (answers in My Tasks,
--   RFI_RESPONSE task) or an external person (answers through a one-time e-mailed link). The answer is reviewed
--   (RFI_REVIEW task); the reviewer resolves it or asks again - the same RFI loops, one round per question
--   (XXFND_RFI_ROUNDS) - until it is resolved or cancelled. The application keeps its own screens and checks and
--   gives the recipient (e.g. a contact person of a customer).
--   KYC's earlier RFIs (XXCMP_RFIS) are copied here once with their numbers (KYC script 16k); XXCMP_RFIS itself is
--   kept unchanged as history.
-- Idempotent (CREATE_TABLE only when missing; changes as checked steps).
--------------------------------------------------------------------------------
declare
    l_n pls_integer;
begin
    if xxfnd_ddl_pkg.create_table('XXFND_RFIS', q'~create table xxfnd_rfis (
    rfi_id                   number         not null,
    rfi_number               varchar2(30)   not null,
    application_code         varchar2(30)   not null,
    entity_name              varchar2(60)   not null,
    pk1_value                varchar2(150)  not null,
    recipient_type           varchar2(30)   not null,
    recipient_user_name      varchar2(255),
    recipient_name           varchar2(360),
    recipient_email          varchar2(320),
    recipient_reference      varchar2(150),
    approval_type_code       varchar2(30),
    rfi_category             varchar2(30)   not null,
    description              varchar2(4000) not null,
    continue_other_work_flag varchar2(1)    default 'Y' not null,
    rfi_status               varchar2(30)   default 'WAITING_FOR_INFORMATION' not null,
    round_no                 number         default 1 not null,
    due_date                 date,
    response_token_hash      varchar2(128),
    token_expiry_date        timestamp,
    response_text            clob,
    responded_date           timestamp,
    resolved_date            timestamp,
    resolution_notes         varchar2(4000),
    response_task_id         number,
    review_task_id           number,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_rfis_pk primary key (rfi_id),
    constraint xxfnd_rfis_uk1 unique (rfi_number),
    constraint xxfnd_rfis_ck1 check (recipient_type in ('USER', 'EXTERNAL')),
    constraint xxfnd_rfis_ck2 check (continue_other_work_flag in ('Y', 'N')),
    constraint xxfnd_rfis_ck3 check (rfi_status in
        ('WAITING_FOR_INFORMATION', 'ON_HOLD_PENDING', 'RESPONDED', 'ON_HOLD_INVESTIGATION', 'RESOLVED',
         'REJECTED_RETURNED', 'CANCELLED')),
    constraint xxfnd_rfis_ck4 check ((recipient_type = 'USER' and recipient_user_name is not null)
                                  or (recipient_type = 'EXTERNAL' and (recipient_email is not null or recipient_reference is not null)))
)~') then
        xxfnd_ddl_pkg.run(q'~create index xxfnd_rfis_n1 on xxfnd_rfis (application_code, entity_name, pk1_value)~');
        xxfnd_ddl_pkg.run(q'~create index xxfnd_rfis_n2 on xxfnd_rfis (upper(recipient_user_name))~');
        xxfnd_ddl_pkg.run(q'~create unique index xxfnd_rfis_u2 on xxfnd_rfis (response_token_hash)~');
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_rfis is 'Requests for information of every application: one row per RFI; its questions and answers are in XXFND_RFI_ROUNDS.'~');
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_rfis.response_token_hash is 'SHA-256 hash of the one-time token e-mailed to an external person. The token itself is never stored.'~');
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_rfis.recipient_reference is 'The application''s own key of the recipient (KYC: party contact ID).'~');
    end if;
end;
/
