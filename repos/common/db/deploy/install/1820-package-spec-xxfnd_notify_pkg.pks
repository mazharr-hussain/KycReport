
create or replace package xxfnd_notify_pkg authid definer as
    -- Release 82: one package for notifications and e-mail with outside people (was XXFND_COMMUNICATION_PKG).

    -- Release 82: e-mails use the APEX Email Template XXFND_STANDARD of the COMMON application (the layout: #SUBJECT#,
    -- #MESSAGE#, #ACTION_URL#, #ACTION_LABEL#, #FOOTER#, #DIR#). XXFND_NOTIFICATION_TEMPLATES keeps only the wording:
    -- a subject and a plain-text message per event, translated in XXFND_NOTIFICATION_TEMPLATES_TL. The wording is in
    -- the recipient's language (English when not translated); Arabic is sent right to left. #TOKEN# placeholders are
    -- replaced from the JSON object P_TOKENS (plain values: the layout escapes them); the link is the token TASK_URL,
    -- RESPONSE_URL or LINK.
    c_layout constant varchar2(30) := 'XXFND_STANDARD';

    -- Sends notification template P_TEMPLATE_CODE to P_TO in P_LANGUAGE (default English). Does nothing when the
    -- template is disabled, the MAIL_FROM application setting is empty, or e-mail is off for the instance, the
    -- application or the workflow process (P_PROCESS_CODE, XXFND_WORKFLOW_PKG.EMAIL_ENABLED). Returns the APEX mail ID
    -- (null when nothing was sent).
    function send_message(p_template_code    in varchar2,
                          p_to               in varchar2,
                          p_tokens           in clob     default null,
                          p_language         in varchar2 default null,
                          p_process_code     in varchar2 default null,
                          p_application_code in varchar2 default null) return number;
    procedure send(p_template_code in varchar2, p_to in varchar2, p_tokens in clob default null,
                   p_process_code in varchar2 default null, p_language in varchar2 default null);
    -- Same, once per application user (comma-separated user names) that has an e-mail address, each in their language
    -- (XXFND_USERS.LANGUAGE_CODE).
    procedure send_to_users(p_template_code in varchar2, p_user_names in varchar2, p_tokens in clob default null,
                            p_process_code in varchar2 default null);
    -- The wording as it is sent (tokens without a value stay as #TOKEN#), for the Notifications screen preview.
    function preview_subject(p_template_code in varchar2, p_language in varchar2 default null,
                             p_tokens in clob default null) return varchar2;
    function preview_message(p_template_code in varchar2, p_language in varchar2 default null,
                             p_tokens in clob default null) return clob;
    -- "Send test to me": the wording in P_LANGUAGE to the current user's e-mail address, whatever the switches.
    procedure send_test(p_template_code in varchar2, p_language in varchar2 default null);
    -- The language of a user (XXFND_USERS.LANGUAGE_CODE), English when unknown.
    function user_language(p_user_name in varchar2) return varchar2;

    ---------------------------------------------------------------- notifications driven by data (release 84)
    -- Raises event P_EVENT_CODE (XXFND_NOTIFY_EVENTS). Every enabled rule of the event (XXFND_NOTIFY_RULES: for
    -- P_APPLICATION_CODE / P_PROCESS_CODE or for every one) on an enabled channel tells the people its recipient type
    -- returns (XXFND_NOTIFY_RECIPIENT_TYPES), each once per channel, in their language, with the event's link. Every
    -- notification is kept in XXFND_NOTIFICATIONS with its delivery status; a failing channel never stops the caller.
    -- P_TOKENS (JSON object): the values of the wording (#TOKEN#) and of the link (the event's LINK_TOKENS; a LINK
    -- value is used as the link itself).
    procedure raise_event(p_event_code       in varchar2,
                          p_application_code in varchar2 default null,
                          p_process_code     in varchar2 default null,
                          p_task_id          in number   default null,
                          p_workflow_id      in number   default null,
                          p_detail_pk        in varchar2 default null,
                          p_tokens           in clob     default null);
    -- The event raised by a trigger (an APEX task event CREATE / COMPLETE / REQUEST_INFO / SUBMIT_INFO, a deadline
    -- REMINDER / ESCALATION, an RFI step) and outcome; null when none is set up or it is disabled.
    function event_for(p_trigger_code in varchar2, p_outcome_code in varchar2 default null) return varchar2;
    -- The people a rule tells for a task / workflow / record (comma-separated user names or e-mail addresses), for
    -- the setup screen's "Test".
    function rule_recipients(p_rule_id in number, p_task_id in number default null, p_workflow_id in number default null,
                             p_detail_pk in varchar2 default null) return varchar2;
    -- The delivery procedures of the channels (XXFND_NOTIFY_CHANNELS.DELIVERY_PROCEDURE): each sets the status of the
    -- notification (SENT, SKIPPED with the reason, FAILED with the error).
    procedure deliver_in_app(p_notification_id in number);
    procedure deliver_email(p_notification_id in number);
    procedure deliver_push(p_notification_id in number);
    procedure deliver_fusion(p_notification_id in number);
    -- Y when the person (default: the signed-in one) has a device subscribed to the COMMON push notifications.
    function has_push(p_user_name in varchar2 default null) return varchar2;
    -- The signed-in person's notification list (the bell): unread count, mark one / all as read.
    function unread_count(p_user_name in varchar2 default null) return number;
    procedure mark_read(p_notification_id in number);
    procedure mark_all_read;
    -- A setting of the COMMON application (Shared Components > Application Settings), e.g. MAIL_FROM, MAIL_FOOTER.
    function common_setting(p_name in varchar2) return varchar2;

    ---------------------------------------------------------------- communications (e-mails per record)
    -- Release 87 (C1): Y when the signed-in user may see the record of the e-mails: its row is visible under the
    -- user's data security (XXFND_ATTACH_PKG.RECORD_VISIBLE, for a registered document entity); Y outside an APEX
    -- session (scripts, jobs) and for an entity that is not registered. The e-mail pages show and act only then.
    function record_open(p_entity_name in varchar2, p_pk1_value in varchar2) return varchar2;
    -- Sends an e-mail for a record and keeps it (status SENT; NOT_SENT when e-mail is switched off for the instance or
    -- the application, or MAIL_FROM is not set - the e-mail is still recorded). P_TEMP_FILE_NAME: an uploaded file
    -- (APEX temporary file) sent with it and kept as the communication's attachment. Returns the communication ID.
    function send_email(p_application_code in varchar2,
                        p_entity_name      in varchar2,
                        p_pk1_value        in varchar2,
                        p_to               in varchar2,
                        p_subject          in varchar2,
                        p_body             in clob,
                        p_cc               in varchar2 default null,
                        p_rfi_id           in number   default null,
                        p_in_reply_to_id   in number   default null,
                        p_temp_file_name   in varchar2 default null) return number;
    -- Records an e-mail received from an outside person. Typed by a person now (SOURCE MANUAL); the Outlook
    -- integration later calls it with SOURCE OUTLOOK and the message / conversation IDs. Returns the communication ID.
    function record_received(p_application_code    in varchar2,
                             p_entity_name         in varchar2,
                             p_pk1_value           in varchar2,
                             p_from                in varchar2,
                             p_subject             in varchar2,
                             p_body                in clob,
                             p_received_date       in timestamp with time zone default systimestamp,
                             p_rfi_id              in number   default null,
                             p_in_reply_to_id      in number   default null,
                             p_source              in varchar2 default 'MANUAL',
                             p_external_message_id in varchar2 default null,
                             p_conversation_id     in varchar2 default null,
                             p_temp_file_name      in varchar2 default null) return number;
    -- Keeps an e-mail another common service already sent (e.g. the RFI e-mail from its template), so it shows with
    -- the record's communications.
    procedure record_sent(p_application_code in varchar2,
                          p_entity_name      in varchar2,
                          p_pk1_value        in varchar2,
                          p_to               in varchar2,
                          p_subject          in varchar2,
                          p_body             in clob,
                          p_rfi_id           in number default null,
                          p_mail_id          in number default null);
    -- The rule of an e-mail before it is sent or recorded (null when it is fine).
    function email_error(p_direction in varchar2, p_address in varchar2, p_subject in varchar2, p_body in clob) return varchar2;

    ---------------------------------------------------------------- release 86: registration and the rule switch
    -- The wording of a notification of the application (English; Arabic when given), added when missing (the
    -- administrators own the wording afterwards). ORA-20180 / ORA-20186 as every registration.
    procedure register_template(p_application_code in varchar2,
                                p_template_code    in varchar2,
                                p_subject          in varchar2,
                                p_message_text     in clob,
                                p_action_label     in varchar2 default null,
                                p_subject_ar       in varchar2 default null,
                                p_message_text_ar  in clob     default null,
                                p_action_label_ar  in varchar2 default null);
    -- A notification rule on (Y) or off (N). In an APEX session: Applications - Manage or Notifications - Manage.
    -- ORA-20187 for an unknown rule.
    procedure set_rule_enabled(p_rule_id in number, p_enabled_flag in varchar2);
    -- Release 88 (C8, C9): removes what the application registered (its own rows only, through
    -- XXFND_APPLICATION_PKG.REMOVE_REGISTERED: ORA-20187 not registered, ORA-20186 another application's, ORA-20196 in use).
    procedure unregister_template(p_application_code in varchar2, p_template_code in varchar2);
    -- Release 88 (C6): the contacts of P_ENTITY_NAME's records come from P_SOURCE_VIEW, a view of the application's
    -- own schema with the columns PK1_VALUE, CONTACT_NAME, EMAIL_ADDRESS, on which the application granted SELECT
    -- to COMMON's schema (ORA-20197 otherwise). Re-registering changes the view.
    procedure register_contact_source(p_application_code in varchar2,
                                      p_entity_name      in varchar2,
                                      p_source_view      in varchar2,
                                      p_description      in varchar2 default null);
    procedure unregister_contact_source(p_application_code in varchar2, p_entity_name in varchar2);
    -- The contacts of one record (empty when no source is registered or the user may not see the record).
    function contacts(p_entity_name in varchar2, p_pk1_value in varchar2) return xxfnd_contact_tab pipelined;
    -- the application's templates, contact sources and its own notification rules
    procedure unregister_application(p_application_code in varchar2);
end xxfnd_notify_pkg;
/
