create or replace package xxcus.xxfnd_util_pkg authid definer as
    -- Signed-in APEX user, or the database user outside APEX (install, jobs).
    function current_user return varchar2;
    -- Session language as an APEX language code ('en', 'ar'); defaults to 'en'.
    function current_lang return varchar2;

    function in_apex_session return boolean;
    -- Install mode: seed scripts run inside an APEX session when installed as
    -- Supporting Objects; this makes the session count as "not APEX" so seeded
    -- rows are not treated as user edits (maker-checker, lookup locks).
    procedure set_install_mode (
        p_on in boolean
    );

    function lookup_meaning (
        p_lookup_type in varchar2,
        p_lookup_code in varchar2
    ) return varchar2;

    function is_valid_lookup (
        p_lookup_type in varchar2,
        p_lookup_code in varchar2
    ) return boolean;

    procedure assert_lookup (
        p_lookup_type in varchar2,
        p_lookup_code in varchar2,
        p_label       in varchar2
    );

    -- Replace #TOKEN# placeholders from a JSON object {"TOKEN":"value",...}.
    function replace_tokens (
        p_text        in clob,
        p_tokens_json in clob
    ) return clob;

    -- WHO-column trigger: fills CREATED_BY/CREATION_DATE/LAST_UPDATED_BY/
    -- LAST_UPDATE_DATE/LAST_UPDATE_LOGIN and increments OBJECT_VERSION_NUMBER.
    procedure create_who_trigger (
        p_table_name in varchar2
    );
    -- Creates WHO triggers on every XXFND_/XXCMP_ table that has the WHO columns.
    procedure create_all_who_triggers;

end xxfnd_util_pkg;
/


-- sqlcl_snapshot {"hash":"b86d80e5fa4f7ca038e0f0fd9474eb3371c19556","type":"PACKAGE_SPEC","name":"XXFND_UTIL_PKG","schemaName":"XXCUS","sxml":""}