create or replace editionable trigger xxcus.xxfnd_integration_endpoints_aud after
    insert or update or delete on xxcus.xxfnd_integration_endpoints
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXFND_INTEGRATION_ENDPOINTS',
                                   to_char(:new.endpoint_code),
                                   'I');
        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXFND_INTEGRATION_ENDPOINTS',
                                   to_char(:old.endpoint_code),
                                   'D');
        return;
    end if;

    l_pk := to_char(:new.endpoint_code);
    if ( :old.endpoint_code <> :new.endpoint_code )
    or (
        :old.endpoint_code is null
        and :new.endpoint_code is not null
    )
    or (
        :old.endpoint_code is not null
        and :new.endpoint_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_INTEGRATION_ENDPOINTS',
                                   l_pk,
                                   'U',
                                   'ENDPOINT_CODE',
                                   :old.endpoint_code,
                                   :new.endpoint_code);
    end if;

    if ( :old.endpoint_name <> :new.endpoint_name )
    or (
        :old.endpoint_name is null
        and :new.endpoint_name is not null
    )
    or (
        :old.endpoint_name is not null
        and :new.endpoint_name is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_INTEGRATION_ENDPOINTS',
                                   l_pk,
                                   'U',
                                   'ENDPOINT_NAME',
                                   :old.endpoint_name,
                                   :new.endpoint_name);
    end if;

    if ( :old.endpoint_type <> :new.endpoint_type )
    or (
        :old.endpoint_type is null
        and :new.endpoint_type is not null
    )
    or (
        :old.endpoint_type is not null
        and :new.endpoint_type is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_INTEGRATION_ENDPOINTS',
                                   l_pk,
                                   'U',
                                   'ENDPOINT_TYPE',
                                   :old.endpoint_type,
                                   :new.endpoint_type);
    end if;

    if ( :old.base_url <> :new.base_url )
    or (
        :old.base_url is null
        and :new.base_url is not null
    )
    or (
        :old.base_url is not null
        and :new.base_url is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_INTEGRATION_ENDPOINTS',
                                   l_pk,
                                   'U',
                                   'BASE_URL',
                                   :old.base_url,
                                   :new.base_url);
    end if;

    if ( :old.web_credential_static_id <> :new.web_credential_static_id )
    or (
        :old.web_credential_static_id is null
        and :new.web_credential_static_id is not null
    )
    or (
        :old.web_credential_static_id is not null
        and :new.web_credential_static_id is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_INTEGRATION_ENDPOINTS',
                                   l_pk,
                                   'U',
                                   'WEB_CREDENTIAL_STATIC_ID',
                                   :old.web_credential_static_id,
                                   :new.web_credential_static_id);
    end if;

    if ( :old.oauth_token_url <> :new.oauth_token_url )
    or (
        :old.oauth_token_url is null
        and :new.oauth_token_url is not null
    )
    or (
        :old.oauth_token_url is not null
        and :new.oauth_token_url is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_INTEGRATION_ENDPOINTS',
                                   l_pk,
                                   'U',
                                   'OAUTH_TOKEN_URL',
                                   :old.oauth_token_url,
                                   :new.oauth_token_url);
    end if;

    if ( :old.oauth_scope <> :new.oauth_scope )
    or (
        :old.oauth_scope is null
        and :new.oauth_scope is not null
    )
    or (
        :old.oauth_scope is not null
        and :new.oauth_scope is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_INTEGRATION_ENDPOINTS',
                                   l_pk,
                                   'U',
                                   'OAUTH_SCOPE',
                                   :old.oauth_scope,
                                   :new.oauth_scope);
    end if;

    if ( :old.status_code <> :new.status_code )
    or (
        :old.status_code is null
        and :new.status_code is not null
    )
    or (
        :old.status_code is not null
        and :new.status_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_INTEGRATION_ENDPOINTS',
                                   l_pk,
                                   'U',
                                   'STATUS_CODE',
                                   :old.status_code,
                                   :new.status_code);
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
        xxfnd_audit_pkg.log_change('XXFND_INTEGRATION_ENDPOINTS',
                                   l_pk,
                                   'U',
                                   'DESCRIPTION',
                                   :old.description,
                                   :new.description);
    end if;

end;
/

alter trigger xxcus.xxfnd_integration_endpoints_aud enable;


-- sqlcl_snapshot {"hash":"3c504f4d5ba037fcdc0fac63b08d38d8b787959b","type":"TRIGGER","name":"XXFND_INTEGRATION_ENDPOINTS_AUD","schemaName":"XXCUS","sxml":""}