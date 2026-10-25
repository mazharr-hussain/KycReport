
create or replace package body xxfnd_audit_pkg as
    g_reason varchar2(1000);

    procedure set_change_reason(p_reason in varchar2) is
    begin
        g_reason := substr(p_reason, 1, 1000);
    end set_change_reason;

    function get_change_reason return varchar2 is
    begin
        return g_reason;
    end get_change_reason;

    procedure clear_change_reason is
    begin
        g_reason := null;
    end clear_change_reason;

    procedure log_change(p_table_name in varchar2,
                         p_pk_value   in varchar2,
                         p_action     in varchar2,
                         p_column     in varchar2 default null,
                         p_old_value  in varchar2 default null,
                         p_new_value  in varchar2 default null) is
    begin
        insert into xxfnd_audit_log
            (table_name, pk_value, action_code, column_name, old_value, new_value, change_reason, changed_by)
        values
            (p_table_name, p_pk_value, p_action, p_column,
             substr(p_old_value, 1, 4000), substr(p_new_value, 1, 4000),
             g_reason, xxfnd_util_pkg.current_user);
    end log_change;

    procedure create_audit_trigger(p_table_name in varchar2) is
    begin
        xxfnd_schema_pkg.create_audit_trigger(p_table_name);
    end create_audit_trigger;

    procedure create_config_audit_triggers is
    begin
        xxfnd_schema_pkg.create_config_audit_triggers;
    end create_config_audit_triggers;

end xxfnd_audit_pkg;
/
