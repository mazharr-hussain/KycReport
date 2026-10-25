
begin
    if xxfnd_ddl_pkg.create_table('XXFND_INTEGRATION_PURPOSES', q'~create table xxfnd_integration_purposes (
    purpose_code           varchar2(30)   not null,
    application_code       varchar2(30),
    purpose_name           varchar2(200)  not null,
    endpoint_code          varchar2(30),
    capture_method         varchar2(20)   default 'MANUAL' not null,
    approval_status        varchar2(20)   default 'DRAFT' not null,
    approved_by            varchar2(255),
    approved_date          timestamp,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_int_purposes_pk primary key (purpose_code),
    constraint xxfnd_int_purposes_fk1 foreign key (endpoint_code) references xxfnd_integration_endpoints (endpoint_code),
    constraint xxfnd_int_purposes_ck1 check (capture_method in ('MANUAL','API')),
    constraint xxfnd_int_purposes_ck2 check (approval_status in ('DRAFT','PENDING_APPROVAL','APPROVED','REJECTED')),
    constraint xxfnd_int_purposes_ck3 check (capture_method = 'MANUAL' or endpoint_code is not null)
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_integration_purposes is 'Which endpoint serves each business purpose, and whether it runs manually or by API. Changes take effect only after a second person approves them.'~');
    end if;
end;
/
