create or replace editionable trigger xxcus.xxfnd_storage_config_aud after
    insert or update or delete on xxcus.xxfnd_storage_config
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXFND_STORAGE_CONFIG',
                                   to_char(:new.storage_config_id),
                                   'I');
        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXFND_STORAGE_CONFIG',
                                   to_char(:old.storage_config_id),
                                   'D');
        return;
    end if;

    l_pk := to_char(:new.storage_config_id);
    if ( :old.storage_config_id <> :new.storage_config_id )
    or (
        :old.storage_config_id is null
        and :new.storage_config_id is not null
    )
    or (
        :old.storage_config_id is not null
        and :new.storage_config_id is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_STORAGE_CONFIG',
                                   l_pk,
                                   'U',
                                   'STORAGE_CONFIG_ID',
                                   to_char(:old.storage_config_id,
                                           'TM9'),
                                   to_char(:new.storage_config_id,
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
        xxfnd_audit_pkg.log_change('XXFND_STORAGE_CONFIG',
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
        xxfnd_audit_pkg.log_change('XXFND_STORAGE_CONFIG',
                                   l_pk,
                                   'U',
                                   'CATEGORY_CODE',
                                   :old.category_code,
                                   :new.category_code);
    end if;

    if ( :old.storage_type <> :new.storage_type )
    or (
        :old.storage_type is null
        and :new.storage_type is not null
    )
    or (
        :old.storage_type is not null
        and :new.storage_type is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_STORAGE_CONFIG',
                                   l_pk,
                                   'U',
                                   'STORAGE_TYPE',
                                   :old.storage_type,
                                   :new.storage_type);
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
        xxfnd_audit_pkg.log_change('XXFND_STORAGE_CONFIG',
                                   l_pk,
                                   'U',
                                   'ENDPOINT_CODE',
                                   :old.endpoint_code,
                                   :new.endpoint_code);
    end if;

    if ( :old.folder_path_template <> :new.folder_path_template )
    or (
        :old.folder_path_template is null
        and :new.folder_path_template is not null
    )
    or (
        :old.folder_path_template is not null
        and :new.folder_path_template is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_STORAGE_CONFIG',
                                   l_pk,
                                   'U',
                                   'FOLDER_PATH_TEMPLATE',
                                   :old.folder_path_template,
                                   :new.folder_path_template);
    end if;

    if ( :old.ucm_security_group <> :new.ucm_security_group )
    or (
        :old.ucm_security_group is null
        and :new.ucm_security_group is not null
    )
    or (
        :old.ucm_security_group is not null
        and :new.ucm_security_group is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_STORAGE_CONFIG',
                                   l_pk,
                                   'U',
                                   'UCM_SECURITY_GROUP',
                                   :old.ucm_security_group,
                                   :new.ucm_security_group);
    end if;

    if ( :old.ucm_doc_type <> :new.ucm_doc_type )
    or (
        :old.ucm_doc_type is null
        and :new.ucm_doc_type is not null
    )
    or (
        :old.ucm_doc_type is not null
        and :new.ucm_doc_type is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_STORAGE_CONFIG',
                                   l_pk,
                                   'U',
                                   'UCM_DOC_TYPE',
                                   :old.ucm_doc_type,
                                   :new.ucm_doc_type);
    end if;

    if ( :old.ucm_doc_account <> :new.ucm_doc_account )
    or (
        :old.ucm_doc_account is null
        and :new.ucm_doc_account is not null
    )
    or (
        :old.ucm_doc_account is not null
        and :new.ucm_doc_account is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_STORAGE_CONFIG',
                                   l_pk,
                                   'U',
                                   'UCM_DOC_ACCOUNT',
                                   :old.ucm_doc_account,
                                   :new.ucm_doc_account);
    end if;

    if ( :old.sharepoint_site_id <> :new.sharepoint_site_id )
    or (
        :old.sharepoint_site_id is null
        and :new.sharepoint_site_id is not null
    )
    or (
        :old.sharepoint_site_id is not null
        and :new.sharepoint_site_id is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_STORAGE_CONFIG',
                                   l_pk,
                                   'U',
                                   'SHAREPOINT_SITE_ID',
                                   :old.sharepoint_site_id,
                                   :new.sharepoint_site_id);
    end if;

    if ( :old.sharepoint_drive_id <> :new.sharepoint_drive_id )
    or (
        :old.sharepoint_drive_id is null
        and :new.sharepoint_drive_id is not null
    )
    or (
        :old.sharepoint_drive_id is not null
        and :new.sharepoint_drive_id is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_STORAGE_CONFIG',
                                   l_pk,
                                   'U',
                                   'SHAREPOINT_DRIVE_ID',
                                   :old.sharepoint_drive_id,
                                   :new.sharepoint_drive_id);
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
        xxfnd_audit_pkg.log_change('XXFND_STORAGE_CONFIG',
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
        xxfnd_audit_pkg.log_change('XXFND_STORAGE_CONFIG',
                                   l_pk,
                                   'U',
                                   'ENABLED_FLAG',
                                   :old.enabled_flag,
                                   :new.enabled_flag);
    end if;

end;
/

alter trigger xxcus.xxfnd_storage_config_aud enable;


-- sqlcl_snapshot {"hash":"14605e67fac64a58abd9af5399f59ae6605014dc","type":"TRIGGER","name":"XXFND_STORAGE_CONFIG_AUD","schemaName":"XXCUS","sxml":""}