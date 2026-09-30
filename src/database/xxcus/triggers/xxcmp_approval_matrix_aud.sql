create or replace editionable trigger xxcus.xxcmp_approval_matrix_aud after
    insert or update or delete on xxcus.xxcmp_approval_matrix
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXCMP_APPROVAL_MATRIX',
                                   to_char(:new.risk_tier),
                                   'I');
        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXCMP_APPROVAL_MATRIX',
                                   to_char(:old.risk_tier),
                                   'D');
        return;
    end if;

    l_pk := to_char(:new.risk_tier);
    if ( :old.risk_tier <> :new.risk_tier )
    or (
        :old.risk_tier is null
        and :new.risk_tier is not null
    )
    or (
        :old.risk_tier is not null
        and :new.risk_tier is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_APPROVAL_MATRIX',
                                   l_pk,
                                   'U',
                                   'RISK_TIER',
                                   :old.risk_tier,
                                   :new.risk_tier);
    end if;

    if ( :old.required_levels <> :new.required_levels )
    or (
        :old.required_levels is null
        and :new.required_levels is not null
    )
    or (
        :old.required_levels is not null
        and :new.required_levels is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_APPROVAL_MATRIX',
                                   l_pk,
                                   'U',
                                   'REQUIRED_LEVELS',
                                   to_char(:old.required_levels,
                                           'TM9'),
                                   to_char(:new.required_levels,
                                           'TM9'));
    end if;

    if ( :old.level1_role_code <> :new.level1_role_code )
    or (
        :old.level1_role_code is null
        and :new.level1_role_code is not null
    )
    or (
        :old.level1_role_code is not null
        and :new.level1_role_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_APPROVAL_MATRIX',
                                   l_pk,
                                   'U',
                                   'LEVEL1_ROLE_CODE',
                                   :old.level1_role_code,
                                   :new.level1_role_code);
    end if;

    if ( :old.level2_role_code <> :new.level2_role_code )
    or (
        :old.level2_role_code is null
        and :new.level2_role_code is not null
    )
    or (
        :old.level2_role_code is not null
        and :new.level2_role_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_APPROVAL_MATRIX',
                                   l_pk,
                                   'U',
                                   'LEVEL2_ROLE_CODE',
                                   :old.level2_role_code,
                                   :new.level2_role_code);
    end if;

    if ( :old.sar_gate_flag <> :new.sar_gate_flag )
    or (
        :old.sar_gate_flag is null
        and :new.sar_gate_flag is not null
    )
    or (
        :old.sar_gate_flag is not null
        and :new.sar_gate_flag is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_APPROVAL_MATRIX',
                                   l_pk,
                                   'U',
                                   'SAR_GATE_FLAG',
                                   :old.sar_gate_flag,
                                   :new.sar_gate_flag);
    end if;

end;
/

alter trigger xxcus.xxcmp_approval_matrix_aud enable;


-- sqlcl_snapshot {"hash":"ea7c478b84d4e16bd62527da302354c5fd1d36ce","type":"TRIGGER","name":"XXCMP_APPROVAL_MATRIX_AUD","schemaName":"XXCUS","sxml":""}