create or replace package xxcus.xxfnd_config_approval_pkg authid definer as
    -- Submits a change for approval and creates its CONFIG_CHANGE approval task (one open
    -- task per change). P_TABLE_NAME/P_KEY: XXCMP_ATTACHMENT_RULES / rule id,
    -- XXFND_INTEGRATION_PURPOSES / purpose code, or XXCMP_QUESTIONS / question id for all
    -- draft or rejected answer options of that question.
    procedure request (
        p_table_name in varchar2,
        p_key        in varchar2
    );
    -- Task actions (the approver's session): apply or reject every row of the change.
    procedure approve (
        p_detail_pk in varchar2
    );

    procedure reject (
        p_detail_pk in varchar2,
        p_reason    in varchar2
    );
    -- Y while the change behind a task is still waiting for approval.
    function is_pending (
        p_detail_pk in varchar2
    ) return varchar2;

end xxfnd_config_approval_pkg;
/


-- sqlcl_snapshot {"hash":"fbf887081deb5b0de1cf8fe5e37535be9356cf5e","type":"PACKAGE_SPEC","name":"XXFND_CONFIG_APPROVAL_PKG","schemaName":"XXCUS","sxml":""}