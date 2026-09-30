create or replace editionable trigger xxcus.xxfnd_roles_aud after
    insert or update or delete on xxcus.xxfnd_roles
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXFND_ROLES',
                                   to_char(:new.role_code),
                                   'I');
        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXFND_ROLES',
                                   to_char(:old.role_code),
                                   'D');
        return;
    end if;

    l_pk := to_char(:new.role_code);
    if ( :old.role_code <> :new.role_code )
    or (
        :old.role_code is null
        and :new.role_code is not null
    )
    or (
        :old.role_code is not null
        and :new.role_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_ROLES',
                                   l_pk,
                                   'U',
                                   'ROLE_CODE',
                                   :old.role_code,
                                   :new.role_code);
    end if;

    if ( :old.application_code <> :new.application_code )
    or (
        :old.application_code is null
        and :new.application_code is not null
    )
    or (
        :old.application_code is not null
        and :new.application_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_ROLES',
                                   l_pk,
                                   'U',
                                   'APPLICATION_CODE',
                                   :old.application_code,
                                   :new.application_code);
    end if;

    if ( :old.role_name <> :new.role_name )
    or (
        :old.role_name is null
        and :new.role_name is not null
    )
    or (
        :old.role_name is not null
        and :new.role_name is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_ROLES',
                                   l_pk,
                                   'U',
                                   'ROLE_NAME',
                                   :old.role_name,
                                   :new.role_name);
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
        xxfnd_audit_pkg.log_change('XXFND_ROLES',
                                   l_pk,
                                   'U',
                                   'DESCRIPTION',
                                   :old.description,
                                   :new.description);
    end if;

    if ( :old.view_sensitive_flag <> :new.view_sensitive_flag )
    or (
        :old.view_sensitive_flag is null
        and :new.view_sensitive_flag is not null
    )
    or (
        :old.view_sensitive_flag is not null
        and :new.view_sensitive_flag is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_ROLES',
                                   l_pk,
                                   'U',
                                   'VIEW_SENSITIVE_FLAG',
                                   :old.view_sensitive_flag,
                                   :new.view_sensitive_flag);
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
        xxfnd_audit_pkg.log_change('XXFND_ROLES',
                                   l_pk,
                                   'U',
                                   'ENABLED_FLAG',
                                   :old.enabled_flag,
                                   :new.enabled_flag);
    end if;

end;
/

alter trigger xxcus.xxfnd_roles_aud enable;


-- sqlcl_snapshot {"hash":"6d3aa70aa9cf1eb64e0faaf8f7043472b1f07ee6","type":"TRIGGER","name":"XXFND_ROLES_AUD","schemaName":"XXCUS","sxml":""}