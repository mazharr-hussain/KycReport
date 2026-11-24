
--------------------------------------------------------------------------------
-- Release 84: notifications driven by data (created here, before XXFND_NOTIFY_PKG that reads and writes them).
--   XXFND_NOTIFY_CHANNELS        how a notification reaches a person: in the application (bell), e-mail, push to
--                                the browser or phone (APEX PWA), Fusion notifications (prepared, off). Each channel
--                                names its delivery procedure; a channel switched off sends nothing.
--   XXFND_NOTIFY_EVENTS          what happens (a task is assigned, approved, ...): its wording (notification
--                                template), what raises it (TRIGGER_CODE + OUTCOME) and the link it carries.
--   XXFND_NOTIFY_RECIPIENT_TYPES who can be told: a query that returns USER_NAME (and EMAIL_ADDRESS, LANGUAGE_CODE
--                                for people without an account) with the binds :TASK_ID, :WORKFLOW_ID, :DETAIL_PK,
--                                :APPLICATION_CODE, :PROCESS_CODE and :VALUE (the rule's value: a role, a privilege).
--   XXFND_NOTIFY_RULES           per event (and application / process, empty = every one): who is told on which
--                                channel, optionally in other wording (TEMPLATE_CODE).
--   XXFND_NOTIFICATIONS          every notification made: one row per person and channel, with its status; the
--                                in-application rows are the person's notification list (read or not).
--------------------------------------------------------------------------------
begin
    -- the link label of a notification is wording too (was 'Open' in the package): per template and language
    xxfnd_ddl_pkg.add_column('XXFND_NOTIFICATION_TEMPLATES', 'ACTION_LABEL', 'varchar2(100)');
    xxfnd_ddl_pkg.add_column('XXFND_NOTIFICATION_TEMPLATES_TL', 'ACTION_LABEL', 'varchar2(100)');
end;
/
