create or replace package body xxcus.xxfnd_dff_setup_pkg as

    function column_family (
        p_column_name in varchar2
    ) return varchar2 is
    begin
        return
            case
                when regexp_like ( p_column_name,
                                   '^ATTRIBUTE_NUMBER' ) then
                    'NUMBER'
                when regexp_like ( p_column_name,
                                   '^ATTRIBUTE_DATE' ) then
                    'DATE'
                when regexp_like ( p_column_name,
                                   '^ATTRIBUTE_TIMESTAMP' ) then
                    'TIMESTAMP'
                when regexp_like ( p_column_name,
                                   '^ATTRIBUTE[0-9]' ) then
                    'CHAR'
            end;
    end column_family;

    -- Segments shown for a context: GLOBAL first, then the context's own.

    ----------------------------------------------------------------------------
    -- setup checks
    ----------------------------------------------------------------------------
    procedure check_flexfield (
        p_table_name       in varchar2,
        p_pk_column        in varchar2,
        p_context_column   in varchar2,
        p_reference_column in varchar2
    ) is

        l_count pls_integer;

        procedure need (
            p_column in varchar2
        ) is
        begin
            if p_column is null then
                return;
            end if;
            select
                count(*)
            into l_count
            from
                user_tab_columns
            where
                    table_name = upper(p_table_name)
                and column_name = upper(p_column);

            if l_count = 0 then
                raise_application_error(-20210, 'Table '
                                                || p_table_name
                                                || ' has no column '
                                                || p_column
                                                || '.');
            end if;

        end need;

    begin
        need(p_pk_column);
        need(p_context_column);
        need(p_reference_column);
        need('ATTRIBUTE1');   -- proves the DFF column block is present
    end check_flexfield;

    procedure check_segment (
        p_dff_code     in varchar2,
        p_context_code in varchar2,
        p_segment_code in varchar2,
        p_column_name  in varchar2,
        p_value_set    in varchar2
    ) is

        l_format xxfnd_value_sets.format_type%type;
        l_table  xxfnd_df_flexfields.table_name%type;
        l_global varchar2(1);
        l_count  pls_integer;
    begin
        select
            format_type
        into l_format
        from
            xxfnd_value_sets
        where
            value_set_code = p_value_set;

        if column_family(p_column_name) <> l_format then
            raise_application_error(-20211, 'Segment '
                                            || p_segment_code
                                            || ': a '
                                            || l_format
                                            || ' value set needs a '
                                            || l_format
                                            || ' column, not '
                                            || p_column_name
                                            || '.');

        end if;

        select
            table_name
        into l_table
        from
            xxfnd_df_flexfields
        where
            descriptive_flexfield_code = p_dff_code;

        select
            count(*)
        into l_count
        from
            user_tab_columns
        where
                table_name = l_table
            and column_name = p_column_name;

        if l_count = 0 then
            raise_application_error(-20212, 'Table '
                                            || l_table
                                            || ' has no column '
                                            || p_column_name
                                            || '.');
        end if;

        -- A GLOBAL column is on every row, so no context may reuse it, and vice versa.
        select
            global_flag
        into l_global
        from
            xxfnd_df_contexts
        where
                descriptive_flexfield_code = p_dff_code
            and context_code = p_context_code;

        select
            count(*)
        into l_count
        from
                 xxfnd_df_segments s
            join xxfnd_df_contexts c on c.descriptive_flexfield_code = s.descriptive_flexfield_code
                                        and c.context_code = s.context_code
        where
                s.descriptive_flexfield_code = p_dff_code
            and s.column_name = p_column_name
            and s.context_code <> p_context_code
            and ( l_global = 'Y'
                  or c.global_flag = 'Y' );

        if l_count > 0 then
            raise_application_error(-20213, 'Column '
                                            || p_column_name
                                            || ' is already used by a global segment or, for a global segment, by another context.');
        end if;

    end check_segment;

    ----------------------------------------------------------------------------
    -- DFV views
    ----------------------------------------------------------------------------
    procedure generate_dfv_view (
        p_dff_code in varchar2
    ) is
        l_ff   xxfnd_df_flexfields%rowtype;
        l_sql  clob;
        l_name varchar2(128);
    begin
        select
            *
        into l_ff
        from
            xxfnd_df_flexfields
        where
            descriptive_flexfield_code = p_dff_code;

        l_sql := 'create or replace view '
                 || dbms_assert.simple_sql_name(substr(l_ff.table_name, 1, 124) || '_DFV')
                 || ' as select t.'
                 || dbms_assert.simple_sql_name(l_ff.pk_column_name)
                 || ', t.'
                 || dbms_assert.simple_sql_name(l_ff.context_column_name)
                 || ' context_code';

        for s in (
            select
                s.segment_code,
                s.column_name,
                s.context_code,
                c.global_flag,
                count(*)
                over(partition by s.segment_code) same_code_count
            from
                     xxfnd_df_segments s
                join xxfnd_df_contexts c on c.descriptive_flexfield_code = s.descriptive_flexfield_code
                                            and c.context_code = s.context_code
            where
                    s.descriptive_flexfield_code = p_dff_code
                and s.enabled_flag = 'Y'
            order by
                c.global_flag desc,
                s.context_code,
                s.sequence_number
        ) loop
            -- Segment code alone when unique across contexts, else CONTEXT_SEGMENT.
            l_name := upper(substr(
                case
                    when s.same_code_count = 1 then
                        s.segment_code
                    else
                        s.context_code
                        || '_'
                        || s.segment_code
                end, 1, 128));

            l_name := dbms_assert.enquote_name(l_name,
                                               capitalize => false);
            if s.global_flag = 'Y' then
                l_sql := l_sql
                         || ', t.'
                         || dbms_assert.simple_sql_name(s.column_name)
                         || ' '
                         || l_name;
            else
                l_sql := l_sql
                         || ', case when t.'
                         || dbms_assert.simple_sql_name(l_ff.context_column_name)
                         || ' = '
                         || dbms_assert.enquote_literal(replace(s.context_code, '''', ''''''))
                         || ' then t.'
                         || dbms_assert.simple_sql_name(s.column_name)
                         || ' end '
                         || l_name;
            end if;

        end loop;

        l_sql := l_sql
                 || ' from '
                 || dbms_assert.simple_sql_name(l_ff.table_name)
                 || ' t';

        execute immediate l_sql;
    end generate_dfv_view;

    procedure generate_all_dfv_views is
    begin
        for f in (
            select
                descriptive_flexfield_code
            from
                xxfnd_df_flexfields
            where
                enabled_flag = 'Y'
        ) loop
            generate_dfv_view(f.descriptive_flexfield_code);
        end loop;
    end generate_all_dfv_views;

end xxfnd_dff_setup_pkg;
/


-- sqlcl_snapshot {"hash":"0864d6e100ca15029d97740f76334856b8402c96","type":"PACKAGE_BODY","name":"XXFND_DFF_SETUP_PKG","schemaName":"XXCUS","sxml":""}