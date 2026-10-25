
create or replace package body xxfnd_error_pkg as

    function session_language return varchar2 is
    begin
        return nvl(lower(substr(apex_util.get_session_lang, 1, 2)), 'en');
    exception
        when others then
            return 'en';
    end session_language;

    function message(p_code in varchar2, p_values in apex_t_varchar2 default null) return varchar2 is
        l_text xxfnd_messages.message_text%type;
        l_lang varchar2(10) := session_language;
    begin
        select max(message_text) keep (dense_rank first order by case when language_code = l_lang then 0 else 1 end)
          into l_text
          from xxfnd_messages
         where message_code = upper(p_code) and language_code in (l_lang, 'en');
        l_text := nvl(l_text, p_code);
        if p_values is not null then
            for i in 1 .. p_values.count loop
                l_text := replace(l_text, '{' || i || '}', p_values(i));
            end loop;
        end if;
        return l_text;
    end message;

    procedure raise_error(p_code in varchar2, p_values in apex_t_varchar2 default null) is
        l_number xxfnd_messages.error_number%type;
    begin
        select max(error_number) into l_number from xxfnd_messages where message_code = upper(p_code);
        raise_application_error(nvl(l_number, -20000), message(p_code, p_values));
    end raise_error;

    procedure register_message(p_code in varchar2, p_text in varchar2, p_error_number in number default null,
                               p_language in varchar2 default 'en') is
    begin
        merge into xxfnd_messages t
        using (select upper(p_code) message_code, lower(p_language) language_code from dual) s
           on (t.message_code = s.message_code and t.language_code = s.language_code)
         when not matched then insert (message_code, language_code, message_text, error_number)
                               values (s.message_code, s.language_code, p_text, p_error_number);
    end register_message;

    function write_log(p_component in varchar2, p_code in number, p_message in varchar2, p_info in clob,
                       p_backtrace in clob, p_stack in clob) return number is
        pragma autonomous_transaction;
        l_id xxfnd_error_log.error_id%type;
    begin
        insert into xxfnd_error_log (user_name, application_id, page_id, session_id, request, component, error_code,
                                     error_message, technical_info, backtrace, call_stack)
        values (v('APP_USER'), to_number(v('APP_ID')), to_number(v('APP_PAGE_ID')), to_number(v('APP_SESSION')),
                substr(v('REQUEST'), 1, 255), substr(p_component, 1, 1000), p_code, substr(p_message, 1, 4000),
                p_info, p_backtrace, p_stack)
        returning error_id into l_id;
        commit;
        return l_id;
    end write_log;

    function log_error(p_component in varchar2, p_message in varchar2 default null) return number is
    begin
        return write_log(p_component, sqlcode, nvl(p_message, sqlerrm), null,
                         dbms_utility.format_error_backtrace, dbms_utility.format_call_stack);
    end log_error;

    procedure log_error(p_component in varchar2, p_message in varchar2 default null) is
        l_id number;
    begin
        l_id := log_error(p_component, p_message);
    end log_error;

    function apex_error_handler(p_error in apex_error.t_error) return apex_error.t_error_result is
        l_result     apex_error.t_error_result;
        l_constraint varchar2(255);
        l_text       xxfnd_messages.message_text%type;
        l_ref        number;
        l_lang       varchar2(10) := session_language;

        function logged return number is
        begin
            return write_log(p_error.component.type || ' ' || p_error.component.name, p_error.ora_sqlcode,
                             p_error.message, p_error.additional_info || chr(10) || p_error.ora_sqlerrm,
                             p_error.error_backtrace, p_error.error_statement);
        end logged;
    begin
        l_result := apex_error.init_error_result(p_error => p_error);

        if p_error.is_internal_error then
            -- APEX's own errors: the common ones (session expired, no access) stay as APEX shows them
            if not p_error.is_common_runtime_error then
                l_ref := logged;
                l_result.message         := message(c_unexpected, apex_t_varchar2(to_char(l_ref)));
                l_result.additional_info := null;
            end if;
        else
            -- never the full error page for an application error
            if l_result.display_location = apex_error.c_on_error_page then
                l_result.display_location := apex_error.c_inline_in_notification;
            end if;

            if p_error.ora_sqlcode in (-1, -2091, -2290, -2291, -2292, -1400) then
                -- a database rule: its catalogue text when there is one
                l_constraint := apex_error.extract_constraint_name(p_error => p_error);
                if l_constraint is not null then
                    select max(message_text) keep (dense_rank first order by case when language_code = l_lang then 0 else 1 end)
                      into l_text from xxfnd_messages
                     where message_code = upper(l_constraint) and language_code in (l_lang, 'en');
                end if;
                if l_text is not null then
                    l_result.message := l_text;
                else
                    l_ref := logged;
                    l_result.message := message(c_unexpected, apex_t_varchar2(to_char(l_ref)));
                end if;
            elsif p_error.ora_sqlcode between -20999 and -20000 then
                -- a message the application raised for the user
                l_result.message := apex_error.get_first_ora_error_text(p_error => p_error);
            elsif p_error.ora_sqlcode is not null then
                l_ref := logged;
                l_result.message := message(c_unexpected, apex_t_varchar2(to_char(l_ref)));
            end if;
            l_result.additional_info := null;

            -- highlight the field the error belongs to
            if l_result.page_item_name is null and l_result.column_alias is null then
                apex_error.auto_set_associated_item(p_error => p_error, p_error_result => l_result);
            end if;
        end if;
        return l_result;
    end apex_error_handler;

end xxfnd_error_pkg;
/
