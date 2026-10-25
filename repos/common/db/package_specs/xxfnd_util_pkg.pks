
create or replace package xxfnd_util_pkg authid definer as
    -- Signed-in APEX user, or the database user outside APEX (install, jobs).
    function current_user return varchar2;
    -- Session language as an APEX language code ('en', 'ar'); defaults to 'en'.
    function current_lang return varchar2;
    function in_apex_session return boolean;
    -- Install mode: seed scripts run inside an APEX session when installed as
    -- Supporting Objects; this makes the session count as "not APEX" so seeded
    -- rows are not treated as user edits (maker-checker, lookup locks).
    procedure set_install_mode(p_on in boolean);
    -- On while user names are renamed (xxfnd_user_pkg.rename_user): the WHO triggers keep the dates and
    -- version of the rows and accept the new user names in CREATED_BY / LAST_UPDATED_BY.
    procedure set_preserve_who(p_on in boolean);
    function preserve_who return boolean;

    -- Replace #TOKEN# placeholders from a JSON object {"TOKEN":"value",...}.
    function replace_tokens(p_text in clob, p_tokens_json in clob) return clob;

    -- WHO-column trigger: fills CREATED_BY/CREATION_DATE/LAST_UPDATED_BY/
    -- LAST_UPDATE_DATE/LAST_UPDATE_LOGIN and increments OBJECT_VERSION_NUMBER.
    procedure create_who_trigger(p_table_name in varchar2);
    -- Creates WHO triggers on every XXFND_/XXCMP_ table that has the WHO columns.
    procedure create_all_who_triggers;

    -- release 54: owner of a table, view or package this schema can see - itself first, else the application
    -- schema that granted it (KYC objects in XXCUS); raises -20130 when there is none.
    function object_owner(p_name in varchar2) return varchar2;
    -- "OWNER"."NAME" of that object, for dynamic SQL.
    function qualified(p_name in varchar2) return varchar2;
end xxfnd_util_pkg;
/
