--------------------------------------------------------------------------------
-- 06a_xxfnd_dff_setup_pkg.sql
-- Descriptive flexfield setup (0.5): integrity checks on flexfield and segment
-- definitions, and the <TABLE>_DFV reporting views. The runtime (render,
-- validate, save) is XXFND_DFF_PKG.
--------------------------------------------------------------------------------

create or replace package xxfnd_dff_setup_pkg authid definer as

    -- Setup checks, called from the XXFND_DF_SEGMENTS trigger.
    procedure check_segment(p_dff_code      in varchar2,
                            p_context_code  in varchar2,
                            p_segment_code  in varchar2,
                            p_column_name   in varchar2,
                            p_value_set     in varchar2);
    procedure check_flexfield(p_table_name in varchar2, p_pk_column in varchar2,
                              p_context_column in varchar2, p_reference_column in varchar2);

    -- Creates or replaces <TABLE>_DFV: one readable column per segment,
    -- for reports and integrations (EBS "DFV" views).
    procedure generate_dfv_view(p_dff_code in varchar2);
    procedure generate_all_dfv_views;
end xxfnd_dff_setup_pkg;
/

create or replace package body xxfnd_dff_setup_pkg as

    function column_family(p_column_name in varchar2) return varchar2 is
    begin
        return case
                 when regexp_like(p_column_name, '^ATTRIBUTE_NUMBER')    then 'NUMBER'
                 when regexp_like(p_column_name, '^ATTRIBUTE_DATE')      then 'DATE'
                 when regexp_like(p_column_name, '^ATTRIBUTE_TIMESTAMP') then 'TIMESTAMP'
                 when regexp_like(p_column_name, '^ATTRIBUTE[0-9]')      then 'CHAR'
               end;
    end column_family;

    -- Segments shown for a context: GLOBAL first, then the context's own.

    ----------------------------------------------------------------------------
    -- setup checks
    ----------------------------------------------------------------------------
    procedure check_flexfield(p_table_name in varchar2, p_pk_column in varchar2,
                              p_context_column in varchar2, p_reference_column in varchar2) is
        l_count pls_integer;
        procedure need(p_column in varchar2) is
        begin
            if p_column is null then
                return;
            end if;
            select count(*) into l_count
              from all_tab_columns   -- release 54: the table may be in an application's schema
             where owner = xxfnd_util_pkg.object_owner(p_table_name)
               and table_name = upper(p_table_name) and column_name = upper(p_column);
            if l_count = 0 then
                raise_application_error(-20210, 'Table ' || p_table_name || ' has no column ' || p_column || '.');
            end if;
        end need;
    begin
        need(p_pk_column);
        need(p_context_column);
        need(p_reference_column);
        need('ATTRIBUTE1');   -- proves the DFF column block is present
    end check_flexfield;

    procedure check_segment(p_dff_code      in varchar2,
                            p_context_code  in varchar2,
                            p_segment_code  in varchar2,
                            p_column_name   in varchar2,
                            p_value_set     in varchar2) is
        l_format  xxfnd_value_sets.format_type%type;
        l_table   xxfnd_df_flexfields.table_name%type;
        l_global  varchar2(1);
        l_count   pls_integer;
    begin
        select format_type into l_format from xxfnd_value_sets where value_set_code = p_value_set;
        if column_family(p_column_name) <> l_format then
            raise_application_error(-20211, 'Segment ' || p_segment_code || ': a ' || l_format
                || ' value set needs a ' || l_format || ' column, not ' || p_column_name || '.');
        end if;

        select table_name into l_table from xxfnd_df_flexfields where descriptive_flexfield_code = p_dff_code;
        select count(*) into l_count
          from all_tab_columns
         where owner = xxfnd_util_pkg.object_owner(l_table) and table_name = l_table and column_name = p_column_name;
        if l_count = 0 then
            raise_application_error(-20212, 'Table ' || l_table || ' has no column ' || p_column_name || '.');
        end if;

        -- A GLOBAL column is on every row, so no context may reuse it, and vice versa.
        select global_flag into l_global
          from xxfnd_df_contexts
         where descriptive_flexfield_code = p_dff_code and context_code = p_context_code;
        select count(*) into l_count
          from xxfnd_df_segments s
          join xxfnd_df_contexts c
            on c.descriptive_flexfield_code = s.descriptive_flexfield_code and c.context_code = s.context_code
         where s.descriptive_flexfield_code = p_dff_code
           and s.column_name = p_column_name
           and s.context_code <> p_context_code
           and (l_global = 'Y' or c.global_flag = 'Y');
        if l_count > 0 then
            raise_application_error(-20213, 'Column ' || p_column_name
                || ' is already used by a global segment or, for a global segment, by another context.');
        end if;
    end check_segment;

    ----------------------------------------------------------------------------
    -- DFV views
    ----------------------------------------------------------------------------
    procedure generate_dfv_view(p_dff_code in varchar2) is
        l_ff   xxfnd_df_flexfields%rowtype;
        l_sql  clob;
        l_name varchar2(128);
    begin
        select * into l_ff from xxfnd_df_flexfields where descriptive_flexfield_code = p_dff_code;
        l_sql := 'create or replace view ' || dbms_assert.simple_sql_name(substr(l_ff.table_name, 1, 124) || '_DFV')
              || ' as select t.' || dbms_assert.simple_sql_name(l_ff.pk_column_name)
              || ', t.' || dbms_assert.simple_sql_name(l_ff.context_column_name) || ' context_code';
        for s in (select s.segment_code, s.column_name, s.context_code, c.global_flag,
                         count(*) over (partition by s.segment_code) same_code_count
                    from xxfnd_df_segments s
                    join xxfnd_df_contexts c
                      on c.descriptive_flexfield_code = s.descriptive_flexfield_code
                     and c.context_code = s.context_code
                   where s.descriptive_flexfield_code = p_dff_code
                     and s.enabled_flag = 'Y'
                   order by c.global_flag desc, s.context_code, s.sequence_number)
        loop
            -- Segment code alone when unique across contexts, else CONTEXT_SEGMENT.
            l_name := upper(substr(case when s.same_code_count = 1 then s.segment_code
                                        else s.context_code || '_' || s.segment_code end, 1, 128));
            l_name := dbms_assert.enquote_name(l_name, capitalize => false);
            if s.global_flag = 'Y' then
                l_sql := l_sql || ', t.' || dbms_assert.simple_sql_name(s.column_name) || ' ' || l_name;
            else
                l_sql := l_sql || ', case when t.' || dbms_assert.simple_sql_name(l_ff.context_column_name)
                      || ' = ' || dbms_assert.enquote_literal(replace(s.context_code, '''', '''''')) || ' then t.'
                      || dbms_assert.simple_sql_name(s.column_name) || ' end ' || l_name;
            end if;
        end loop;
        l_sql := l_sql || ' from ' || xxfnd_util_pkg.qualified(l_ff.table_name) || ' t';
        execute immediate l_sql;
    end generate_dfv_view;

    procedure generate_all_dfv_views is
    begin
        for f in (select descriptive_flexfield_code from xxfnd_df_flexfields where enabled_flag = 'Y') loop
            begin
                generate_dfv_view(f.descriptive_flexfield_code);
            exception
                when others then
                    -- release 54: an application table not (yet) granted to this schema - the view is generated
                    -- on the next run (the application's install grants its tables, KYC script 19a)
                    if sqlcode <> -20130 then
                        raise;
                    end if;
            end;
        end loop;
    end generate_all_dfv_views;

end xxfnd_dff_setup_pkg;
/

--------------------------------------------------------------------------------
-- Setup-integrity triggers
--------------------------------------------------------------------------------
create or replace trigger xxfnd_df_flexfields_chk
    before insert or update of table_name, pk_column_name, context_column_name, context_reference_column
    on xxfnd_df_flexfields
    for each row
begin
    :new.table_name               := upper(:new.table_name);
    :new.pk_column_name           := upper(:new.pk_column_name);
    :new.context_column_name      := upper(:new.context_column_name);
    :new.context_reference_column := upper(:new.context_reference_column);
    xxfnd_dff_setup_pkg.check_flexfield(:new.table_name, :new.pk_column_name,
                                  :new.context_column_name, :new.context_reference_column);
end;
/

-- Compound trigger: the cross-row GLOBAL-column check reads XXFND_DF_SEGMENTS,
-- so it runs after the statement to avoid a mutating-table error.
create or replace trigger xxfnd_df_segments_chk
    for insert or update of column_name, value_set_code, context_code on xxfnd_df_segments
    compound trigger

    type t_key is record (dff varchar2(60), ctx varchar2(80), seg varchar2(30),
                          col varchar2(128), vs varchar2(60));
    type t_keys is table of t_key index by pls_integer;
    g_keys t_keys;

    before each row is
    begin
        :new.column_name := upper(:new.column_name);
        :new.segment_code := upper(:new.segment_code);
    end before each row;

    after each row is
        l_key t_key;
    begin
        l_key.dff := :new.descriptive_flexfield_code;
        l_key.ctx := :new.context_code;
        l_key.seg := :new.segment_code;
        l_key.col := :new.column_name;
        l_key.vs  := :new.value_set_code;
        g_keys(g_keys.count + 1) := l_key;
    end after each row;

    after statement is
    begin
        for i in 1 .. g_keys.count loop
            xxfnd_dff_setup_pkg.check_segment(g_keys(i).dff, g_keys(i).ctx, g_keys(i).seg,
                                        g_keys(i).col, g_keys(i).vs);
        end loop;
        g_keys.delete;
    end after statement;
end xxfnd_df_segments_chk;
/

-- Protected (seeded) contexts cannot be disabled or deleted from the screens.
create or replace trigger xxfnd_df_contexts_protect
    before update of enabled_flag or delete on xxfnd_df_contexts
    for each row
begin
    if :old.protected_flag = 'Y' and xxfnd_util_pkg.in_apex_session
       and (deleting or :new.enabled_flag = 'N') then
        raise_application_error(-20214, 'Context ' || :old.context_code || ' is system-defined and cannot be disabled or deleted.');
    end if;
end;
/
