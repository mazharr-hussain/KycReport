create or replace package xxcus.xxfnd_notify_pkg authid definer as
    -- Sends notification template P_TEMPLATE_CODE (in the user's language when translated)
    -- to P_TO, replacing #TOKEN# placeholders from the JSON object P_TOKENS.
    -- Does nothing when the template is disabled or the MAIL_FROM application setting is empty.
    procedure send (
        p_template_code in varchar2,
        p_to            in varchar2,
        p_tokens        in clob default null
    );
    -- Same, once per application user (comma-separated user names) that has an e-mail address.
    procedure send_to_users (
        p_template_code in varchar2,
        p_user_names    in varchar2,
        p_tokens        in clob default null
    );

end xxfnd_notify_pkg;
/


-- sqlcl_snapshot {"hash":"6e83b3f17727cbe8e622bc7532972d9aff31652a","type":"PACKAGE_SPEC","name":"XXFND_NOTIFY_PKG","schemaName":"XXCUS","sxml":""}