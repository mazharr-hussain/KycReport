create or replace editionable trigger xxcus.xxcmp_conclusion_templates_aud after
    insert or update or delete on xxcus.xxcmp_conclusion_templates
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXCMP_CONCLUSION_TEMPLATES',
                                   to_char(:new.risk_tier),
                                   'I');
        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXCMP_CONCLUSION_TEMPLATES',
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
        xxfnd_audit_pkg.log_change('XXCMP_CONCLUSION_TEMPLATES',
                                   l_pk,
                                   'U',
                                   'RISK_TIER',
                                   :old.risk_tier,
                                   :new.risk_tier);
    end if;

    if ( :old.template_name <> :new.template_name )
    or (
        :old.template_name is null
        and :new.template_name is not null
    )
    or (
        :old.template_name is not null
        and :new.template_name is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_CONCLUSION_TEMPLATES',
                                   l_pk,
                                   'U',
                                   'TEMPLATE_NAME',
                                   :old.template_name,
                                   :new.template_name);
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
        xxfnd_audit_pkg.log_change('XXCMP_CONCLUSION_TEMPLATES',
                                   l_pk,
                                   'U',
                                   'ENABLED_FLAG',
                                   :old.enabled_flag,
                                   :new.enabled_flag);
    end if;

end;
/

alter trigger xxcus.xxcmp_conclusion_templates_aud enable;


-- sqlcl_snapshot {"hash":"b5fc57208f4018a416d3d83392bf99aff196e557","type":"TRIGGER","name":"XXCMP_CONCLUSION_TEMPLATES_AUD","schemaName":"XXCUS","sxml":""}