create or replace editionable trigger xxcus.xxcmp_attachment_rules_aud after
    insert or update or delete on xxcus.xxcmp_attachment_rules
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXCMP_ATTACHMENT_RULES',
                                   to_char(:new.attachment_rule_id),
                                   'I');
        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXCMP_ATTACHMENT_RULES',
                                   to_char(:old.attachment_rule_id),
                                   'D');
        return;
    end if;

    l_pk := to_char(:new.attachment_rule_id);
    if ( :old.attachment_rule_id <> :new.attachment_rule_id )
    or (
        :old.attachment_rule_id is null
        and :new.attachment_rule_id is not null
    )
    or (
        :old.attachment_rule_id is not null
        and :new.attachment_rule_id is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_ATTACHMENT_RULES',
                                   l_pk,
                                   'U',
                                   'ATTACHMENT_RULE_ID',
                                   to_char(:old.attachment_rule_id,
                                           'TM9'),
                                   to_char(:new.attachment_rule_id,
                                           'TM9'));
    end if;

    if ( :old.entity_name <> :new.entity_name )
    or (
        :old.entity_name is null
        and :new.entity_name is not null
    )
    or (
        :old.entity_name is not null
        and :new.entity_name is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_ATTACHMENT_RULES',
                                   l_pk,
                                   'U',
                                   'ENTITY_NAME',
                                   :old.entity_name,
                                   :new.entity_name);
    end if;

    if ( :old.category_code <> :new.category_code )
    or (
        :old.category_code is null
        and :new.category_code is not null
    )
    or (
        :old.category_code is not null
        and :new.category_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_ATTACHMENT_RULES',
                                   l_pk,
                                   'U',
                                   'CATEGORY_CODE',
                                   :old.category_code,
                                   :new.category_code);
    end if;

    if ( :old.jurisdiction <> :new.jurisdiction )
    or (
        :old.jurisdiction is null
        and :new.jurisdiction is not null
    )
    or (
        :old.jurisdiction is not null
        and :new.jurisdiction is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_ATTACHMENT_RULES',
                                   l_pk,
                                   'U',
                                   'JURISDICTION',
                                   :old.jurisdiction,
                                   :new.jurisdiction);
    end if;

    if ( :old.entity_type <> :new.entity_type )
    or (
        :old.entity_type is null
        and :new.entity_type is not null
    )
    or (
        :old.entity_type is not null
        and :new.entity_type is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_ATTACHMENT_RULES',
                                   l_pk,
                                   'U',
                                   'ENTITY_TYPE',
                                   :old.entity_type,
                                   :new.entity_type);
    end if;

    if ( :old.mandatory_flag <> :new.mandatory_flag )
    or (
        :old.mandatory_flag is null
        and :new.mandatory_flag is not null
    )
    or (
        :old.mandatory_flag is not null
        and :new.mandatory_flag is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_ATTACHMENT_RULES',
                                   l_pk,
                                   'U',
                                   'MANDATORY_FLAG',
                                   :old.mandatory_flag,
                                   :new.mandatory_flag);
    end if;

    if ( :old.priority <> :new.priority )
    or (
        :old.priority is null
        and :new.priority is not null
    )
    or (
        :old.priority is not null
        and :new.priority is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_ATTACHMENT_RULES',
                                   l_pk,
                                   'U',
                                   'PRIORITY',
                                   to_char(:old.priority,
                                           'TM9'),
                                   to_char(:new.priority,
                                           'TM9'));
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
        xxfnd_audit_pkg.log_change('XXCMP_ATTACHMENT_RULES',
                                   l_pk,
                                   'U',
                                   'ENABLED_FLAG',
                                   :old.enabled_flag,
                                   :new.enabled_flag);
    end if;

    if ( :old.approval_status <> :new.approval_status )
    or (
        :old.approval_status is null
        and :new.approval_status is not null
    )
    or (
        :old.approval_status is not null
        and :new.approval_status is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_ATTACHMENT_RULES',
                                   l_pk,
                                   'U',
                                   'APPROVAL_STATUS',
                                   :old.approval_status,
                                   :new.approval_status);
    end if;

    if ( :old.approved_by <> :new.approved_by )
    or (
        :old.approved_by is null
        and :new.approved_by is not null
    )
    or (
        :old.approved_by is not null
        and :new.approved_by is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_ATTACHMENT_RULES',
                                   l_pk,
                                   'U',
                                   'APPROVED_BY',
                                   :old.approved_by,
                                   :new.approved_by);
    end if;

    if ( :old.approved_date <> :new.approved_date )
    or (
        :old.approved_date is null
        and :new.approved_date is not null
    )
    or (
        :old.approved_date is not null
        and :new.approved_date is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_ATTACHMENT_RULES',
                                   l_pk,
                                   'U',
                                   'APPROVED_DATE',
                                   to_char(:old.approved_date,
                                           'YYYY-MM-DD HH24:MI:SS.FF'),
                                   to_char(:new.approved_date,
                                           'YYYY-MM-DD HH24:MI:SS.FF'));
    end if;

end;
/

alter trigger xxcus.xxcmp_attachment_rules_aud enable;


-- sqlcl_snapshot {"hash":"996dde4cb9776f1813027515f1979cb0afa61df5","type":"TRIGGER","name":"XXCMP_ATTACHMENT_RULES_AUD","schemaName":"XXCUS","sxml":""}