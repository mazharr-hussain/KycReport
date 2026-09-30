create or replace editionable trigger xxcus.xxfnd_notification_templates_aud after
    insert or update or delete on xxcus.xxfnd_notification_templates
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXFND_NOTIFICATION_TEMPLATES',
                                   to_char(:new.template_code),
                                   'I');
        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXFND_NOTIFICATION_TEMPLATES',
                                   to_char(:old.template_code),
                                   'D');
        return;
    end if;

    l_pk := to_char(:new.template_code);
    if ( :old.template_code <> :new.template_code )
    or (
        :old.template_code is null
        and :new.template_code is not null
    )
    or (
        :old.template_code is not null
        and :new.template_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_NOTIFICATION_TEMPLATES',
                                   l_pk,
                                   'U',
                                   'TEMPLATE_CODE',
                                   :old.template_code,
                                   :new.template_code);
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
        xxfnd_audit_pkg.log_change('XXFND_NOTIFICATION_TEMPLATES',
                                   l_pk,
                                   'U',
                                   'APPLICATION_CODE',
                                   :old.application_code,
                                   :new.application_code);
    end if;

    if ( :old.subject <> :new.subject )
    or (
        :old.subject is null
        and :new.subject is not null
    )
    or (
        :old.subject is not null
        and :new.subject is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_NOTIFICATION_TEMPLATES',
                                   l_pk,
                                   'U',
                                   'SUBJECT',
                                   :old.subject,
                                   :new.subject);
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
        xxfnd_audit_pkg.log_change('XXFND_NOTIFICATION_TEMPLATES',
                                   l_pk,
                                   'U',
                                   'ENABLED_FLAG',
                                   :old.enabled_flag,
                                   :new.enabled_flag);
    end if;

end;
/

alter trigger xxcus.xxfnd_notification_templates_aud enable;


-- sqlcl_snapshot {"hash":"6ae76179ec06edd611ed7042dad8885a0d9b0cb4","type":"TRIGGER","name":"XXFND_NOTIFICATION_TEMPLATES_AUD","schemaName":"XXCUS","sxml":""}