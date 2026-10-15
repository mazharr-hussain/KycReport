--------------------------------------------------------------------------------
-- 06a_xxfnd_dff_pkg.sql
-- Descriptive flexfield setup (0.5): the integrity triggers on flexfield and segment definitions.
-- Release 80: the checks and the <TABLE>_DFV reporting views are in XXFND_DFF_PKG (10/11).
--------------------------------------------------------------------------------

-- release 80: the setup checks and the DFV views are in XXFND_DFF_PKG (10/11); XXFND_DFF_SETUP_PKG is dropped below

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
    xxfnd_dff_pkg.check_flexfield(:new.table_name, :new.pk_column_name,
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
            xxfnd_dff_pkg.check_segment(g_keys(i).dff, g_keys(i).ctx, g_keys(i).seg,
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

-- release 80: the setup package merged into XXFND_DFF_PKG (old callers break on purpose: no wrappers); the reporting
-- views this schema created over other schemas' tables leave it (each application creates its own)
begin
    xxfnd_ddl_pkg.drop_object('XXFND_DFF_SETUP_PKG', 'PACKAGE');
    for v in (select v.view_name from user_views v
               join xxfnd_df_flexfields f on f.table_name || '_DFV' = v.view_name
              where not exists (select 1 from user_tables t where t.table_name = f.table_name)) loop
        xxfnd_ddl_pkg.drop_object(v.view_name, 'VIEW');
    end loop;
end;
/
