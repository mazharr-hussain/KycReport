create or replace package body xxcus.xxfnd_ddl_pkg as

    function release_applied (
        p_release_code in varchar2
    ) return boolean is
        l_count pls_integer;
    begin
        select
            count(*)
        into l_count
        from
            xxfnd_schema_releases
        where
            release_code = upper(p_release_code);

        return l_count > 0;
    end release_applied;

    procedure mark_release (
        p_release_code in varchar2,
        p_description  in varchar2
    ) is
    begin
        merge into xxfnd_schema_releases t
        using (
            select
                upper(p_release_code) release_code
            from
                dual
        ) s on ( t.release_code = s.release_code )
        when not matched then
        insert (
            release_code,
            description,
            applied_by )
        values
            ( s.release_code,
              p_description,
              coalesce(
                  sys_context('APEX$SESSION', 'APP_USER'),
                  sys_context('USERENV', 'SESSION_USER')
              ) );

    end mark_release;

    procedure add_column (
        p_table_name  in varchar2,
        p_column_name in varchar2,
        p_definition  in varchar2
    ) is

        l_table  varchar2(128) := upper(dbms_assert.simple_sql_name(p_table_name));
        l_column varchar2(128) := upper(dbms_assert.simple_sql_name(p_column_name));
        l_count  pls_integer;
    begin
        select
            count(*)
        into l_count
        from
            user_tab_columns
        where
                table_name = l_table
            and column_name = l_column;

        if l_count = 0 then
            execute immediate 'alter table '
                              || l_table
                              || ' add ('
                              || l_column
                              || ' '
                              || p_definition
                              || ')';

        end if;

    end add_column;

end xxfnd_ddl_pkg;
/


-- sqlcl_snapshot {"hash":"f66943c7c680b9399baba7f152dee5f177e35acc","type":"PACKAGE_BODY","name":"XXFND_DDL_PKG","schemaName":"XXCUS","sxml":""}