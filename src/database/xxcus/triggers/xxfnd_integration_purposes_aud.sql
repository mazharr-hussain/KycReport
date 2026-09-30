create or replace editionable trigger xxcus.xxfnd_integration_purposes_aud after
    insert or update or delete on xxcus.xxfnd_integration_purposes
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXFND_INTEGRATION_PURPOSES',
                                   to_char(:new.purpose_code),
                                   'I');
        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXFND_INTEGRATION_PURPOSES',
                                   to_char(:old.purpose_code),
                                   'D');
        return;
    end if;

    l_pk := to_char(:new.purpose_code);
    if ( :old.purpose_code <> :new.purpose_code )
    or (
        :old.purpose_code is null
        and :new.purpose_code is not null
    )
    or (
        :old.purpose_code is not null
        and :new.purpose_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_INTEGRATION_PURPOSES',
                                   l_pk,
                                   'U',
                                   'PURPOSE_CODE',
                                   :old.purpose_code,
                                   :new.purpose_code);
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
        xxfnd_audit_pkg.log_change('XXFND_INTEGRATION_PURPOSES',
                                   l_pk,
                                   'U',
                                   'APPLICATION_CODE',
                                   :old.application_code,
                                   :new.application_code);
    end if;

    if ( :old.purpose_name <> :new.purpose_name )
    or (
        :old.purpose_name is null
        and :new.purpose_name is not null
    )
    or (
        :old.purpose_name is not null
        and :new.purpose_name is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_INTEGRATION_PURPOSES',
                                   l_pk,
                                   'U',
                                   'PURPOSE_NAME',
                                   :old.purpose_name,
                                   :new.purpose_name);
    end if;

    if ( :old.endpoint_code <> :new.endpoint_code )
    or (
        :old.endpoint_code is null
        and :new.endpoint_code is not null
    )
    or (
        :old.endpoint_code is not null
        and :new.endpoint_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_INTEGRATION_PURPOSES',
                                   l_pk,
                                   'U',
                                   'ENDPOINT_CODE',
                                   :old.endpoint_code,
                                   :new.endpoint_code);
    end if;

    if ( :old.capture_method <> :new.capture_method )
    or (
        :old.capture_method is null
        and :new.capture_method is not null
    )
    or (
        :old.capture_method is not null
        and :new.capture_method is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_INTEGRATION_PURPOSES',
                                   l_pk,
                                   'U',
                                   'CAPTURE_METHOD',
                                   :old.capture_method,
                                   :new.capture_method);
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
        xxfnd_audit_pkg.log_change('XXFND_INTEGRATION_PURPOSES',
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
        xxfnd_audit_pkg.log_change('XXFND_INTEGRATION_PURPOSES',
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
        xxfnd_audit_pkg.log_change('XXFND_INTEGRATION_PURPOSES',
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

alter trigger xxcus.xxfnd_integration_purposes_aud enable;


-- sqlcl_snapshot {"hash":"d362ed06bca823e6a671be25019f9bbb09ecdddd","type":"TRIGGER","name":"XXFND_INTEGRATION_PURPOSES_AUD","schemaName":"XXCUS","sxml":""}