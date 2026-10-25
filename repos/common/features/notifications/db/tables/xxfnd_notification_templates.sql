
--==============================================================================
-- 0.0  NOTIFICATION TEMPLATES, AUDIT, RETENTION
--==============================================================================
begin
    if xxfnd_ddl_pkg.create_table('XXFND_NOTIFICATION_TEMPLATES', q'~create table xxfnd_notification_templates (
    template_code          varchar2(50)   not null,
    application_code       varchar2(30),
    subject                varchar2(500)  not null,
    body_html              clob           not null,
    enabled_flag           varchar2(1)    default 'Y' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_notif_templates_pk primary key (template_code),
    constraint xxfnd_notif_templates_ck1 check (enabled_flag in ('Y','N'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_notification_templates is 'Wording of every system email and alert. Placeholders use #TOKEN# syntax and are replaced at send time.'~');
    end if;
end;
/
