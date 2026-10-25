
begin
    xxfnd_ddl_pkg.ensure_table('XXFND_NOTIFICATION_TEMPLATES_TL', q'~create table xxfnd_notification_templates_tl (
    template_code          varchar2(50)   not null,
    language_code          varchar2(10)   not null,
    subject                varchar2(500)  not null,
    body_html              clob           not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_notif_templates_tl_pk primary key (template_code, language_code),
    constraint xxfnd_notif_templates_tl_fk1 foreign key (template_code)
        references xxfnd_notification_templates (template_code) on delete cascade
)~');
end;
/
