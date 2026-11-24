
-- Release 82: the notification wording is plain text per event and language (MESSAGE_TEXT); the layout is the APEX
-- Email Template XXFND_STANDARD. BODY_HTML is kept (no data is deleted) but no longer required.
begin
    xxfnd_ddl_pkg.add_column('XXFND_NOTIFICATION_TEMPLATES', 'MESSAGE_TEXT', 'clob');
    xxfnd_ddl_pkg.add_column('XXFND_NOTIFICATION_TEMPLATES_TL', 'MESSAGE_TEXT', 'clob');
    xxfnd_ddl_pkg.set_nullable('XXFND_NOTIFICATION_TEMPLATES', 'BODY_HTML');
    xxfnd_ddl_pkg.set_nullable('XXFND_NOTIFICATION_TEMPLATES_TL', 'BODY_HTML');
    xxfnd_ddl_pkg.run(q'~comment on column xxfnd_notification_templates.message_text is 'Release 82: the message as plain text with #TOKEN# placeholders; the layout (links, formatting, direction) comes from the APEX Email Template XXFND_STANDARD.'~');
    xxfnd_ddl_pkg.run(q'~comment on column xxfnd_notification_templates.body_html is 'Before release 82: the message as HTML. Kept; read only when MESSAGE_TEXT is empty (tags dropped).'~');
end;
/
