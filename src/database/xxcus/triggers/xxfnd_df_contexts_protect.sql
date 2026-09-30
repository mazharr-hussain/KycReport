create or replace editionable trigger xxcus.xxfnd_df_contexts_protect before
    update of enabled_flag or delete on xxcus.xxfnd_df_contexts
    for each row
begin
    if
        :old.protected_flag = 'Y'
        and xxfnd_util_pkg.in_apex_session
        and ( deleting
        or :new.enabled_flag = 'N' )
    then
        raise_application_error(-20214,
                                'Context '
                                || :old.context_code
                                || ' is system-defined and cannot be disabled or deleted.');
    end if;
end;
/

alter trigger xxcus.xxfnd_df_contexts_protect enable;


-- sqlcl_snapshot {"hash":"d85597dddbde330e4411b51060ba2709fb02c964","type":"TRIGGER","name":"XXFND_DF_CONTEXTS_PROTECT","schemaName":"XXCUS","sxml":""}