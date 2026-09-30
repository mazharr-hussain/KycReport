create or replace editionable trigger xxcus.xxfnd_retention_policies_aud after
    insert or update or delete on xxcus.xxfnd_retention_policies
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXFND_RETENTION_POLICIES',
                                   to_char(:new.retention_policy_id),
                                   'I');
        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXFND_RETENTION_POLICIES',
                                   to_char(:old.retention_policy_id),
                                   'D');
        return;
    end if;

    l_pk := to_char(:new.retention_policy_id);
    if ( :old.retention_policy_id <> :new.retention_policy_id )
    or (
        :old.retention_policy_id is null
        and :new.retention_policy_id is not null
    )
    or (
        :old.retention_policy_id is not null
        and :new.retention_policy_id is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_RETENTION_POLICIES',
                                   l_pk,
                                   'U',
                                   'RETENTION_POLICY_ID',
                                   to_char(:old.retention_policy_id,
                                           'TM9'),
                                   to_char(:new.retention_policy_id,
                                           'TM9'));
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
        xxfnd_audit_pkg.log_change('XXFND_RETENTION_POLICIES',
                                   l_pk,
                                   'U',
                                   'TABLE_NAME',
                                   :old.table_name,
                                   :new.table_name);
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
        xxfnd_audit_pkg.log_change('XXFND_RETENTION_POLICIES',
                                   l_pk,
                                   'U',
                                   'JURISDICTION',
                                   :old.jurisdiction,
                                   :new.jurisdiction);
    end if;

    if ( :old.retention_years <> :new.retention_years )
    or (
        :old.retention_years is null
        and :new.retention_years is not null
    )
    or (
        :old.retention_years is not null
        and :new.retention_years is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_RETENTION_POLICIES',
                                   l_pk,
                                   'U',
                                   'RETENTION_YEARS',
                                   to_char(:old.retention_years,
                                           'TM9'),
                                   to_char(:new.retention_years,
                                           'TM9'));
    end if;

    if ( :old.action_at_expiry <> :new.action_at_expiry )
    or (
        :old.action_at_expiry is null
        and :new.action_at_expiry is not null
    )
    or (
        :old.action_at_expiry is not null
        and :new.action_at_expiry is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_RETENTION_POLICIES',
                                   l_pk,
                                   'U',
                                   'ACTION_AT_EXPIRY',
                                   :old.action_at_expiry,
                                   :new.action_at_expiry);
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
        xxfnd_audit_pkg.log_change('XXFND_RETENTION_POLICIES',
                                   l_pk,
                                   'U',
                                   'ENABLED_FLAG',
                                   :old.enabled_flag,
                                   :new.enabled_flag);
    end if;

end;
/

alter trigger xxcus.xxfnd_retention_policies_aud enable;


-- sqlcl_snapshot {"hash":"5112d59a8e3dfbe3e1979de5262319618a7f3b03","type":"TRIGGER","name":"XXFND_RETENTION_POLICIES_AUD","schemaName":"XXCUS","sxml":""}