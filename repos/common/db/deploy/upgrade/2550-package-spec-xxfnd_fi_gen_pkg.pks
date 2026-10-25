--------------------------------------------------------------------------------
-- XXFND_FI_GEN_PKG (release 107, Fusion Objects). COMMON only (XXFUSION).
--   The generators, run when an administrator activates an object or a drift is applied:
--   - the replica table XXFI_<code> (selected attributes, typed, primary key) and its staging table XXFI_<code>_STG
--     (every column as text, as files and JSON deliver it) - created when missing, then only missing columns added and
--     lengths widened (idempotent, through XXFND_DDL_PKG);
--   - the versioned business view XXFI_<code>_V<n> (selected attributes, business names as column comments) and the
--     stable business view XXFI_<code>_V the applications read, repointed to the applied version;
--   - the BICC datastore configuration (the selected columns, PUT /meta/datastores) and the BICC job of the object;
--   - the REST query of the object (fields, onlyData, paging).
--------------------------------------------------------------------------------
create or replace package xxfnd_fi_gen_pkg authid definer as
    -- The name of a generated object of the object (P_SUFFIX: null = replica table, _STG, _V, _V<n>).
    function object_name(p_object_id in number, p_suffix in varchar2 default null) return varchar2;
    -- The Oracle column type of an attribute (from the Fusion data type, length and scale).
    function sql_type(p_data_type in varchar2, p_length in number, p_scale in number) return varchar2;
    -- The selected attributes as JSON (the metadata of a version) and its SHA-256 hash.
    function metadata_json(p_object_id in number) return clob;
    function metadata_hash(p_object_id in number) return varchar2;
    -- Creates or completes the replica and staging tables of the object.
    procedure ensure_tables(p_object_id in number);
    -- A new version when the selected metadata changed: its view XXFI_<code>_V<n>, the stable view repointed to it.
    -- Returns the applied version number.
    function apply_version(p_object_id in number) return number;
    -- REST: the query string of a pull (selected fields, only data, paging; P_SINCE: changes after this date).
    function rest_query(p_object_id in number, p_offset in number, p_limit in number default 500,
                        p_since in timestamp default null) return varchar2;
    -- BICC: the datastore configured with the selected columns, and the object's BICC job (created when missing).
    procedure bicc_configure(p_object_id in number);
end xxfnd_fi_gen_pkg;
/
