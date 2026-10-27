begin

    if xxfnd_ddl_pkg.create_table('XXFND_NOTIFY_EVENTS', q'~create table xxfnd_notify_events (
    event_code             varchar2(30)   not null,
    event_name             varchar2(200)  not null,
    template_code          varchar2(50)   not null,
    trigger_code           varchar2(30)   not null,
    outcome_code           varchar2(30),
    link_application_code  varchar2(30),
    link_page_alias        varchar2(255),
    link_items             varchar2(1000),
    link_tokens            varchar2(1000),
    link_public_flag       varchar2(1)    default 'N' not null,
    enabled_flag           varchar2(1)    default 'Y' not null,
    description            varchar2(1000),
    created_by             varchar2(255)  not null,
    creation_date          timestamp      not null,
    last_updated_by        varchar2(255)  not null,
    last_update_date       timestamp      not null,
    last_update_login      varchar2(255),
    object_version_number  number         default 1 not null,
    constraint xxfnd_notify_events_pk primary key (event_code),
    constraint xxfnd_notify_events_fk1 foreign key (template_code) references xxfnd_notification_templates (template_code),
    constraint xxfnd_notify_events_ck1 check (enabled_flag in ('Y','N')),
    constraint xxfnd_notify_events_ck2 check (link_public_flag in ('Y','N'))
)~') then
        xxfnd_ddl_pkg.run(q'~create unique index xxfnd_notify_events_u1 on xxfnd_notify_events (trigger_code, nvl(outcome_code, '#'))~');
        xxfnd_ddl_pkg.run(q'~create index xxfnd_notify_events_n1 on xxfnd_notify_events (template_code)~');
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_notify_events is 'Release 84: notification events. TRIGGER_CODE is what raises the event (an APEX task event CREATE, COMPLETE, REQUEST_INFO, SUBMIT_INFO; a deadline REMINDER, ESCALATION; an RFI step), OUTCOME_CODE narrows a completion (APPROVED, REJECTED). The link is the page LINK_PAGE_ALIAS of application LINK_APPLICATION_CODE (empty = the task''s own application), with LINK_ITEMS set from the event values LINK_TOKENS; LINK_PUBLIC_FLAG Y for a page opened without an account.'~');
    end if;
end;
/
