--------------------------------------------------------------------------------
-- 09f Central error handling (release 74). COMMON only (XXFUSION); every application uses it.
--   - XXFND_MESSAGES: the message catalogue (code + language -> text with {1}..{n} tokens). Packages raise by code
--     (XXFND_ERROR_PKG.RAISE_ERROR); a constraint name can also be a code, so a broken rule shows a readable message.
--     Administrators edit the texts; release 75 adds other languages.
--   - XXFND_ERROR_LOG: every unexpected error (user, application, page, component, error, stack), with a reference
--     number shown to the user.
--   - XXFND_ERROR_PKG.APEX_ERROR_HANDLER: the APEX error handling function of every application. Messages raised
--     by the application (ORA-20000..20999) are shown as they are; a known constraint shows its catalogue text;
--     anything else is logged and the user sees a friendly message with the reference.
--   Standard pattern in packages: catch only what you handle; to log and re-raise
--       when others then xxfnd_error_pkg.log_error('<package>.<procedure>'); raise;
-- Idempotent (CREATE_TABLE only when missing; changes as checked steps).
--------------------------------------------------------------------------------
begin
    if xxfnd_ddl_pkg.create_table('XXFND_MESSAGES', q'~create table xxfnd_messages (
    message_code           varchar2(128)  not null,
    language_code          varchar2(10)   default 'en' not null,
    message_text           varchar2(4000) not null,
    error_number           number(5),
    description            varchar2(1000),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_messages_pk primary key (message_code, language_code),
    constraint xxfnd_messages_ck1 check (error_number between -20999 and -20000)
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_messages is 'Message catalogue: user messages by code and language ({1}..{n} = values). A constraint name as code gives that rule a readable message.'~');
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_messages.error_number is 'Oracle error number raised for the message (-20000..-20999); empty = -20000.'~');
    end if;
end;
/
