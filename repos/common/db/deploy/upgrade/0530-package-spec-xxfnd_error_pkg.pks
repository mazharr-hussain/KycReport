
create or replace package xxfnd_error_pkg authid definer as
    c_unexpected constant varchar2(30) := 'XXFND_UNEXPECTED_ERROR';

    -- The catalogue text of a code in the session language (else English), {1}..{n} replaced by p_values.
    function message(p_code in varchar2, p_values in apex_t_varchar2 default null) return varchar2;
    -- Raises the catalogue message (its error number, else -20000). An unknown code raises the code itself.
    procedure raise_error(p_code in varchar2, p_values in apex_t_varchar2 default null);
    -- An application registers its own messages (English); an existing text (perhaps changed by the business) is kept.
    procedure register_message(p_code in varchar2, p_text in varchar2, p_error_number in number default null,
                               p_language in varchar2 default 'en');
    -- Logs the current error (sqlcode, sqlerrm, backtrace, call stack) with the place it happened; returns the
    -- reference. Autonomous: the log row stays even when the caller rolls back.
    function log_error(p_component in varchar2, p_message in varchar2 default null) return number;
    procedure log_error(p_component in varchar2, p_message in varchar2 default null);
    -- The APEX error handling function of every application.
    function apex_error_handler(p_error in apex_error.t_error) return apex_error.t_error_result;
end xxfnd_error_pkg;
/
