create or replace editionable trigger xxcus.xxfnd_df_flexfields_chk before
    insert or update of table_name, pk_column_name, context_column_name, context_reference_column on xxcus.xxfnd_df_flexfields
    for each row
begin
    :new.table_name := upper(:new.table_name);
    :new.pk_column_name := upper(:new.pk_column_name);
    :new.context_column_name := upper(:new.context_column_name);
    :new.context_reference_column := upper(:new.context_reference_column);
    xxfnd_dff_setup_pkg.check_flexfield(:new.table_name,
                                        :new.pk_column_name,
                                        :new.context_column_name,
                                        :new.context_reference_column);

end;
/

alter trigger xxcus.xxfnd_df_flexfields_chk enable;


-- sqlcl_snapshot {"hash":"00c2ebdd57737e8e690540e0da150cf894fc028c","type":"TRIGGER","name":"XXFND_DF_FLEXFIELDS_CHK","schemaName":"XXCUS","sxml":""}