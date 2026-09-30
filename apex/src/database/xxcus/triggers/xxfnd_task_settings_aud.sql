create or replace editionable trigger xxcus.xxfnd_task_settings_aud after
    insert or update or delete on xxcus.xxfnd_task_settings
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXFND_TASK_SETTINGS',
                                   to_char(:new.task_definition),
                                   'I');
        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXFND_TASK_SETTINGS',
                                   to_char(:old.task_definition),
                                   'D');
        return;
    end if;

    l_pk := to_char(:new.task_definition);
    if ( :old.task_definition <> :new.task_definition )
    or (
        :old.task_definition is null
        and :new.task_definition is not null
    )
    or (
        :old.task_definition is not null
        and :new.task_definition is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_TASK_SETTINGS',
                                   l_pk,
                                   'U',
                                   'TASK_DEFINITION',
                                   :old.task_definition,
                                   :new.task_definition);
    end if;

    if ( :old.due_days <> :new.due_days )
    or (
        :old.due_days is null
        and :new.due_days is not null
    )
    or (
        :old.due_days is not null
        and :new.due_days is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_TASK_SETTINGS',
                                   l_pk,
                                   'U',
                                   'DUE_DAYS',
                                   to_char(:old.due_days,
                                           'TM9'),
                                   to_char(:new.due_days,
                                           'TM9'));
    end if;

    if ( :old.reminder_days_before <> :new.reminder_days_before )
    or (
        :old.reminder_days_before is null
        and :new.reminder_days_before is not null
    )
    or (
        :old.reminder_days_before is not null
        and :new.reminder_days_before is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_TASK_SETTINGS',
                                   l_pk,
                                   'U',
                                   'REMINDER_DAYS_BEFORE',
                                   to_char(:old.reminder_days_before,
                                           'TM9'),
                                   to_char(:new.reminder_days_before,
                                           'TM9'));
    end if;

    if ( :old.escalation_role_code <> :new.escalation_role_code )
    or (
        :old.escalation_role_code is null
        and :new.escalation_role_code is not null
    )
    or (
        :old.escalation_role_code is not null
        and :new.escalation_role_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_TASK_SETTINGS',
                                   l_pk,
                                   'U',
                                   'ESCALATION_ROLE_CODE',
                                   :old.escalation_role_code,
                                   :new.escalation_role_code);
    end if;

    if ( :old.notify_on_create_flag <> :new.notify_on_create_flag )
    or (
        :old.notify_on_create_flag is null
        and :new.notify_on_create_flag is not null
    )
    or (
        :old.notify_on_create_flag is not null
        and :new.notify_on_create_flag is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_TASK_SETTINGS',
                                   l_pk,
                                   'U',
                                   'NOTIFY_ON_CREATE_FLAG',
                                   :old.notify_on_create_flag,
                                   :new.notify_on_create_flag);
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
        xxfnd_audit_pkg.log_change('XXFND_TASK_SETTINGS',
                                   l_pk,
                                   'U',
                                   'DESCRIPTION',
                                   :old.description,
                                   :new.description);
    end if;

end;
/

alter trigger xxcus.xxfnd_task_settings_aud enable;


-- sqlcl_snapshot {"hash":"fb04d9f0451c99c95be6a48b7c842b5e518774d7","type":"TRIGGER","name":"XXFND_TASK_SETTINGS_AUD","schemaName":"XXCUS","sxml":""}