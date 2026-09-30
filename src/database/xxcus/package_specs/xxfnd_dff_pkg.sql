create or replace package xxcus.xxfnd_dff_pkg authid definer as

    -- Flexfield code registered for a table, or null.
    function flexfield_for_table (
        p_table_name in varchar2
    ) return varchar2;

    -- Context the row uses: reference column, user choice, stored value, default.
    function derive_context (
        p_table_name      in varchar2,
        p_pk_value        in varchar2,
        p_context_code    in varchar2 default null,
        p_reference_value in varchar2 default null
    ) return varchar2;

    -- HTML for the shared DFF region. Empty string when the table has no
    -- enabled DFF or no displayed segment.
    function render (
        p_table_name      in varchar2,
        p_pk_value        in varchar2,
        p_context_code    in varchar2 default null,
        p_reference_value in varchar2 default null,
        p_read_only       in varchar2 default 'N'
    ) return clob;

    -- First error found, or null. Used as an APEX validation.
    function validate (
        p_table_name      in varchar2,
        p_values_json     in clob,
        p_context_code    in varchar2 default null,
        p_pk_value        in varchar2 default null,
        p_reference_value in varchar2 default null
    ) return varchar2;

    -- Writes ATTRIBUTE_CATEGORY and every configured segment column. Columns
    -- of contexts other than the one in use are cleared, as in EBS.
    procedure save (
        p_table_name      in varchar2,
        p_pk_value        in varchar2,
        p_values_json     in clob,
        p_context_code    in varchar2 default null,
        p_reference_value in varchar2 default null
    );

    -- SQL typed in by administrators (a TABLE value set's query, a segment's SQL default) runs with the
    -- schema's rights, so it must be a query: SELECT or WITH, one statement, :CONTEXT_CODE as the only bind.
    -- P_KIND = VALUE_SET (columns RETURN_VALUE and DISPLAY_VALUE) or DEFAULT (one value).
    -- P_PARSE = Y also parses it (setup screens, on save); the runtime re-checks without parsing.
    -- Returns the problem, or null when the SQL is acceptable.
    function admin_sql_error (
        p_sql   in clob,
        p_kind  in varchar2,
        p_parse in varchar2 default 'Y'
    ) return varchar2;

    -- Values for a segment's list: RETURN_VALUE, DISPLAY_VALUE, PARENT_VALUE.
    -- Also used by the setup screens to preview a value set.
    function value_list (
        p_value_set_code in varchar2,
        p_context_code   in varchar2 default null
    ) return sys_refcursor;

end xxfnd_dff_pkg;
/


-- sqlcl_snapshot {"hash":"5bd5c5274f10ef4dd3709abc722a416c98f88c76","type":"PACKAGE_SPEC","name":"XXFND_DFF_PKG","schemaName":"XXCUS","sxml":""}