--------------------------------------------------------------------------------
-- 29 Workspace servers and document storage per application (release 86, part B). COMMON only (XXFUSION), after 28.
--   The tables, columns and views this release needs are created where their owner runs earlier (checked steps):
--   XXFND_SERVERS, XXFND_SERVERS_V and XXFND_INTEGRATION_PURPOSES.SERVER_CODE in 05b (integrations); the storage
--   columns, XXFND_DOCUMENTS.SERVER_CODE / STORAGE_CONTAINER and XXFND_APP_STORAGE_V in 14 (attachments).
--   This script:
--   1. Lookups SERVER_TYPE (the six server types) and STORAGE_TYPE (+ OCI Object Storage, Database).
--   2. Copies the retired XXFND_INTEGRATION_ENDPOINTS into XXFND_SERVERS (base URL, Web Credential, OAuth token URL)
--      where no server of that code exists; adds the servers COMMON ships as workspace components (FUSION, UCM_MAIN,
--      SHAREPOINT_MAIN) when missing.
--   3. Purposes: SERVER_CODE from the old endpoint; an API purpose needs a REST Data Source or a server (CK5, was CK4).
--   4. Converts the old storage rules (entity / category / endpoint, shared or per application) into the new form:
--      one row per application (category empty = the application default; application empty = COMMON) and per
--      category override; the server is the old endpoint. A shared rule becomes the rule of COMMON and of every
--      registered application that has none; of several old rules for the same application and category the generic
--      one (no entity), then the lowest priority, stays enabled - the others are disabled, not deleted (documents
--      stored by them keep their location). Documents record their server and library (STORAGE_CONTAINER).
--   5. Drops the retired endpoint objects: trigger XXFND_INT_ENDPOINTS_RO, the foreign keys to the table and the table
--      (XXFND_DDL_PKG.DROP_OBJECT records the DDL; the table goes to the recycle bin, not purged).
--   6. Setup types: Document Storage at instance or application level; Servers (table XXFND_SERVERS) replaces
--      Integration Endpoints.
-- Idempotent: every step acts only when needed; a re-run changes nothing.
--------------------------------------------------------------------------------

-- 1. lookups
declare
    procedure lv(p_type in varchar2, p_code in varchar2, p_meaning in varchar2, p_seq in number) is
    begin
        merge into xxfnd_lookup_values t using (select p_type lookup_type, p_code lookup_code from dual) s
           on (t.lookup_type = s.lookup_type and t.lookup_code = s.lookup_code)
         when not matched then insert (lookup_type, lookup_code, meaning, display_sequence)
                               values (p_type, p_code, p_meaning, p_seq);
    end lv;
begin
    xxfnd_util_pkg.set_install_mode(true);
    merge into xxfnd_lookup_types t using (select 'SERVER_TYPE' lookup_type from dual) s
       on (t.lookup_type = s.lookup_type)
     when not matched then insert (lookup_type, meaning, customization_level, description)
                           values ('SERVER_TYPE', 'Server Types', 'S',
                                   'Release 86: types of the workspace servers (XXFND_SERVERS). Storage: OBJECT_STORAGE, '
                                   || 'SHAREPOINT, UCM; integration: FUSION, REST, OUTLOOK.');
    lv('SERVER_TYPE', 'OBJECT_STORAGE', 'OCI Object Storage', 10);
    lv('SERVER_TYPE', 'SHAREPOINT', 'Microsoft SharePoint (Graph)', 20);
    lv('SERVER_TYPE', 'UCM', 'Oracle WebCenter Content (UCM)', 30);
    lv('SERVER_TYPE', 'FUSION', 'Oracle Fusion Cloud', 40);
    lv('SERVER_TYPE', 'REST', 'REST service', 50);
    lv('SERVER_TYPE', 'OUTLOOK', 'Outlook (Microsoft Graph)', 60);
    lv('STORAGE_TYPE', 'OBJECT_STORAGE', 'OCI Object Storage', 30);
    lv('STORAGE_TYPE', 'DATABASE', 'Database', 40);
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/

-- 2. the servers: the retired endpoints (dynamic SQL - the table is gone after the first run), then the servers
-- COMMON ships as workspace components
declare
    l_n pls_integer;
    procedure srv(p_code in varchar2, p_name in varchar2, p_type in varchar2, p_cred in varchar2, p_desc in varchar2) is
    begin
        merge into xxfnd_servers t using (select p_code server_code from dual) s
           on (t.server_code = s.server_code)
         when not matched then insert (server_code, server_name, server_type, credential_static_id, enabled_flag, description)
                               values (s.server_code, p_name, p_type, p_cred, 'Y', p_desc);
    end srv;
begin
    xxfnd_util_pkg.set_install_mode(true);
    select count(*) into l_n from user_tables where table_name = 'XXFND_INTEGRATION_ENDPOINTS';
    if l_n > 0 then
        execute immediate q'~
        merge into xxfnd_servers t
        using (select e.endpoint_code, e.endpoint_name, e.base_url, e.web_credential_static_id, e.oauth_token_url,
                      e.description,
                      case when e.endpoint_type in ('UCM', 'SHAREPOINT') then e.endpoint_type
                           when e.endpoint_code = 'FUSION' then 'FUSION'
                           when e.endpoint_code like 'OUTLOOK%' then 'OUTLOOK'
                           else 'REST' end                                       as server_type,
                      case when e.status_code = 'INACTIVE' then 'N' else 'Y' end as enabled_flag
                 from xxfnd_integration_endpoints e
                where e.endpoint_code <> 'DATABASE') s
           on (t.server_code = s.endpoint_code)
         when not matched then insert (server_code, server_name, server_type, base_url, credential_static_id,
                                       oauth_token_url, enabled_flag, description)
                               values (s.endpoint_code, s.endpoint_name, s.server_type, s.base_url,
                                       s.web_credential_static_id,
                                       case when s.server_type in ('SHAREPOINT', 'OUTLOOK') then s.oauth_token_url end,
                                       s.enabled_flag, s.description)~';
    end if;
    -- release 100: the credential of the workspace's Fusion integration (prerequisite), not a COMMON placeholder
    srv('FUSION', 'Oracle Fusion Cloud', 'FUSION', 'apex-fa-iabwbn-dev1-dbms-cred',
        'Oracle Fusion Cloud Applications (HCM workers for the user sync).');
    update xxfnd_servers set credential_static_id = 'apex-fa-iabwbn-dev1-dbms-cred'
     where server_code = 'FUSION' and credential_static_id = 'FUSION_CREDENTIALS';
    srv('UCM_MAIN', 'Oracle WebCenter Content', 'UCM', 'XXFND_UCM_CRED', 'Document store UCM (attachments).');
    srv('SHAREPOINT_MAIN', 'Microsoft SharePoint (Graph)', 'SHAREPOINT', 'XXFND_GRAPH_CRED',
        'Document store SharePoint through Microsoft Graph (attachments). Needs the OAuth token URL of the tenant.');
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/

-- 3. purposes: the server of the old endpoint; an API purpose needs a REST Data Source or a server
begin
    xxfnd_util_pkg.set_install_mode(true);
    update xxfnd_integration_purposes p
       set p.server_code = p.endpoint_code
     where p.server_code is null
       and p.endpoint_code is not null
       and exists (select 1 from xxfnd_servers s where s.server_code = p.endpoint_code);
    xxfnd_util_pkg.set_install_mode(false);
    commit;
    xxfnd_ddl_pkg.drop_constraint('XXFND_INTEGRATION_PURPOSES', 'XXFND_INT_PURPOSES_CK4');
    xxfnd_ddl_pkg.add_constraint('XXFND_INTEGRATION_PURPOSES', 'XXFND_INT_PURPOSES_CK5',
        q'~check (capture_method = 'MANUAL' or rest_source_static_id is not null or server_code is not null)~');
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/

-- 4. the old storage rules in the new form (rows not converted yet: an endpoint and no server)
begin
    xxfnd_ddl_pkg.drop_index('XXFND_STORAGE_CONFIG_U1');   -- (entity, category): replaced by U2 (application, category)
    -- storage is kept per application now (instance = COMMON, or an application): the setup type allows both, so
    -- the rows below and the Storage editor may name an application (trigger XXFND_STORAGE_CONFIG_LV)
    xxfnd_util_pkg.set_install_mode(true);
    update xxfnd_setup_types
       set allowed_level = 'B',
           description   = 'Where attached documents are kept: per application and category (release 86).'
     where setup_type_code = 'DOCUMENT_STORAGE' and allowed_level = 'I';
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/

declare
    l_app   varchar2(30);
    l_n     pls_integer;
    l_enabled varchar2(1);

    -- an enabled rule exists for the application (empty = COMMON) and category
    function taken(p_app in varchar2, p_category in varchar2, p_except in number) return boolean is
        l_c pls_integer;
    begin
        select count(*) into l_c from xxfnd_storage_config
         where enabled_flag = 'Y' and storage_config_id <> p_except
           and nvl(application_code, '#') = nvl(p_app, '#') and nvl(category_code, '#') = nvl(p_category, '#')
           and (server_code is not null or storage_type = 'DATABASE' or endpoint_code is null);
        return l_c > 0;
    end taken;
begin
    xxfnd_util_pkg.set_install_mode(true);
    for r in (select s.*,
                     (select max(e.application_code) from xxfnd_document_entities e where e.entity_name = s.entity_name) as entity_app,
                     (select max(c.application_code) from xxfnd_document_categories c where c.category_code = s.category_code) as category_app
                from xxfnd_storage_config s
               where s.server_code is null
                 and s.endpoint_code is not null
               order by case when s.enabled_flag = 'Y' then 0 else 1 end,
                        case when s.entity_name is null then 0 else 1 end,
                        s.priority, s.storage_config_id) loop
        l_app := upper(coalesce(r.application_code, r.entity_app, r.category_app));
        if l_app = 'COMMON' then
            l_app := null;
        end if;
        -- the row itself: its application and server; disabled when another rule already holds its place
        l_enabled := r.enabled_flag;
        if l_enabled = 'Y' and taken(l_app, r.category_code, r.storage_config_id) then
            l_enabled := 'N';
        end if;
        update xxfnd_storage_config
           set server_code      = r.endpoint_code,
               application_code = l_app,
               enabled_flag     = l_enabled
         where storage_config_id = r.storage_config_id;
        -- a shared rule (no application anywhere): also the rule of every registered application without one
        if r.enabled_flag = 'Y' and coalesce(r.application_code, r.entity_app, r.category_app) is null then
            for a in (select application_code from xxfnd_applications
                       where application_code <> 'COMMON' order by application_code) loop
                if not taken(a.application_code, r.category_code, -1) then
                    insert into xxfnd_storage_config (application_code, category_code, storage_type, server_code,
                                                      folder_path_template, ucm_security_group, ucm_doc_type,
                                                      ucm_doc_account, sharepoint_site_id, sharepoint_drive_id,
                                                      priority, enabled_flag)
                    values (a.application_code, r.category_code, r.storage_type, r.endpoint_code,
                            r.folder_path_template, r.ucm_security_group, r.ucm_doc_type, r.ucm_doc_account,
                            r.sharepoint_site_id, r.sharepoint_drive_id, r.priority, 'Y');
                end if;
            end loop;
        end if;
    end loop;

    -- documents keep where they are: their server and library from the rule that stored them
    update xxfnd_documents d
       set (d.server_code, d.storage_container) =
           (select coalesce(s.server_code, s.endpoint_code),
                   case d.storage_type when 'SHAREPOINT' then s.sharepoint_drive_id
                                       when 'OBJECT_STORAGE' then s.bucket_name end
              from xxfnd_storage_config s where s.storage_config_id = d.storage_config_id)
     where d.server_code is null
       and d.storage_type in ('UCM', 'SHAREPOINT', 'OBJECT_STORAGE')
       and d.storage_config_id is not null;
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/

begin
    -- one enabled rule per application and category (application empty = COMMON, category empty = default)
    xxfnd_ddl_pkg.ensure_index('XXFND_STORAGE_CONFIG_U2', q'~create unique index xxfnd_storage_config_u2 on xxfnd_storage_config (
        case when enabled_flag = 'Y' then nvl(application_code, '#') end,
        case when enabled_flag = 'Y' then nvl(category_code, '#') end)~');
end;
/

-- 5. the retired endpoints: trigger, the foreign keys to the table, the table (data copied in step 2)
begin
    xxfnd_ddl_pkg.drop_object('XXFND_INT_ENDPOINTS_RO', 'TRIGGER');
    xxfnd_ddl_pkg.drop_constraint('XXFND_STORAGE_CONFIG', 'XXFND_STORAGE_CONFIG_FK3');
    xxfnd_ddl_pkg.drop_constraint('XXFND_INTEGRATION_PURPOSES', 'XXFND_INT_PURPOSES_FK1');
    xxfnd_ddl_pkg.drop_constraint('XXFND_TRANSMISSIONS', 'XXFND_TRANSMISSIONS_FK1');
    xxfnd_ddl_pkg.drop_object('XXFND_INTEGRATION_ENDPOINTS', 'TABLE', p_retired_table => true);
    delete from xxfnd_config_tables where table_name = 'XXFND_INTEGRATION_ENDPOINTS';
    commit;
end;
/
comment on column xxfnd_integration_purposes.endpoint_code is 'Before release 86: the retired integration endpoint. No longer read (SERVER_CODE).';
-- release 108: XXFND_TRANSMISSIONS is retired (not created any more): its comment only where it still exists
declare
    l_n pls_integer;
begin
    select count(*) into l_n from user_tables where table_name = 'XXFND_TRANSMISSIONS';
    if l_n > 0 then
        execute immediate q'~comment on column xxfnd_transmissions.endpoint_code is 'Before release 86: the retired integration endpoint (this log is no longer written: XXFND_INTEGRATION_CALLS).'~';
    end if;
end;
/

-- 6. setup types: Servers instead of Integration Endpoints (Document Storage: step 4)
declare
    l_n pls_integer;
begin
    xxfnd_util_pkg.set_install_mode(true);
    select count(*) into l_n from xxfnd_setup_types where setup_type_code = 'SERVERS';
    if l_n = 0 then
        insert into xxfnd_setup_types (setup_type_code, setup_type_name, feature_code, table_name, list_page_id,
                                       form_page_id, allowed_level, all_applications_flag, display_sequence, description)
        values ('SERVERS', 'Servers', 'INTEGRATIONS', 'XXFND_SERVERS', 120, 121, 'I', 'Y', 100,
                'Workspace servers (APEX Remote Servers and Web Credentials) for storage and integrations.');
    end if;
    -- the retired type (its applications go with it: on delete cascade)
    delete from xxfnd_setup_types where setup_type_code = 'INTEGRATION_ENDPOINTS';
    update xxfnd_setup_types set description = 'What a server is used for.'
     where setup_type_code = 'INTEGRATION_PURPOSES' and description = 'What an endpoint is used for.';
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/

-- anything a change above left invalid is compiled again (no install error, no stale package state)
begin
    dbms_utility.compile_schema(schema => user, compile_all => false);
end;
/
