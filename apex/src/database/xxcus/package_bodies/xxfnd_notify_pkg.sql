create or replace package body xxcus.xxfnd_notify_pkg as

    procedure send (
        p_template_code in varchar2,
        p_to            in varchar2,
        p_tokens        in clob default null
    ) is

        l_from    varchar2(320) := apex_app_setting.get_value('MAIL_FROM');
        l_subject varchar2(4000);
        l_body    clob;
        l_mail_id number;
    begin
        if p_to is null
           or l_from is null then
            return;
        end if;
        begin
            select
                nvl(t.subject, n.subject),
                nvl(t.body_html, n.body_html)
            into
                l_subject,
                l_body
            from
                xxfnd_notification_templates    n
                left join xxfnd_notification_templates_tl t on t.template_code = n.template_code
                                                               and t.language_code = xxfnd_util_pkg.current_lang
            where
                    n.template_code = p_template_code
                and n.enabled_flag = 'Y';

        exception
            when no_data_found then
                return;
        end;

        if p_tokens is not null then
            l_subject := dbms_lob.substr(
                xxfnd_util_pkg.replace_tokens(l_subject, p_tokens),
                4000,
                1
            );

            l_body := xxfnd_util_pkg.replace_tokens(l_body, p_tokens);
        end if;

        l_mail_id := apex_mail.send(
            p_to        => p_to,
            p_from      => l_from,
            p_subj      => substr(l_subject, 1, 500),
            p_body      => regexp_replace(l_body, '<[^>]+>', ''),
            p_body_html => l_body
        );

    end send;

    procedure send_to_users (
        p_template_code in varchar2,
        p_user_names    in varchar2,
        p_tokens        in clob default null
    ) is
    begin
        for u in (
            select distinct
                e.email_address
            from
                xxfnd_employees e
            where
                e.user_name in (
                    select
                        upper(trim(column_value))
                    from
                        table ( apex_string.split(p_user_names, ',') )
                )
                and e.enabled_flag = 'Y'
                and e.email_address is not null
        ) loop
            send(p_template_code, u.email_address, p_tokens);
        end loop;
    end send_to_users;

end xxfnd_notify_pkg;
/


-- sqlcl_snapshot {"hash":"3efc4fe43c138bd8be8a5f4302562b2b5d105fa2","type":"PACKAGE_BODY","name":"XXFND_NOTIFY_PKG","schemaName":"XXCUS","sxml":""}