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
