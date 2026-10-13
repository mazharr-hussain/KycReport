--------------------------------------------------------------------------------
-- 06_xxfnd_dff_pkg.sql
-- Descriptive flexfield runtime (0.5).
--
--   How a screen uses it (one shared pattern, no per-screen setup):
--     1. Dynamic Content region, PL/SQL body:
--          return xxfnd_dff_pkg.render('XXCMP_PARTIES', :P21_PARTY_ID,
--                                      p_context_code => :P21_DFF_CONTEXT);
--     2. Hidden page item Pnn_DFF_JSON; the application's dff.js copies the
--        field values into it when the page is submitted.
--     3. Validation (function body returning error text):
--          return xxfnd_dff_pkg.validate('XXCMP_PARTIES', :P21_DFF_JSON, :P21_DFF_CONTEXT);
--     4. Process after the form's DML process:
--          xxfnd_dff_pkg.save('XXCMP_PARTIES', :P21_PARTY_ID, :P21_DFF_JSON, :P21_DFF_CONTEXT);
--
--   Registering a table in XXFND_DF_FLEXFIELDS and enabling contexts and
--   segments is all an administrator does; every screen carrying the region
--   renders the fields straight away.
--
--   Value exchange format (JSON keys are the reserved column names):
--     CHAR       text as entered
--     NUMBER     decimal point '.', no group separators
--     DATE       YYYY-MM-DD
--     TIMESTAMP  YYYY-MM-DDTHH24:MI[:SS]
--
--   TABLE value sets and SQL defaults may reference :CONTEXT_CODE once
--   (dynamic SQL binds by position).
--------------------------------------------------------------------------------

create or replace package xxfnd_dff_pkg authid definer as

    -- Flexfield code registered for a table, or null.
    function flexfield_for_table(p_table_name in varchar2) return varchar2;

    -- Context the row uses: reference column, user choice, stored value, default.
    function derive_context(p_table_name      in varchar2,
                            p_pk_value        in varchar2,
                            p_context_code    in varchar2 default null,
                            p_reference_value in varchar2 default null) return varchar2;

    -- HTML for the shared DFF region. Empty string when the table has no
    -- enabled DFF or no displayed segment.
    function render(p_table_name      in varchar2,
                    p_pk_value        in varchar2,
                    p_context_code    in varchar2 default null,
                    p_reference_value in varchar2 default null,
                    p_read_only       in varchar2 default 'N') return clob;

    -- First error found, or null. Used as an APEX validation.
    function validate(p_table_name      in varchar2,
                      p_values_json     in clob,
                      p_context_code    in varchar2 default null,
                      p_pk_value        in varchar2 default null,
                      p_reference_value in varchar2 default null) return varchar2;

    -- Writes ATTRIBUTE_CATEGORY and every configured segment column. Columns
    -- of contexts other than the one in use are cleared, as in EBS.
    procedure save(p_table_name      in varchar2,
                   p_pk_value        in varchar2,
                   p_values_json     in clob,
                   p_context_code    in varchar2 default null,
                   p_reference_value in varchar2 default null);

    -- SQL typed in by administrators (a TABLE value set's query, a segment's SQL default) runs with the
    -- schema's rights, so it must be a query: SELECT or WITH, one statement, :CONTEXT_CODE as the only bind.
    -- P_KIND = VALUE_SET (columns RETURN_VALUE and DISPLAY_VALUE) or DEFAULT (one value).
    -- P_PARSE = Y also parses it (setup screens, on save); the runtime re-checks without parsing.
    -- Returns the problem, or null when the SQL is acceptable.
    function admin_sql_error(p_sql in clob, p_kind in varchar2, p_parse in varchar2 default 'Y') return varchar2;

    -- Values for a segment's list: RETURN_VALUE, DISPLAY_VALUE, PARENT_VALUE.
    -- Also used by the setup screens to preview a value set.
    function value_list(p_value_set_code in varchar2,
                        p_context_code   in varchar2 default null)
        return sys_refcursor;


    -- Release 80 (from XXFND_DFF_SETUP_PKG): setup checks, called from the XXFND_DF_FLEXFIELDS / XXFND_DF_SEGMENTS
    -- triggers.
    procedure check_segment(p_dff_code      in varchar2,
                            p_context_code  in varchar2,
                            p_segment_code  in varchar2,
                            p_column_name   in varchar2,
                            p_value_set     in varchar2);
    procedure check_flexfield(p_table_name in varchar2, p_pk_column in varchar2,
                              p_context_column in varchar2, p_reference_column in varchar2);
    -- Creates or replaces <TABLE>_DFV: one readable column per segment, for reports and integrations (EBS "DFV"
    -- views). Release 80: GENERATE_ALL_DFV_VIEWS covers this schema's own tables only.
    procedure generate_dfv_view(p_dff_code in varchar2);
    procedure generate_all_dfv_views;
    -- Release 80: the flexfield's name (English) and its protected GLOBAL context, saved from page 153.
    procedure save_flexfield_name(p_dff_code in varchar2, p_flexfield_name in varchar2);
end xxfnd_dff_pkg;
/
