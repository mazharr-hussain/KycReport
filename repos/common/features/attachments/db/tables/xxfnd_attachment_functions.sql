
begin
    if xxfnd_ddl_pkg.create_table('XXFND_ATTACHMENT_FUNCTIONS', q'~create table xxfnd_attachment_functions (
    function_code          varchar2(60)   not null,
    application_code       varchar2(30),
    function_name          varchar2(240)  not null,
    apex_app_alias         varchar2(255)  not null,
    apex_page_id           number         not null,
    enabled_flag           varchar2(1)    default 'Y' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_att_functions_pk primary key (function_code),
    constraint xxfnd_att_functions_uk1 unique (apex_app_alias, apex_page_id),
    constraint xxfnd_att_functions_ck1 check (enabled_flag in ('Y','N'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table  xxfnd_attachment_functions is 'An APEX page that shows attachments (FND_ATTACHMENT_FUNCTIONS). Keyed by application alias, which stays stable across imports; the numeric application ID does not.'~');
    end if;
end;
/
