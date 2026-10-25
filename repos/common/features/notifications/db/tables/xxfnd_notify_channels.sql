begin

    if xxfnd_ddl_pkg.create_table('XXFND_NOTIFY_CHANNELS', q'~create table xxfnd_notify_channels (
    channel_code           varchar2(30)   not null,
    channel_name           varchar2(100)  not null,
    delivery_procedure     varchar2(200)  not null,
    integration_purpose    varchar2(30),
    inbox_flag             varchar2(1)    default 'N' not null,
    enabled_flag           varchar2(1)    default 'Y' not null,
    display_sequence       number         default 10 not null,
    description            varchar2(1000),
    created_by             varchar2(255)  not null,
    creation_date          timestamp      not null,
    last_updated_by        varchar2(255)  not null,
    last_update_date       timestamp      not null,
    last_update_login      varchar2(255),
    object_version_number  number         default 1 not null,
    constraint xxfnd_notify_channels_pk primary key (channel_code),
    constraint xxfnd_notify_channels_ck1 check (enabled_flag in ('Y','N')),
    constraint xxfnd_notify_channels_ck2 check (channel_code = upper(channel_code)),
    constraint xxfnd_notify_channels_ck3 check (inbox_flag in ('Y','N'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_notify_channels is 'Release 84: the channels a notification is delivered on (in the application, e-mail, push, Fusion). DELIVERY_PROCEDURE takes the notification ID; INTEGRATION_PURPOSE is the COMMON integration purpose a remote channel calls; INBOX_FLAG Y = its notifications are the person''s notification list (the bell).'~');
    end if;
end;
/
