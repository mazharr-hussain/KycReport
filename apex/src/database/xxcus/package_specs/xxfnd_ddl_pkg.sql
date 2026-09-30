create or replace package xxcus.xxfnd_ddl_pkg authid current_user as
    -- True once MARK_RELEASE has recorded this release in this schema.
    function release_applied (
        p_release_code in varchar2
    ) return boolean;

    procedure mark_release (
        p_release_code in varchar2,
        p_description  in varchar2
    );
    -- ALTER TABLE ... ADD (<column> <definition>) only when the column is missing.
    procedure add_column (
        p_table_name  in varchar2,
        p_column_name in varchar2,
        p_definition  in varchar2
    );

end xxfnd_ddl_pkg;
/


-- sqlcl_snapshot {"hash":"6940e3e57dab7ad40f56676af4e868eaeb8a6dae","type":"PACKAGE_SPEC","name":"XXFND_DDL_PKG","schemaName":"XXCUS","sxml":""}