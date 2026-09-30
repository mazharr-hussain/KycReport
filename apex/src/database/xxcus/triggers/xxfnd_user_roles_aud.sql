create or replace editionable trigger xxcus.xxfnd_user_roles_aud after
    insert or update or delete on xxcus.xxfnd_user_roles
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXFND_USER_ROLES',
                                   to_char(:new.user_role_id),
                                   'I');
        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXFND_USER_ROLES',
                                   to_char(:old.user_role_id),
                                   'D');
        return;
    end if;

    l_pk := to_char(:new.user_role_id);
    if ( :old.user_role_id <> :new.user_role_id )
    or (
        :old.user_role_id is null
        and :new.user_role_id is not null
    )
    or (
        :old.user_role_id is not null
        and :new.user_role_id is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_USER_ROLES',
                                   l_pk,
                                   'U',
                                   'USER_ROLE_ID',
                                   to_char(:old.user_role_id,
                                           'TM9'),
                                   to_char(:new.user_role_id,
                                           'TM9'));
    end if;

    if ( :old.employee_id <> :new.employee_id )
    or (
        :old.employee_id is null
        and :new.employee_id is not null
    )
    or (
        :old.employee_id is not null
        and :new.employee_id is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_USER_ROLES',
                                   l_pk,
                                   'U',
                                   'EMPLOYEE_ID',
                                   to_char(:old.employee_id,
                                           'TM9'),
                                   to_char(:new.employee_id,
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
        xxfnd_audit_pkg.log_change('XXFND_USER_ROLES',
                                   l_pk,
                                   'U',
                                   'ROLE_CODE',
                                   :old.role_code,
                                   :new.role_code);
    end if;

    if ( :old.start_date_active <> :new.start_date_active )
    or (
        :old.start_date_active is null
        and :new.start_date_active is not null
    )
    or (
        :old.start_date_active is not null
        and :new.start_date_active is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_USER_ROLES',
                                   l_pk,
                                   'U',
                                   'START_DATE_ACTIVE',
                                   to_char(:old.start_date_active,
                                           'YYYY-MM-DD HH24:MI:SS'),
                                   to_char(:new.start_date_active,
                                           'YYYY-MM-DD HH24:MI:SS'));
    end if;

    if ( :old.end_date_active <> :new.end_date_active )
    or (
        :old.end_date_active is null
        and :new.end_date_active is not null
    )
    or (
        :old.end_date_active is not null
        and :new.end_date_active is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_USER_ROLES',
                                   l_pk,
                                   'U',
                                   'END_DATE_ACTIVE',
                                   to_char(:old.end_date_active,
                                           'YYYY-MM-DD HH24:MI:SS'),
                                   to_char(:new.end_date_active,
                                           'YYYY-MM-DD HH24:MI:SS'));
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
        xxfnd_audit_pkg.log_change('XXFND_USER_ROLES',
                                   l_pk,
                                   'U',
                                   'ENABLED_FLAG',
                                   :old.enabled_flag,
                                   :new.enabled_flag);
    end if;

end;
/

alter trigger xxcus.xxfnd_user_roles_aud enable;


-- sqlcl_snapshot {"hash":"9fa180b57250758e6db5ee5fffd515503167c401","type":"TRIGGER","name":"XXFND_USER_ROLES_AUD","schemaName":"XXCUS","sxml":""}