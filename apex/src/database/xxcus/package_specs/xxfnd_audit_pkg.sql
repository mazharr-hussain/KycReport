create or replace package xxcus.xxfnd_audit_pkg authid definer as
    -- Set before a save to record why a configuration value changed (FR-36).
    procedure set_change_reason (
        p_reason in varchar2
    );

    function get_change_reason return varchar2;

    procedure clear_change_reason;

    procedure log_change (
        p_table_name in varchar2,
        p_pk_value   in varchar2,
        p_action     in varchar2,
        p_column     in varchar2 default null,
        p_old_value  in varchar2 default null,
        p_new_value  in varchar2 default null
    );

    -- Generates an AFTER INSERT/UPDATE/DELETE row trigger that writes one row
    -- per changed column (updates) or one row per record (inserts, deletes).
    -- WHO columns and LOB columns are skipped.
    procedure create_audit_trigger (
        p_table_name in varchar2
    );

    procedure create_config_audit_triggers;

end xxfnd_audit_pkg;
/


-- sqlcl_snapshot {"hash":"190874c24b7ce418b589a38cb52045bf8478e2d3","type":"PACKAGE_SPEC","name":"XXFND_AUDIT_PKG","schemaName":"XXCUS","sxml":""}