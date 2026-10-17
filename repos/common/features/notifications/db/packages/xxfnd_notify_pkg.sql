
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

create or replace package body xxfnd_notify_pkg as
    -- communications: the attachment entity of an e-mail (release 82: moved to the top with the merge)
    c_entity constant varchar2(30) := 'XXFND_COMMUNICATIONS';
    -- release 84: the people of a notification rule
    type t_person is record (user_name varchar2(255), email_address varchar2(320), language_code varchar2(10));
    type t_people is table of t_person index by pls_integer;
    -- the notification being delivered with a link that must not be kept (a one-time answer link): the delivery
    -- procedures send these, the table keeps the masked wording
    g_secret_id      number;
    g_secret_message clob;
    g_secret_link    varchar2(4000);
    c_masked_link    constant varchar2(30) := '[secure link]';


    function user_language(p_user_name in varchar2) return varchar2 is
        l_lang varchar2(10);
    begin
        select max(language_code) into l_lang from xxfnd_users where user_name = upper(p_user_name);
        return nvl(l_lang, 'en');
    end user_language;

    -- The wording of a template in a language (English, then the base row, when not translated); null when the
    -- template does not exist or is disabled (p_enabled_only).
    procedure wording(p_template_code in varchar2, p_language in varchar2, p_enabled_only in boolean,
                      p_subject out varchar2, p_message out clob) is
        -- release 82: wording only; a row kept from before release 82 may still hold HTML: its tags are dropped
        function plain(p_text in clob) return clob is
        begin
            return regexp_replace(regexp_replace(p_text, '<br\s*/?>|</p>|</div>|</li>', chr(10), 1, 0, 'i'), '<[^>]+>', '');
        end plain;
    begin
        for w in (select coalesce(t.subject, e.subject, n.subject) subject,
                         t.message_text t_text, t.body_html t_html, e.message_text e_text, e.body_html e_html,
                         n.message_text n_text, n.body_html n_html
                    from xxfnd_notification_templates n
                    left join xxfnd_notification_templates_tl t
                      on t.template_code = n.template_code and t.language_code = nvl(p_language, 'en')
                    left join xxfnd_notification_templates_tl e
                      on e.template_code = n.template_code and e.language_code = 'en'
                   where n.template_code = p_template_code
                     and (n.enabled_flag = 'Y' or not p_enabled_only)) loop
            p_subject := w.subject;
            p_message := coalesce(w.t_text, plain(w.t_html), w.e_text, plain(w.e_html), w.n_text, plain(w.n_html));
        end loop;
    end wording;

    -- release 84: the link label is wording too (XXFND_NOTIFICATION_TEMPLATES.ACTION_LABEL per language; before release 84 a fixed label in this package)
    function action_label(p_template_code in varchar2, p_language in varchar2) return varchar2 is
        l_label varchar2(100);
    begin
        select max(coalesce(t.action_label, e.action_label, n.action_label))
          into l_label
          from xxfnd_notification_templates n
          left join xxfnd_notification_templates_tl t
            on t.template_code = n.template_code and t.language_code = nvl(p_language, 'en')
          left join xxfnd_notification_templates_tl e
            on e.template_code = n.template_code and e.language_code = 'en'
         where n.template_code = p_template_code;
        return l_label;
    end action_label;

    function common_app_id return number is
        l_id number;
    begin
        select max(apex_application_id) into l_id from xxfnd_applications where application_code = 'COMMON';
        return l_id;
    end common_app_id;

    -- release 84: the settings are read from the APEX dictionary for the COMMON application, whichever application
    -- raised the notification
    function common_setting(p_name in varchar2) return varchar2 is
        l_value varchar2(4000);
        l_app   number := common_app_id;
    begin
        select max(value) into l_value
          from apex_application_settings
         where application_id = l_app and name = upper(p_name);
        return l_value;
    end common_setting;

    -- the placeholders of the XXFND_STANDARD layout: the sender's footer is the COMMON setting MAIL_FOOTER
    function placeholders(p_subject in varchar2, p_message in clob, p_url in varchar2, p_label in varchar2,
                          p_language in varchar2) return clob is
        l_json json_object_t := json_object_t();
    begin
        l_json.put('SUBJECT', p_subject);
        l_json.put('MESSAGE', p_message);
        l_json.put('ACTION_URL', p_url);
        l_json.put('ACTION_LABEL', case when p_url is not null then p_label end);
        l_json.put('FOOTER', common_setting('MAIL_FOOTER'));
        l_json.put('DIR', case when p_language = 'ar' then 'rtl' else 'ltr' end);
        return l_json.to_clob;
    end placeholders;

    function deliver(p_to in varchar2, p_subject in varchar2, p_message in clob, p_url in varchar2,
                     p_label in varchar2, p_language in varchar2) return number is
    begin
        return apex_mail.send(
                   p_to                 => p_to,
                   p_from               => common_setting('MAIL_FROM'),
                   p_template_static_id => c_layout,
                   p_placeholders       => placeholders(p_subject, p_message, p_url, p_label, p_language),
                   p_application_id     => common_app_id);
    end deliver;

    -- the link of a token set (the older wording carries it as TASK_URL or RESPONSE_URL)
    function token_link(p_tokens in clob) return varchar2 is
        l_tokens json_object_t;
    begin
        if p_tokens is null then
            return null;
        end if;
        l_tokens := json_object_t.parse(p_tokens);
        return coalesce(l_tokens.get_string('LINK'), l_tokens.get_string('TASK_URL'), l_tokens.get_string('RESPONSE_URL'));
    end token_link;

    function send_message(p_template_code    in varchar2,
                          p_to               in varchar2,
                          p_tokens           in clob     default null,
                          p_language         in varchar2 default null,
                          p_process_code     in varchar2 default null,
                          p_application_code in varchar2 default null) return number is
        l_subject varchar2(4000);
        l_message clob;
        l_lang    varchar2(10) := nvl(p_language, 'en');
    begin
        if p_to is null or common_setting('MAIL_FROM') is null
           or xxfnd_workflow_pkg.email_enabled(p_process_code, p_application_code) = 'N' then   -- e-mail switched off
            return null;
        end if;
        wording(p_template_code, l_lang, true, l_subject, l_message);
        if l_subject is null then
            return null;   -- no such template, or disabled
        end if;
        if p_tokens is not null then
            l_subject := dbms_lob.substr(xxfnd_util_pkg.replace_tokens(l_subject, p_tokens), 500, 1);
            l_message := xxfnd_util_pkg.replace_tokens(l_message, p_tokens);
        end if;
        return deliver(p_to, l_subject, l_message, token_link(p_tokens), action_label(p_template_code, l_lang), l_lang);
    end send_message;

    procedure send(p_template_code in varchar2, p_to in varchar2, p_tokens in clob default null,
                   p_process_code in varchar2 default null, p_language in varchar2 default null) is
        l_mail_id number;
    begin
        l_mail_id := send_message(p_template_code, p_to, p_tokens, p_language, p_process_code);
    end send;

    procedure send_to_users(p_template_code in varchar2, p_user_names in varchar2, p_tokens in clob default null,
                            p_process_code in varchar2 default null) is
    begin
        for u in (select e.email_address, max(nvl(us.language_code, 'en')) language_code
                    from xxfnd_employees e
                    left join xxfnd_users us on us.user_name = e.user_name
                   where e.user_name in (select upper(trim(column_value)) from table(apex_string.split(p_user_names, ',')))
                     and e.enabled_flag = 'Y'
                     and e.email_address is not null
                   group by e.email_address) loop
            send(p_template_code, u.email_address, p_tokens, p_process_code, u.language_code);
        end loop;
    end send_to_users;

    function preview_subject(p_template_code in varchar2, p_language in varchar2 default null,
                             p_tokens in clob default null) return varchar2 is
        l_subject varchar2(4000);
        l_message clob;
    begin
        wording(p_template_code, nvl(p_language, 'en'), false, l_subject, l_message);
        return case when p_tokens is null then l_subject
                    else dbms_lob.substr(xxfnd_util_pkg.replace_tokens(l_subject, p_tokens), 4000, 1) end;
    end preview_subject;

    function preview_message(p_template_code in varchar2, p_language in varchar2 default null,
                             p_tokens in clob default null) return clob is
        l_subject varchar2(4000);
        l_message clob;
    begin
        wording(p_template_code, nvl(p_language, 'en'), false, l_subject, l_message);
        return case when p_tokens is null then l_message else xxfnd_util_pkg.replace_tokens(l_message, p_tokens) end;
    end preview_message;

    procedure send_test(p_template_code in varchar2, p_language in varchar2 default null) is
        l_to      varchar2(320);
        l_subject varchar2(4000);
        l_message clob;
        l_mail_id number;
    begin
        select max(e.email_address) into l_to from xxfnd_employees e where e.user_name = xxfnd_util_pkg.current_user;
        if l_to is null then
            select max(email_address) into l_to from xxfnd_users where user_name = xxfnd_util_pkg.current_user;
        end if;
        if l_to is null then
            raise_application_error(-20162, 'You have no e-mail address: the test cannot be sent.');
        end if;
        if common_setting('MAIL_FROM') is null then
            raise_application_error(-20163, 'The sender address (application setting MAIL_FROM) is not set.');
        end if;
        wording(p_template_code, nvl(p_language, 'en'), false, l_subject, l_message);
        l_mail_id := deliver(l_to, '[Test] ' || l_subject, l_message, null, null, nvl(p_language, 'en'));
        apex_mail.push_queue;
    end send_test;


    ---------------------------------------------------------------- notifications driven by data (release 84)

    function event_for(p_trigger_code in varchar2, p_outcome_code in varchar2 default null) return varchar2 is
        l_event xxfnd_notify_events.event_code%type;
    begin
        select max(event_code) into l_event
          from xxfnd_notify_events
         where trigger_code = upper(p_trigger_code)
           and nvl(outcome_code, '#') = nvl(upper(p_outcome_code), '#')
           and enabled_flag = 'Y';
        return l_event;
    end event_for;

    -- the people of a recipient type: its query, run with the binds it uses
    function people(p_recipient_type in varchar2, p_value in varchar2, p_task_id in number, p_workflow_id in number,
                    p_detail_pk in varchar2, p_application_code in varchar2, p_process_code in varchar2) return t_people is
        l_query  xxfnd_notify_recipient_types.recipient_query%type;
        l_cur    integer;
        l_cols   dbms_sql.desc_tab2;
        l_ncol   integer;
        l_rows   integer;
        l_pos    apex_t_varchar2 := apex_t_varchar2(null, null, null);   -- column positions: user, e-mail, language
        l_val    varchar2(4000);
        l_people t_people;
        l_i      pls_integer := 0;
        procedure bind(p_name in varchar2, p_bind_value in varchar2) is
        begin
            if regexp_like(l_query, ':' || p_name || '([^A-Za-z0-9_$#]|$)', 'i') then
                dbms_sql.bind_variable(l_cur, ':' || p_name, p_bind_value);
            end if;
        end bind;
    begin
        select recipient_query into l_query from xxfnd_notify_recipient_types where recipient_type_code = p_recipient_type;
        l_cur := dbms_sql.open_cursor;
        begin
            dbms_sql.parse(l_cur, l_query, dbms_sql.native);
            bind('TASK_ID', to_char(p_task_id));
            bind('WORKFLOW_ID', to_char(p_workflow_id));
            bind('DETAIL_PK', p_detail_pk);
            bind('APPLICATION_CODE', p_application_code);
            bind('PROCESS_CODE', p_process_code);
            bind('VALUE', p_value);
            dbms_sql.describe_columns2(l_cur, l_ncol, l_cols);
            for c in 1 .. l_ncol loop
                case upper(l_cols(c).col_name)
                    when 'USER_NAME'     then l_pos(1) := c;
                    when 'EMAIL_ADDRESS' then l_pos(2) := c;
                    when 'LANGUAGE_CODE' then l_pos(3) := c;
                    else null;
                end case;
                dbms_sql.define_column(l_cur, c, l_val, 4000);
            end loop;
            l_rows := dbms_sql.execute(l_cur);
            while dbms_sql.fetch_rows(l_cur) > 0 loop
                l_i := l_i + 1;
                for k in 1 .. 3 loop
                    if l_pos(k) is not null then
                        dbms_sql.column_value(l_cur, to_number(l_pos(k)), l_val);
                        case k
                            when 1 then l_people(l_i).user_name     := upper(l_val);
                            when 2 then l_people(l_i).email_address := l_val;
                            else        l_people(l_i).language_code := l_val;
                        end case;
                    end if;
                end loop;
                if l_people(l_i).user_name is null and l_people(l_i).email_address is null then
                    l_people.delete(l_i);
                    l_i := l_i - 1;
                end if;
            end loop;
            dbms_sql.close_cursor(l_cur);
        exception
            when others then
                if dbms_sql.is_open(l_cur) then
                    dbms_sql.close_cursor(l_cur);
                end if;
                raise;
        end;
        return l_people;
    end people;

    function rule_recipients(p_rule_id in number, p_task_id in number default null, p_workflow_id in number default null,
                             p_detail_pk in varchar2 default null) return varchar2 is
        l_rule   xxfnd_notify_rules%rowtype;
        l_people t_people;
        l_list   varchar2(32767);
    begin
        select * into l_rule from xxfnd_notify_rules where rule_id = p_rule_id;
        l_people := people(l_rule.recipient_type_code, l_rule.recipient_value, p_task_id, p_workflow_id, p_detail_pk,
                           l_rule.application_code, l_rule.process_code);
        for i in 1 .. l_people.count loop
            l_list := l_list || case when l_list is not null then ', ' end
                   || coalesce(l_people(i).user_name, l_people(i).email_address);
        end loop;
        return substr(l_list, 1, 4000);
    end rule_recipients;

    -- the link of an event: page LINK_PAGE_ALIAS of the event's application (empty = the task's application), its
    -- items set from the event values LINK_TOKENS; a LINK value given by the caller wins
    function event_link(p_event in xxfnd_notify_events%rowtype, p_task_id in number, p_application_code in varchar2,
                        p_tokens in clob) return varchar2 is
        l_tokens json_object_t := case when p_tokens is not null then json_object_t.parse(p_tokens) end;
        l_app    number;
        l_values varchar2(4000);
    begin
        if l_tokens is not null and l_tokens.get_string('LINK') is not null then
            return l_tokens.get_string('LINK');
        end if;
        if p_event.link_page_alias is null then
            return null;
        end if;
        select max(apex_application_id) into l_app from xxfnd_applications
         where application_code = coalesce(p_event.link_application_code, p_application_code);
        if l_app is null and p_task_id is not null then
            select max(application_id) into l_app from apex_tasks where task_id = p_task_id;
        end if;
        for t in (select trim(column_value) name from table(apex_string.split(p_event.link_tokens, ','))) loop
            l_values := l_values || case when l_values is not null then ',' end
                     || case when l_tokens is not null then l_tokens.get_string(t.name) end;
        end loop;
        return apex_page.get_url(p_application  => to_char(l_app),
                                 p_page         => p_event.link_page_alias,
                                 p_session      => case when p_event.link_public_flag = 'Y' then 0 end,
                                 p_items        => p_event.link_items,
                                 p_values       => l_values,
                                 p_plain_url    => true,
                                 p_absolute_url => true);
    exception
        when others then
            return null;   -- no APEX context (e.g. a script): the notification goes without its link
    end event_link;

    procedure set_status(p_notification_id in number, p_status in varchar2, p_text in varchar2 default null,
                         p_mail_id in number default null) is
    begin
        update xxfnd_notifications
           set status_code = p_status, status_text = substr(p_text, 1, 4000), mail_id = nvl(p_mail_id, mail_id)
         where notification_id = p_notification_id;
    end set_status;

    procedure deliver_one(p_notification_id in number, p_procedure in varchar2) is
    begin
        execute immediate 'begin ' || dbms_assert.qualified_sql_name(p_procedure) || '(:id); end;' using p_notification_id;
    exception
        when others then
            -- a failing channel never stops the business step that raised the event
            set_status(p_notification_id, 'FAILED', sqlerrm);
    end deliver_one;

    procedure raise_event_(p_event_code       in varchar2,
                           p_application_code in varchar2,
                           p_process_code     in varchar2,
                           p_task_id          in number,
                           p_workflow_id      in number,
                           p_detail_pk        in varchar2,
                           p_tokens           in clob) is
        l_event   xxfnd_notify_events%rowtype;
        l_people  t_people;
        l_done    apex_t_varchar2 := apex_t_varchar2();
        l_key     varchar2(1000);
        l_link    varchar2(4000);
        l_tokens  json_object_t;
        l_subject varchar2(4000);
        l_message clob;
        l_shown   clob;
        l_lang    varchar2(10);
        l_email   varchar2(320);
        l_label   varchar2(100);
        l_id      number;
    begin
        begin
            select * into l_event from xxfnd_notify_events where event_code = p_event_code and enabled_flag = 'Y';
        exception
            when no_data_found then
                return;   -- not set up, or switched off
        end;
        l_link := event_link(l_event, p_task_id, p_application_code, p_tokens);
        l_tokens := case when p_tokens is not null then json_object_t.parse(p_tokens) else json_object_t() end;
        -- the older wording names the link TASK_URL or RESPONSE_URL
        l_tokens.put('LINK', l_link);
        l_tokens.put('TASK_URL', l_link);
        l_tokens.put('RESPONSE_URL', l_link);
        for r in (select r.rule_id, r.recipient_type_code, r.recipient_value, r.channel_code,
                         nvl(r.template_code, l_event.template_code) template_code, c.delivery_procedure
                    from xxfnd_notify_rules r
                    join xxfnd_notify_channels c on c.channel_code = r.channel_code
                   where r.event_code = l_event.event_code
                     and r.enabled_flag = 'Y'
                     and c.enabled_flag = 'Y'
                     and (r.application_code is null or r.application_code = p_application_code)
                     and (r.process_code is null or r.process_code = upper(p_process_code))
                   order by c.display_sequence, r.rule_id) loop
            l_people := people(r.recipient_type_code, r.recipient_value, p_task_id, p_workflow_id, p_detail_pk,
                               p_application_code, upper(p_process_code));
            for i in 1 .. l_people.count loop
                l_key := r.channel_code || '|' || coalesce(l_people(i).user_name, lower(l_people(i).email_address));
                continue when l_key member of l_done;
                l_done.extend;
                l_done(l_done.count) := l_key;
                l_lang := coalesce(l_people(i).language_code,
                                   case when l_people(i).user_name is not null then user_language(l_people(i).user_name) end, 'en');
                wording(r.template_code, l_lang, true, l_subject, l_message);
                continue when l_subject is null;   -- the wording is switched off
                l_subject := dbms_lob.substr(xxfnd_util_pkg.replace_tokens(l_subject, l_tokens.to_clob), 500, 1);
                l_message := xxfnd_util_pkg.replace_tokens(l_message, l_tokens.to_clob);
                if l_event.link_public_flag = 'Y' and l_link is not null then
                    -- a one-time answer link is sent, never kept
                    l_shown := replace(l_message, l_link, c_masked_link);
                else
                    l_shown := l_message;
                end if;
                l_email := l_people(i).email_address;
                if l_email is null and l_people(i).user_name is not null then
                    select max(email_address) into l_email from xxfnd_employees
                     where user_name = l_people(i).user_name and enabled_flag = 'Y';
                end if;
                l_label := action_label(r.template_code, l_lang);
                insert into xxfnd_notifications (event_code, channel_code, rule_id, application_code, process_code,
                                                 user_name, email_address, language_code, subject, message_text,
                                                 link_url, link_label, task_id, workflow_id, detail_pk)
                values (l_event.event_code, r.channel_code, r.rule_id, p_application_code, upper(p_process_code),
                        l_people(i).user_name, l_email, l_lang, nvl(l_subject, l_event.event_name), l_shown,
                        case when l_event.link_public_flag = 'Y' and l_link is not null then c_masked_link else l_link end,
                        l_label, p_task_id, p_workflow_id, p_detail_pk)
                returning notification_id into l_id;
                g_secret_id      := l_id;
                g_secret_message := l_message;
                g_secret_link    := l_link;
                deliver_one(l_id, r.delivery_procedure);
                g_secret_id      := null;
                g_secret_message := null;
                g_secret_link    := null;
            end loop;
        end loop;
    end raise_event_;

    procedure raise_event(p_event_code       in varchar2,
                          p_application_code in varchar2 default null,
                          p_process_code     in varchar2 default null,
                          p_task_id          in number   default null,
                          p_workflow_id      in number   default null,
                          p_detail_pk        in varchar2 default null,
                          p_tokens           in clob     default null) is
    begin
        -- the setup (wording, rules, people) is read whoever raises the event: a task action runs in the workflow's
        -- background session (no user), where the data security of the setup tables would hide it
        xxfnd_vpd_pkg.begin_trusted;
        raise_event_(p_event_code, p_application_code, p_process_code, p_task_id, p_workflow_id, p_detail_pk, p_tokens);
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end raise_event;

    procedure deliver_in_app(p_notification_id in number) is
        l_user xxfnd_notifications.user_name%type;
    begin
        select user_name into l_user from xxfnd_notifications where notification_id = p_notification_id;
        if l_user is null then
            set_status(p_notification_id, 'SKIPPED', 'A person without an account has no notification list.');
        else
            set_status(p_notification_id, 'SENT');
        end if;
    end deliver_in_app;

    procedure deliver_email(p_notification_id in number) is
        l_n       xxfnd_notifications%rowtype;
        l_mail_id number;
    begin
        select * into l_n from xxfnd_notifications where notification_id = p_notification_id;
        if l_n.email_address is null then
            set_status(p_notification_id, 'SKIPPED', 'No e-mail address.');
        elsif common_setting('MAIL_FROM') is null then
            set_status(p_notification_id, 'SKIPPED', 'The sender address (COMMON setting MAIL_FROM) is not set.');
        elsif xxfnd_workflow_pkg.email_enabled(l_n.process_code, l_n.application_code) = 'N' then
            set_status(p_notification_id, 'SKIPPED', 'E-mail is switched off for this process or application.');
        else
            l_mail_id := deliver(l_n.email_address, l_n.subject,
                                 case when g_secret_id = p_notification_id then g_secret_message else l_n.message_text end,
                                 case when g_secret_id = p_notification_id then g_secret_link else l_n.link_url end,
                                 l_n.link_label, l_n.language_code);
            set_status(p_notification_id, 'SENT', null, l_mail_id);
        end if;
    end deliver_email;

    procedure deliver_push(p_notification_id in number) is
        l_n xxfnd_notifications%rowtype;
    begin
        select * into l_n from xxfnd_notifications where notification_id = p_notification_id;
        if l_n.user_name is null then
            set_status(p_notification_id, 'SKIPPED', 'A person without an account has no device subscribed.');
        elsif not apex_pwa.has_push_subscription(p_application_id => common_app_id, p_user_name => l_n.user_name) then
            set_status(p_notification_id, 'SKIPPED', 'No device of this person is subscribed to push notifications.');
        else
            apex_pwa.send_push_notification(p_application_id => common_app_id,
                                            p_user_name      => l_n.user_name,
                                            p_title          => l_n.subject,
                                            p_body           => dbms_lob.substr(l_n.message_text, 1000, 1),
                                            p_target_url     => l_n.link_url);
            set_status(p_notification_id, 'SENT');
        end if;
    end deliver_push;

    procedure deliver_fusion(p_notification_id in number) is
        l_n       xxfnd_notifications%rowtype;
        l_purpose xxfnd_notify_channels.integration_purpose%type;
        l_body    json_object_t := json_object_t();
        l_resp    clob;
    begin
        select * into l_n from xxfnd_notifications where notification_id = p_notification_id;
        select max(integration_purpose) into l_purpose from xxfnd_notify_channels where channel_code = l_n.channel_code;
        if l_n.user_name is null then
            set_status(p_notification_id, 'SKIPPED', 'A person without an account is not a Fusion user.');
            return;
        end if;
        l_body.put('userName', l_n.user_name);
        l_body.put('title', l_n.subject);
        l_body.put('message', dbms_lob.substr(l_n.message_text, 4000, 1));
        l_body.put('link', l_n.link_url);
        l_resp := xxfnd_integration_pkg.call(p_purpose_code => l_purpose, p_http_method => 'POST', p_body => l_body.to_clob,
                                             p_entity_name  => 'XXFND_NOTIFICATIONS', p_pk1_value => to_char(p_notification_id));
        set_status(p_notification_id, 'SENT');
    end deliver_fusion;

    function has_push(p_user_name in varchar2 default null) return varchar2 is
    begin
        return case when apex_pwa.has_push_subscription(p_application_id => common_app_id,
                                                        p_user_name => upper(nvl(p_user_name, xxfnd_util_pkg.current_user)))
                    then 'Y' else 'N' end;
    exception
        when others then
            return 'N';   -- not a progressive web app (push not set up)
    end has_push;

    function unread_count(p_user_name in varchar2 default null) return number is
        l_n number;
    begin
        select count(*) into l_n
          from xxfnd_notifications n
          join xxfnd_notify_channels c on c.channel_code = n.channel_code and c.inbox_flag = 'Y'
         where n.user_name = upper(nvl(p_user_name, xxfnd_util_pkg.current_user))
           and n.status_code = 'SENT' and n.read_date is null;
        return l_n;
    end unread_count;

    procedure mark_read(p_notification_id in number) is
    begin
        -- only the person's own notification
        update xxfnd_notifications set read_date = systimestamp
         where notification_id = p_notification_id and user_name = upper(xxfnd_util_pkg.current_user)
           and read_date is null;
    end mark_read;

    procedure mark_all_read is
    begin
        update xxfnd_notifications set read_date = systimestamp
         where user_name = upper(xxfnd_util_pkg.current_user) and read_date is null
           and channel_code in (select channel_code from xxfnd_notify_channels where inbox_flag = 'Y');
    end mark_all_read;


    ---------------------------------------------------------------- communications (e-mails per record)


    function valid_addresses(p_list in varchar2) return boolean is
    begin
        for a in (select trim(column_value) addr from table(apex_string.split(replace(p_list, ';', ','), ','))
                   where trim(column_value) is not null) loop
            if not regexp_like(a.addr, '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$') then
                return false;
            end if;
        end loop;
        return true;
    end valid_addresses;

    function email_error(p_direction in varchar2, p_address in varchar2, p_subject in varchar2, p_body in clob) return varchar2 is
    begin
        if trim(p_address) is null then
            return case when p_direction = 'OUT' then 'Enter who the e-mail goes to.' else 'Enter who sent the e-mail.' end;
        elsif not valid_addresses(p_address) then
            return 'Enter valid e-mail addresses (separate several with a comma).';
        elsif trim(p_subject) is null then
            return 'Enter the subject.';
        elsif p_body is null or dbms_lob.getlength(p_body) = 0 then
            return 'Enter the message.';
        end if;
        return null;
    end email_error;

    procedure keep_file(p_communication_id in number, p_temp_file_name in varchar2, p_application_code in varchar2) is
        l_id number;
    begin
        if p_temp_file_name is not null then
            l_id := xxfnd_attach_pkg.add_file(p_entity_name    => c_entity,
                                              p_pk1_value      => to_char(p_communication_id),
                                              p_category_code  => 'OTHER',
                                              p_temp_file_name => p_temp_file_name,
                                              p_title          => 'E-mail attachment');
        end if;
    end keep_file;

    function record_open(p_entity_name in varchar2, p_pk1_value in varchar2) return varchar2 is
        l_n pls_integer;
    begin
        if not xxfnd_util_pkg.in_apex_session or xxfnd_vpd_pkg.is_trusted then
            return 'Y';
        end if;
        select count(*) into l_n from xxfnd_document_entities where entity_name = upper(p_entity_name);
        if l_n = 0 then
            return 'Y';
        end if;
        return xxfnd_attach_pkg.record_visible(p_entity_name, p_pk1_value);
    end record_open;

    function send_email(p_application_code in varchar2,
                        p_entity_name      in varchar2,
                        p_pk1_value        in varchar2,
                        p_to               in varchar2,
                        p_subject          in varchar2,
                        p_body             in clob,
                        p_cc               in varchar2 default null,
                        p_rfi_id           in number   default null,
                        p_in_reply_to_id   in number   default null,
                        p_temp_file_name   in varchar2 default null) return number is
        l_error   varchar2(4000) := email_error('OUT', p_to, p_subject, p_body);
        l_from    varchar2(320)  := common_setting('MAIL_FROM');
        l_status  varchar2(30)   := 'NOT_SENT';
        l_mail_id number;
        l_id      number;
        l_code    xxfnd_applications.application_code%type;
    begin
        l_code := xxfnd_application_pkg.registered_code(p_application_code);   -- release 88 (C10): its own records only
        if record_open(p_entity_name, p_pk1_value) = 'N' then
            xxfnd_error_pkg.raise_error('XXFND_NOT_ALLOWED');    -- release 87 (C1): only the e-mails of a record the user sees
        end if;
        if l_error is not null then
            raise_application_error(-20540, l_error);
        end if;
        if l_from is not null and xxfnd_workflow_pkg.email_enabled(null, p_application_code) = 'Y' then
            l_mail_id := apex_mail.send(p_to => p_to, p_cc => p_cc, p_from => l_from, p_subj => substr(p_subject, 1, 500),
                                        p_body => p_body);
            for f in (select filename, mime_type, blob_content from apex_application_temp_files
                       where name = p_temp_file_name) loop
                apex_mail.add_attachment(p_mail_id => l_mail_id, p_attachment => f.blob_content,
                                         p_filename => f.filename, p_mime_type => f.mime_type);
            end loop;
            l_status := 'SENT';
        end if;
        insert into xxfnd_communications (application_code, entity_name, pk1_value, rfi_id, direction, from_address,
                                          to_address, cc_address, subject, body, status, source, mail_id, in_reply_to_id,
                                          recorded_by)
        values (p_application_code, p_entity_name, p_pk1_value, p_rfi_id, 'OUT', l_from, p_to, p_cc,
                substr(p_subject, 1, 500), p_body, l_status, 'APEX_MAIL', l_mail_id, p_in_reply_to_id,
                xxfnd_util_pkg.current_user)
        returning communication_id into l_id;
        keep_file(l_id, p_temp_file_name, p_application_code);
        return l_id;
    end send_email;

    procedure record_sent(p_application_code in varchar2,
                          p_entity_name      in varchar2,
                          p_pk1_value        in varchar2,
                          p_to               in varchar2,
                          p_subject          in varchar2,
                          p_body             in clob,
                          p_rfi_id           in number default null,
                          p_mail_id          in number default null) is
        l_code xxfnd_applications.application_code%type := xxfnd_application_pkg.registered_code(p_application_code);   -- release 88 (C10)
    begin
        insert into xxfnd_communications (application_code, entity_name, pk1_value, rfi_id, direction, from_address,
                                          to_address, subject, body, status, source, mail_id, recorded_by)
        values (p_application_code, p_entity_name, p_pk1_value, p_rfi_id, 'OUT', common_setting('MAIL_FROM'),
                p_to, nvl(substr(p_subject, 1, 500), '-'), p_body, 'SENT', 'APEX_MAIL', p_mail_id,
                xxfnd_util_pkg.current_user);
    end record_sent;

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
                             p_temp_file_name      in varchar2 default null) return number is
        l_error varchar2(4000) := email_error('IN', p_from, p_subject, p_body);
        l_id    number;
        l_code  xxfnd_applications.application_code%type;
    begin
        l_code := xxfnd_application_pkg.registered_code(p_application_code);   -- release 88 (C10)
        if record_open(p_entity_name, p_pk1_value) = 'N' then
            xxfnd_error_pkg.raise_error('XXFND_NOT_ALLOWED');    -- release 87 (C1)
        end if;
        if l_error is not null then
            raise_application_error(-20540, l_error);
        end if;
        insert into xxfnd_communications (application_code, entity_name, pk1_value, rfi_id, direction, from_address,
                                          subject, body, communication_date, status, source, external_message_id,
                                          conversation_id, in_reply_to_id, recorded_by)
        values (p_application_code, p_entity_name, p_pk1_value, p_rfi_id, 'IN', p_from, substr(p_subject, 1, 500), p_body,
                nvl(p_received_date, systimestamp), 'RECEIVED', p_source, p_external_message_id, p_conversation_id,
                p_in_reply_to_id, xxfnd_util_pkg.current_user)
        returning communication_id into l_id;
        keep_file(l_id, p_temp_file_name, p_application_code);
        return l_id;
    end record_received;

    ---------------------------------------------------------------- release 86: registration and the rule switch
    procedure register_template(p_application_code in varchar2,
                                p_template_code    in varchar2,
                                p_subject          in varchar2,
                                p_message_text     in clob,
                                p_action_label     in varchar2 default null,
                                p_subject_ar       in varchar2 default null,
                                p_message_text_ar  in clob     default null,
                                p_action_label_ar  in varchar2 default null) is
        l_code xxfnd_notification_templates.application_code%type := xxfnd_application_pkg.setup_code(p_application_code);
        l_tpl  xxfnd_notification_templates.template_code%type := upper(p_template_code);
        l_n    pls_integer;
        l_row  xxfnd_notification_templates.application_code%type;
    begin
        select count(*), max(application_code) into l_n, l_row from xxfnd_notification_templates where template_code = l_tpl;
        if l_n > 0 then
            xxfnd_application_pkg.assert_same_application('Notification template', l_tpl, l_row, p_application_code);
        else
            insert into xxfnd_notification_templates (template_code, application_code, subject, message_text, action_label,
                                                      enabled_flag)
            values (l_tpl, l_code, p_subject, p_message_text, p_action_label, 'Y');
        end if;
        if p_subject_ar is not null then
            merge into xxfnd_notification_templates_tl t
            using (select l_tpl template_code, 'ar' language_code from dual) s
               on (t.template_code = s.template_code and t.language_code = s.language_code)
             when not matched then insert (template_code, language_code, subject, message_text, action_label)
                                   values (l_tpl, 'ar', p_subject_ar, p_message_text_ar, p_action_label_ar);
        end if;
    end register_template;

    procedure set_rule_enabled(p_rule_id in number, p_enabled_flag in varchar2) is
    begin
        if xxfnd_util_pkg.in_apex_session
           and not (xxfnd_privilege_pkg.has_privilege('APPLICATIONS', 'MANAGE')
                    or xxfnd_privilege_pkg.has_privilege('NOTIFICATIONS', 'MANAGE')) then
            xxfnd_error_pkg.raise_error('XXFND_NOT_ALLOWED');
        end if;
        update xxfnd_notify_rules set enabled_flag = case when p_enabled_flag = 'Y' then 'Y' else 'N' end
         where rule_id = p_rule_id;
        if sql%rowcount = 0 then
            xxfnd_error_pkg.raise_error('XXFND_REG_UNKNOWN', apex_t_varchar2('Notification rule', to_char(p_rule_id)));
        end if;
    end set_rule_enabled;

    -- release 88 (C8, C9)
    -- release 88 (C6)
    procedure register_contact_source(p_application_code in varchar2,
                                      p_entity_name      in varchar2,
                                      p_source_view      in varchar2,
                                      p_description      in varchar2 default null) is
        l_code   xxfnd_applications.application_code%type := xxfnd_application_pkg.registered_code(p_application_code);
        l_schema xxfnd_applications.schema_name%type;
        l_view   varchar2(128) := upper(trim(p_source_view));
        l_owner  xxfnd_contact_sources.application_code%type;
        l_n      pls_integer;
    begin
        select max(schema_name) into l_schema from xxfnd_applications where application_code = l_code;
        select count(distinct column_name) into l_n from all_tab_columns
         where owner = l_schema and table_name = l_view and column_name in ('PK1_VALUE', 'CONTACT_NAME', 'EMAIL_ADDRESS');
        if l_n < 3 then
            xxfnd_error_pkg.raise_error('XXFND_CONTACT_SOURCE_VIEW', apex_t_varchar2(l_view, l_schema));
        end if;
        select max(application_code) into l_owner from xxfnd_contact_sources where entity_name = upper(trim(p_entity_name));
        xxfnd_application_pkg.assert_same_application('Contact source', upper(trim(p_entity_name)), l_owner, l_code);
        merge into xxfnd_contact_sources t
        using (select upper(trim(p_entity_name)) entity_name from dual) s
           on (t.entity_name = s.entity_name)
         when matched then update set t.source_view = l_view, t.description = nvl(p_description, t.description)
         when not matched then insert (entity_name, application_code, source_view, description)
                               values (s.entity_name, l_code, l_view, p_description);
    end register_contact_source;

    procedure unregister_contact_source(p_application_code in varchar2, p_entity_name in varchar2) is
    begin
        xxfnd_application_pkg.remove_registered(p_application_code, 'Contact source', 'XXFND_CONTACT_SOURCES',
            apex_t_varchar2('ENTITY_NAME'), apex_t_varchar2(upper(trim(p_entity_name))));
    end unregister_contact_source;

    function contacts(p_entity_name in varchar2, p_pk1_value in varchar2) return xxfnd_contact_tab pipelined is
        l_src  varchar2(300);
        l_cur  sys_refcursor;
        l_name varchar2(400);
        l_mail varchar2(320);
    begin
        select max(dbms_assert.enquote_name(a.schema_name, false) || '.' || dbms_assert.enquote_name(c.source_view, false))
          into l_src
          from xxfnd_contact_sources c
          join xxfnd_applications a on a.application_code = c.application_code
         where c.entity_name = upper(p_entity_name) and c.enabled_flag = 'Y';
        if l_src is null or p_pk1_value is null or record_open(p_entity_name, p_pk1_value) = 'N' then
            return;
        end if;
        open l_cur for 'select substr(contact_name, 1, 400), substr(email_address, 1, 320) from ' || l_src
                    || ' where pk1_value = :p and email_address is not null order by contact_name' using p_pk1_value;
        loop
            fetch l_cur into l_name, l_mail;
            exit when l_cur%notfound;
            pipe row (xxfnd_contact_row(l_name, l_mail));
        end loop;
        close l_cur;
        return;
    exception
        when no_data_needed then
            if l_cur%isopen then close l_cur; end if;
        when others then
            if l_cur%isopen then close l_cur; end if;
            xxfnd_error_pkg.log_error('XXFND_NOTIFY_PKG.CONTACTS', sqlerrm);
            return;
    end contacts;

    procedure unregister_template(p_application_code in varchar2, p_template_code in varchar2) is
    begin
        xxfnd_application_pkg.remove_registered(p_application_code, 'Notification template', 'XXFND_NOTIFICATION_TEMPLATES',
            apex_t_varchar2('TEMPLATE_CODE'), apex_t_varchar2(upper(trim(p_template_code))));
    end unregister_template;

    procedure unregister_application(p_application_code in varchar2) is
    begin
        xxfnd_application_pkg.remove_all_registered(p_application_code, 'Contact sources', 'XXFND_CONTACT_SOURCES');
        xxfnd_application_pkg.remove_all_registered(p_application_code, 'Notification rules', 'XXFND_NOTIFY_RULES');
        xxfnd_application_pkg.remove_all_registered(p_application_code, 'Notification templates', 'XXFND_NOTIFICATION_TEMPLATES');
    end unregister_application;

end xxfnd_notify_pkg;
/
