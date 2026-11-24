begin

    if xxfnd_ddl_pkg.create_table('XXFND_NOTIFY_RECIPIENT_TYPES', q'~create table xxfnd_notify_recipient_types (
    recipient_type_code    varchar2(30)   not null,
    recipient_type_name    varchar2(200)  not null,
    recipient_query        varchar2(4000) not null,
    value_required_flag    varchar2(1)    default 'N' not null,
    description            varchar2(1000),
    created_by             varchar2(255)  not null,
    creation_date          timestamp      not null,
    last_updated_by        varchar2(255)  not null,
    last_update_date       timestamp      not null,
    last_update_login      varchar2(255),
    object_version_number  number         default 1 not null,
    constraint xxfnd_notify_rcpt_types_pk primary key (recipient_type_code),
    constraint xxfnd_notify_rcpt_types_ck1 check (value_required_flag in ('Y','N'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_notify_recipient_types is 'Release 84: who a notification goes to, as a query returning USER_NAME (optionally EMAIL_ADDRESS and LANGUAGE_CODE for a person without an account). Binds: :TASK_ID, :WORKFLOW_ID, :DETAIL_PK, :APPLICATION_CODE, :PROCESS_CODE, :VALUE.'~');
    end if;
end;
/
