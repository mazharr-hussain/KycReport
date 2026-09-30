create or replace editionable trigger xxcus.xxfnd_sod_rules_aud after
    insert or update or delete on xxcus.xxfnd_sod_rules
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXFND_SOD_RULES',
                                   to_char(:new.sod_rule_id),
                                   'I');
        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXFND_SOD_RULES',
                                   to_char(:old.sod_rule_id),
                                   'D');
        return;
    end if;

    l_pk := to_char(:new.sod_rule_id);
    if ( :old.sod_rule_id <> :new.sod_rule_id )
    or (
        :old.sod_rule_id is null
        and :new.sod_rule_id is not null
    )
    or (
        :old.sod_rule_id is not null
        and :new.sod_rule_id is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_SOD_RULES',
                                   l_pk,
                                   'U',
                                   'SOD_RULE_ID',
                                   to_char(:old.sod_rule_id,
                                           'TM9'),
                                   to_char(:new.sod_rule_id,
                                           'TM9'));
    end if;

    if ( :old.role_code_1 <> :new.role_code_1 )
    or (
        :old.role_code_1 is null
        and :new.role_code_1 is not null
    )
    or (
        :old.role_code_1 is not null
        and :new.role_code_1 is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_SOD_RULES',
                                   l_pk,
                                   'U',
                                   'ROLE_CODE_1',
                                   :old.role_code_1,
                                   :new.role_code_1);
    end if;

    if ( :old.role_code_2 <> :new.role_code_2 )
    or (
        :old.role_code_2 is null
        and :new.role_code_2 is not null
    )
    or (
        :old.role_code_2 is not null
        and :new.role_code_2 is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_SOD_RULES',
                                   l_pk,
                                   'U',
                                   'ROLE_CODE_2',
                                   :old.role_code_2,
                                   :new.role_code_2);
    end if;

    if ( :old.conflict_scope <> :new.conflict_scope )
    or (
        :old.conflict_scope is null
        and :new.conflict_scope is not null
    )
    or (
        :old.conflict_scope is not null
        and :new.conflict_scope is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_SOD_RULES',
                                   l_pk,
                                   'U',
                                   'CONFLICT_SCOPE',
                                   :old.conflict_scope,
                                   :new.conflict_scope);
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
        xxfnd_audit_pkg.log_change('XXFND_SOD_RULES',
                                   l_pk,
                                   'U',
                                   'DESCRIPTION',
                                   :old.description,
                                   :new.description);
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
        xxfnd_audit_pkg.log_change('XXFND_SOD_RULES',
                                   l_pk,
                                   'U',
                                   'ENABLED_FLAG',
                                   :old.enabled_flag,
                                   :new.enabled_flag);
    end if;

end;
/

alter trigger xxcus.xxfnd_sod_rules_aud enable;


-- sqlcl_snapshot {"hash":"5a47938c4678efc971a769229c09dc46e063a5d0","type":"TRIGGER","name":"XXFND_SOD_RULES_AUD","schemaName":"XXCUS","sxml":""}