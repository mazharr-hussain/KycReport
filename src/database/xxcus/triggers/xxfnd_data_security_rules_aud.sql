create or replace editionable trigger xxcus.xxfnd_data_security_rules_aud after
    insert or update or delete on xxcus.xxfnd_data_security_rules
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXFND_DATA_SECURITY_RULES',
                                   to_char(:new.rule_id),
                                   'I');
        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXFND_DATA_SECURITY_RULES',
                                   to_char(:old.rule_id),
                                   'D');
        return;
    end if;

    l_pk := to_char(:new.rule_id);
    if ( :old.rule_id <> :new.rule_id )
    or (
        :old.rule_id is null
        and :new.rule_id is not null
    )
    or (
        :old.rule_id is not null
        and :new.rule_id is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DATA_SECURITY_RULES',
                                   l_pk,
                                   'U',
                                   'RULE_ID',
                                   to_char(:old.rule_id,
                                           'TM9'),
                                   to_char(:new.rule_id,
                                           'TM9'));
    end if;

    if ( :old.role_code <> :new.role_code )
    or (
        :old.role_code is null
        and :new.role_code is not null
    )
    or (
        :old.role_code is not null
        and :new.role_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DATA_SECURITY_RULES',
                                   l_pk,
                                   'U',
                                   'ROLE_CODE',
                                   :old.role_code,
                                   :new.role_code);
    end if;

    if ( :old.table_name <> :new.table_name )
    or (
        :old.table_name is null
        and :new.table_name is not null
    )
    or (
        :old.table_name is not null
        and :new.table_name is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DATA_SECURITY_RULES',
                                   l_pk,
                                   'U',
                                   'TABLE_NAME',
                                   :old.table_name,
                                   :new.table_name);
    end if;

    if ( :old.rule_type <> :new.rule_type )
    or (
        :old.rule_type is null
        and :new.rule_type is not null
    )
    or (
        :old.rule_type is not null
        and :new.rule_type is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DATA_SECURITY_RULES',
                                   l_pk,
                                   'U',
                                   'RULE_TYPE',
                                   :old.rule_type,
                                   :new.rule_type);
    end if;

    if ( :old.column_name <> :new.column_name )
    or (
        :old.column_name is null
        and :new.column_name is not null
    )
    or (
        :old.column_name is not null
        and :new.column_name is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DATA_SECURITY_RULES',
                                   l_pk,
                                   'U',
                                   'COLUMN_NAME',
                                   :old.column_name,
                                   :new.column_name);
    end if;

    if ( :old.value_list <> :new.value_list )
    or (
        :old.value_list is null
        and :new.value_list is not null
    )
    or (
        :old.value_list is not null
        and :new.value_list is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DATA_SECURITY_RULES',
                                   l_pk,
                                   'U',
                                   'VALUE_LIST',
                                   :old.value_list,
                                   :new.value_list);
    end if;

    if ( :old.enabled_flag <> :new.enabled_flag )
    or (
        :old.enabled_flag is null
        and :new.enabled_flag is not null
    )
    or (
        :old.enabled_flag is not null
        and :new.enabled_flag is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DATA_SECURITY_RULES',
                                   l_pk,
                                   'U',
                                   'ENABLED_FLAG',
                                   :old.enabled_flag,
                                   :new.enabled_flag);
    end if;

    if ( :old.description <> :new.description )
    or (
        :old.description is null
        and :new.description is not null
    )
    or (
        :old.description is not null
        and :new.description is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DATA_SECURITY_RULES',
                                   l_pk,
                                   'U',
                                   'DESCRIPTION',
                                   :old.description,
                                   :new.description);
    end if;

end;
/

alter trigger xxcus.xxfnd_data_security_rules_aud enable;


-- sqlcl_snapshot {"hash":"b8619c1be04aefa62df861ffedbb5692cf20a9e3","type":"TRIGGER","name":"XXFND_DATA_SECURITY_RULES_AUD","schemaName":"XXCUS","sxml":""}