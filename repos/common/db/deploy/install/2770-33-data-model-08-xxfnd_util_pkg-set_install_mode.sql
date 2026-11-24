
-- the feature (Platform; IT at install), its pages, the diagram groups of COMMON's tables and COMMON's prefix
begin
    xxfnd_util_pkg.set_install_mode(true);
    xxfnd_privilege_pkg.register_feature(p_application_code => 'COMMON', p_feature_code => 'DATA_MODEL',
        p_feature_name => 'Data Model', p_feature_group => 'PLATFORM', p_display_sequence => 70, p_admin_flag => 'Y',
        p_home_page_id => 175, p_icon_css => 'fa-sitemap',
        p_description => 'The database objects of every registered application, read live from the dictionary: the object catalogue and the entity-relationship diagram.');
    xxfnd_privilege_pkg.register_privilege('COMMON', 'DATA_MODEL', 'VIEW');
    xxfnd_privilege_pkg.register_privilege('COMMON', 'DATA_MODEL', 'MANAGE');
    xxfnd_privilege_pkg.register_feature_page('COMMON', 'DATA_MODEL', 175, 'Objects', 10);
    xxfnd_privilege_pkg.register_feature_page('COMMON', 'DATA_MODEL', 176);
    xxfnd_privilege_pkg.register_feature_page('COMMON', 'DATA_MODEL', 177, 'Diagram', 20);
    xxfnd_privilege_pkg.add_role_privilege('COMMON', 'COMMON_ADMIN', 'DATA_MODEL.VIEW');
    xxfnd_privilege_pkg.add_role_privilege('COMMON', 'COMMON_ADMIN', 'DATA_MODEL.MANAGE');
    declare
        l_n pls_integer;
        procedure g(p_table in varchar2, p_group in varchar2) is
        begin
            xxfnd_data_model_pkg.register_table_group('COMMON', p_table, p_group);
        end g;
    begin
        select count(*) into l_n from xxfnd_dm_app_scopes where application_code = 'COMMON';
        if l_n = 0 then
            xxfnd_data_model_pkg.set_object_prefix('COMMON', 'XXFND_,XXHR_');
        else
            -- release 102: the HR tables (XXHR_) are COMMON's too; an administrator's other prefix is kept
            select count(*) into l_n from xxfnd_dm_app_scopes where application_code = 'COMMON' and object_prefix = 'XXFND_';
            if l_n > 0 then
                xxfnd_data_model_pkg.set_object_prefix('COMMON', 'XXFND_,XXHR_');
            end if;
        end if;
        -- COMMON's tables by module (the six modules of COMMON)
        g('XXFND_APPLICATIONS', 'Platform');
        g('XXFND_APPLICATION_FUNCTIONS', 'Platform');
        g('XXFND_APP_MENU_ENTRIES', 'Platform');
        g('XXFND_SETUP_TYPES', 'Platform');
        g('XXFND_SETUP_TYPE_APPS', 'Platform');
        g('XXFND_MESSAGES', 'Platform');
        g('XXFND_ERROR_LOG', 'Platform');
        g('XXFND_SCHEMA_RELEASES', 'Platform');
        g('XXFND_DROPPED_OBJECTS', 'Platform');
        g('XXFND_FEATURES', 'Security');
        g('XXFND_FEATURE_PAGES', 'Security');
        g('XXFND_PRIVILEGES', 'Security');
        g('XXFND_ROLES', 'Security');
        g('XXFND_ROLE_PRIVILEGES', 'Security');
        g('XXFND_USERS', 'Security');
        g('XXFND_USER_ROLES', 'Security');
        g('XXHR_EMPLOYEES', 'Security');
        g('XXHR_ORGANIZATIONS', 'Security');
        g('XXFND_DATA_SECURITY_RULES', 'Security');
        g('XXFND_DATA_RULE_ASSIGNMENTS', 'Security');
        g('XXFND_SOD_RULES', 'Security');
        g('XXFND_AUDIT_LOG', 'Security');
        g('XXFND_LOOKUP_TYPES', 'Reference Data');
        g('XXFND_LOOKUP_VALUES', 'Reference Data');
        g('XXFND_LOOKUP_VALUES_TL', 'Reference Data');
        g('XXFND_VALUE_SETS', 'Reference Data');
        g('XXFND_DF_FLEXFIELDS', 'Reference Data');
        g('XXFND_DF_FLEXFIELDS_TL', 'Reference Data');
        g('XXFND_DF_CONTEXTS', 'Reference Data');
        g('XXFND_DF_CONTEXTS_TL', 'Reference Data');
        g('XXFND_DF_SEGMENTS', 'Reference Data');
        g('XXFND_DF_SEGMENTS_TL', 'Reference Data');
        g('XXFND_DOCUMENT_ENTITIES', 'Documents and Records');
        g('XXFND_DOCUMENT_ENTITIES_TL', 'Documents and Records');
        g('XXFND_DOCUMENT_CATEGORIES', 'Documents and Records');
        g('XXFND_DOCUMENT_CATEGORIES_TL', 'Documents and Records');
        g('XXFND_DOCUMENTS', 'Documents and Records');
        g('XXFND_DOCUMENTS_TL', 'Documents and Records');
        g('XXFND_DOCUMENT_FILES', 'Documents and Records');
        g('XXFND_ATTACHED_DOCUMENTS', 'Documents and Records');
        g('XXFND_ATTACHMENT_FUNCTIONS', 'Documents and Records');
        g('XXFND_ATTACHMENT_BLOCKS', 'Documents and Records');
        g('XXFND_ATTACHMENT_BLK_ENTITIES', 'Documents and Records');
        g('XXFND_DOC_CATEGORY_USAGES', 'Documents and Records');
        g('XXFND_ENTITY_CONTAINERS', 'Documents and Records');
        g('XXFND_STORAGE_CONFIG', 'Documents and Records');
        g('XXFND_RETENTION_POLICIES', 'Documents and Records');
        g('XXFND_WORKFLOW_PROCESSES', 'Workflow');
        g('XXFND_TASK_SETTINGS', 'Workflow');
        g('XXFND_TASK_ALERTS', 'Workflow');
        g('XXFND_WF_DELEGATIONS', 'Workflow');
        g('XXFND_CONFIG_TABLES', 'Workflow');
        g('XXFND_APPROVAL_TYPES', 'Workflow');
        g('XXFND_APPROVAL_TYPE_ATTRS', 'Workflow');
        g('XXFND_APPROVAL_RULES', 'Workflow');
        g('XXFND_APPROVAL_RULE_CONDS', 'Workflow');
        g('XXFND_APPROVAL_RULE_STEPS', 'Workflow');
        g('XXFND_APPROVAL_TXNS', 'Workflow');
        g('XXFND_APPROVAL_TXN_STEPS', 'Workflow');
        g('XXFND_RFIS', 'Workflow');
        g('XXFND_RFI_ROUNDS', 'Workflow');
        g('XXFND_NOTIFY_EVENTS', 'Workflow');
        g('XXFND_NOTIFY_CHANNELS', 'Workflow');
        g('XXFND_NOTIFY_RECIPIENT_TYPES', 'Workflow');
        g('XXFND_NOTIFY_RULES', 'Workflow');
        g('XXFND_NOTIFICATION_TEMPLATES', 'Workflow');
        g('XXFND_NOTIFICATION_TEMPLATES_TL', 'Workflow');
        g('XXFND_NOTIFICATIONS', 'Workflow');
        g('XXFND_COMMUNICATIONS', 'Workflow');
        g('XXFND_CONTACT_SOURCES', 'Workflow');
        g('XXFND_SERVERS', 'Integrations');
        g('XXFND_SERVER_TESTS', 'Integrations');
        g('XXFND_INTEGRATION_PURPOSES', 'Integrations');
        g('XXFND_INTEGRATION_CALLS', 'Integrations');
    end;
    -- every registered application gets the new common function and its menu entry (only what is missing)
    for a in (select application_code from xxfnd_applications where application_code <> 'COMMON') loop
        xxfnd_application_pkg.ensure_menu(a.application_code);
    end loop;
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
