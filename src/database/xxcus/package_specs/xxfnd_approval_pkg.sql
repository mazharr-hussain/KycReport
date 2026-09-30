create or replace package xxcus.xxfnd_approval_pkg authid definer as
    -- Tables under maker-checker control.
    function is_controlled (
        p_table_name in varchar2
    ) return boolean;

    procedure submit (
        p_table_name in varchar2,
        p_pk_value   in varchar2
    );

    procedure approve (
        p_table_name in varchar2,
        p_pk_value   in varchar2
    );

    procedure reject (
        p_table_name in varchar2,
        p_pk_value   in varchar2,
        p_reason     in varchar2
    );

    -- Called from the BEFORE UPDATE/INSERT trigger on each controlled table.
    -- Editing an approved row sends it back for approval; approving your own
    -- change is refused.
    procedure apply_rules (
        p_inserting        in boolean,
        p_old_status       in varchar2,
        p_new_status       in out varchar2,
        p_old_last_updated in varchar2,
        p_approved_by      in out varchar2,
        p_approved_date    in out timestamp
    );

end xxfnd_approval_pkg;
/


-- sqlcl_snapshot {"hash":"729c61a8e652cc577d0ed9011c3ebc87babfbeab","type":"PACKAGE_SPEC","name":"XXFND_APPROVAL_PKG","schemaName":"XXCUS","sxml":""}