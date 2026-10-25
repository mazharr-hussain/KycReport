--------------------------------------------------------------------------------
-- XXFND_FI_RUN_PKG (release 107, Fusion Objects). COMMON only (XXFUSION).
--   The runtime of the onboarded objects (automation "Fusion Objects run" calls RUN_DUE):
--   - BICC replica: the object's BICC job is started from APEX (BICC REST, through the Fusion server and credential),
--     its status polled; when done, the extract files written to Object Storage (the object's OBJECT_STORAGE server,
--     bucket and prefix) are read with DBMS_CLOUD, unzipped (APEX_ZIP), parsed (APEX_DATA_PARSER) into the staging
--     table and merged into the replica; the primary-key extract (files with "pecsv") removes deleted rows.
--     DBMS_CLOUD is called through dynamic SQL: the package compiles without it and a run says what is missing.
--   - REST replica: paged pulls of the selected fields (incremental by the last-update attribute when there is one)
--     into staging, then merged; a full pull removes the rows Fusion no longer returns.
--   - Real-time and push: FETCH and PUSH, the shared REST calls the applications use.
--   Every run is logged (XXFND_FI_RUNS) and the object's last sync updated; failures alert the administrators.
--------------------------------------------------------------------------------
create or replace package xxfnd_fi_run_pkg authid definer as
    -- BICC job paths (relative to XXFND_FI_META_PKG.C_BICC_ROOT); {job} / {request} are replaced.
    c_bicc_run    constant varchar2(200) := '/jobs/{job}/schedules';
    c_bicc_status constant varchar2(200) := '/jobs/{job}/schedules/{request}';
    c_page_size   constant pls_integer   := 500;

    -- The automation's entry: every due ACTIVE replica object, then the daily metadata check.
    procedure run_due;
    -- One object now (Run now on the Object Detail screen); FUSION_OBJECTS - Manage in an APEX session.
    procedure run_object(p_object_id in number);
    -- Text from a file or JSON to a timestamp (the formats BICC and Fusion REST use); null when not a date.
    function to_ts(p_text in varchar2) return timestamp;
    -- Real-time (FETCH_ROWS): a GET on the object's REST resource (P_QUERY: q=..., fields=..., limit=...).
    function fetch_rows(p_object_id in number, p_query in varchar2 default null) return clob;
    -- Push: POST (create) or PATCH / DELETE of one row (P_KEY) of the object's REST resource.
    function push(p_object_id in number, p_payload in clob, p_method in varchar2 default 'POST',
                  p_key in varchar2 default null) return clob;
end xxfnd_fi_run_pkg;
/
