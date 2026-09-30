create or replace editionable trigger xxcus.xxfnd_employees_aud after
    insert or update or delete on xxcus.xxfnd_employees
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXFND_EMPLOYEES',
                                   to_char(:new.employee_id),
                                   'I');
        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXFND_EMPLOYEES',
                                   to_char(:old.employee_id),
                                   'D');
        return;
    end if;

    l_pk := to_char(:new.employee_id);
    if ( :old.employee_id <> :new.employee_id )
    or (
        :old.employee_id is null
        and :new.employee_id is not null
    )
    or (
        :old.employee_id is not null
        and :new.employee_id is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_EMPLOYEES',
                                   l_pk,
                                   'U',
                                   'EMPLOYEE_ID',
                                   to_char(:old.employee_id,
                                           'TM9'),
                                   to_char(:new.employee_id,
                                           'TM9'));
    end if;

    if ( :old.source_type <> :new.source_type )
    or (
        :old.source_type is null
        and :new.source_type is not null
    )
    or (
        :old.source_type is not null
        and :new.source_type is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_EMPLOYEES',
                                   l_pk,
                                   'U',
                                   'SOURCE_TYPE',
                                   :old.source_type,
                                   :new.source_type);
    end if;

    if ( :old.fusion_person_id <> :new.fusion_person_id )
    or (
        :old.fusion_person_id is null
        and :new.fusion_person_id is not null
    )
    or (
        :old.fusion_person_id is not null
        and :new.fusion_person_id is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_EMPLOYEES',
                                   l_pk,
                                   'U',
                                   'FUSION_PERSON_ID',
                                   to_char(:old.fusion_person_id,
                                           'TM9'),
                                   to_char(:new.fusion_person_id,
                                           'TM9'));
    end if;

    if ( :old.fusion_person_number <> :new.fusion_person_number )
    or (
        :old.fusion_person_number is null
        and :new.fusion_person_number is not null
    )
    or (
        :old.fusion_person_number is not null
        and :new.fusion_person_number is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_EMPLOYEES',
                                   l_pk,
                                   'U',
                                   'FUSION_PERSON_NUMBER',
                                   :old.fusion_person_number,
                                   :new.fusion_person_number);
    end if;

    if ( :old.user_name <> :new.user_name )
    or (
        :old.user_name is null
        and :new.user_name is not null
    )
    or (
        :old.user_name is not null
        and :new.user_name is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_EMPLOYEES',
                                   l_pk,
                                   'U',
                                   'USER_NAME',
                                   :old.user_name,
                                   :new.user_name);
    end if;

    if ( :old.full_name <> :new.full_name )
    or (
        :old.full_name is null
        and :new.full_name is not null
    )
    or (
        :old.full_name is not null
        and :new.full_name is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_EMPLOYEES',
                                   l_pk,
                                   'U',
                                   'FULL_NAME',
                                   :old.full_name,
                                   :new.full_name);
    end if;

    if ( :old.email_address <> :new.email_address )
    or (
        :old.email_address is null
        and :new.email_address is not null
    )
    or (
        :old.email_address is not null
        and :new.email_address is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_EMPLOYEES',
                                   l_pk,
                                   'U',
                                   'EMAIL_ADDRESS',
                                   :old.email_address,
                                   :new.email_address);
    end if;

    if ( :old.department_name <> :new.department_name )
    or (
        :old.department_name is null
        and :new.department_name is not null
    )
    or (
        :old.department_name is not null
        and :new.department_name is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_EMPLOYEES',
                                   l_pk,
                                   'U',
                                   'DEPARTMENT_NAME',
                                   :old.department_name,
                                   :new.department_name);
    end if;

    if ( :old.job_title <> :new.job_title )
    or (
        :old.job_title is null
        and :new.job_title is not null
    )
    or (
        :old.job_title is not null
        and :new.job_title is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_EMPLOYEES',
                                   l_pk,
                                   'U',
                                   'JOB_TITLE',
                                   :old.job_title,
                                   :new.job_title);
    end if;

    if ( :old.last_sync_date <> :new.last_sync_date )
    or (
        :old.last_sync_date is null
        and :new.last_sync_date is not null
    )
    or (
        :old.last_sync_date is not null
        and :new.last_sync_date is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_EMPLOYEES',
                                   l_pk,
                                   'U',
                                   'LAST_SYNC_DATE',
                                   to_char(:old.last_sync_date,
                                           'YYYY-MM-DD HH24:MI:SS.FF'),
                                   to_char(:new.last_sync_date,
                                           'YYYY-MM-DD HH24:MI:SS.FF'));
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
        xxfnd_audit_pkg.log_change('XXFND_EMPLOYEES',
                                   l_pk,
                                   'U',
                                   'ENABLED_FLAG',
                                   :old.enabled_flag,
                                   :new.enabled_flag);
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
        xxfnd_audit_pkg.log_change('XXFND_EMPLOYEES',
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
        xxfnd_audit_pkg.log_change('XXFND_EMPLOYEES',
                                   l_pk,
                                   'U',
                                   'END_DATE_ACTIVE',
                                   to_char(:old.end_date_active,
                                           'YYYY-MM-DD HH24:MI:SS'),
                                   to_char(:new.end_date_active,
                                           'YYYY-MM-DD HH24:MI:SS'));
    end if;

end;
/

alter trigger xxcus.xxfnd_employees_aud enable;


-- sqlcl_snapshot {"hash":"ab370fc1563c86a557a09cc33fcde3117be2fcd2","type":"TRIGGER","name":"XXFND_EMPLOYEES_AUD","schemaName":"XXCUS","sxml":""}