-- Release 86 part B checks (run as XXFUSION from apex/tests, after 29): workspace servers (XXFND_SERVERS), document
-- storage per application with category overrides (XXFND_APP_STORAGE_V, XXFND_ATTACH_PKG.RESOLVE_STORAGE), OCI Object
-- Storage URL and object names (no call to OCI), the conversion of old storage rules (29 is run again here: re-run
-- safe), and no reference left to the retired XXFND_INTEGRATION_ENDPOINTS.
-- Its rows stay (the user keeps test data): disabled application R87TEST, its categories R87_CAT_*, entity R87_ENTITY,
-- servers R87_*, purpose R87_TEST, and two old-form storage rules of R87_ENTITY.
set serveroutput on feedback off

-- test data, and two storage rules in the old form (endpoint and entity, no server) for the conversion
declare
    procedure put_category(p_code in varchar2, p_app in varchar2) is
    begin
        merge into xxfnd_document_categories t using (select p_code c from dual) s on (t.category_code = s.c)
         when not matched then insert (category_code, application_code, category_name) values (s.c, p_app, 'R87 ' || s.c);
    end put_category;
begin
    apex_util.set_workspace('XXCUS');
    xxfnd_util_pkg.set_install_mode(true);
    merge into xxfnd_applications t using (select 'R87TEST' c from dual) s on (t.application_code = s.c)
     when not matched then insert (application_code, application_name, enabled_flag, description)
                           values (s.c, 'R87 storage test', 'N', 'Test application of r87_servers_test.sql');
    put_category('R87_CAT_A', 'R87TEST');
    put_category('R87_CAT_B', 'R87TEST');
    put_category('R87_CAT_C', 'R87TEST');
    put_category('R87_CAT_D', 'R87TEST');
    put_category('R87_CAT_E', 'R87TEST');   -- no override
    put_category('R87_CAT_F', 'R87TEST');   -- typed in the grid by r87_servers_ui.py
    put_category('R87_CAT_X', 'KYC');
    merge into xxfnd_document_entities t using (select 'R87_ENTITY' e from dual) s on (t.entity_name = s.e)
     when not matched then insert (entity_name, application_code, table_name, pk1_column, enabled_flag)
                           values (s.e, 'R87TEST', 'XXFND_SERVERS', 'SERVER_CODE', 'Y');
    -- old form: entity rule for category A (the application already overrides A below - it becomes disabled) and D
    merge into xxfnd_storage_config t
    using (select 'R87_CAT_A' c, 'SG_OLD_A' g from dual union all select 'R87_CAT_D', 'SG_OLD_D' from dual) s
       on (t.entity_name = 'R87_ENTITY' and t.category_code = s.c)
     when not matched then insert (entity_name, category_code, storage_type, endpoint_code, ucm_security_group,
                                   folder_path_template, enabled_flag)
                           values ('R87_ENTITY', s.c, 'UCM', 'UCM_MAIN', s.g, '/old/#PK1_VALUE#', 'Y');
    xxfnd_util_pkg.set_install_mode(false);
    -- the application overrides category A before the old rules are converted; then 29 runs again: it converts the
    -- two old rules, everything else is already done (re-run safe)
    xxfnd_attach_pkg.save_category_storage('R87TEST', 'R87_CAT_A', 'DATABASE');
    commit;
end;
/
@@../db/29-servers.sql

declare
    l_n    number;
    l_v    varchar2(4000);
    l_cfg  xxfnd_storage_config%rowtype;
    l_st   xxfnd_app_storage_v%rowtype;
    procedure check_(p_ok in boolean, p_text in varchar2) is
    begin
        dbms_output.put_line(case when p_ok then 'PASS ' else 'FAIL ' end || p_text);
    end check_;
    procedure expect_error(p_code in number, p_text in varchar2, p_block in varchar2) is
    begin
        execute immediate p_block;
        check_(false, p_text || ' (no error)');
    exception
        when others then
            check_(sqlcode = p_code, p_text || ' (' || sqlcode || ')');
    end expect_error;
    function line(p_category in varchar2) return xxfnd_app_storage_v%rowtype is
        l_r xxfnd_app_storage_v%rowtype;
    begin
        select * into l_r from xxfnd_app_storage_v
         where application_code = 'R87TEST' and nvl(category_code, '#') = nvl(p_category, '#');
        return l_r;
    end line;
begin
    apex_util.set_workspace('XXCUS');

    ---------------------------------------------------------------- objects
    select count(*) into l_n from user_objects where status <> 'VALID';
    check_(l_n = 0, 'no invalid object (' || l_n || ')');
    select count(*) into l_n from user_tables where table_name = 'XXFND_INTEGRATION_ENDPOINTS';
    check_(l_n = 0, 'the retired XXFND_INTEGRATION_ENDPOINTS is dropped');
    select count(*) into l_n from user_triggers where trigger_name = 'XXFND_INT_ENDPOINTS_RO';
    check_(l_n = 0, 'its read-only trigger is dropped');
    select count(*) into l_n from xxfnd_dropped_objects
     where object_name in ('XXFND_INTEGRATION_ENDPOINTS', 'XXFND_INT_ENDPOINTS_RO') and object_ddl is not null;
    check_(l_n >= 2, 'DROP_OBJECT recorded the table and the trigger with their DDL (' || l_n || ')');
    select count(*) into l_n from user_dependencies where referenced_name = 'XXFND_INTEGRATION_ENDPOINTS';
    check_(l_n = 0, 'no object depends on XXFND_INTEGRATION_ENDPOINTS (' || l_n || ')');
    select count(*) into l_n from user_source where upper(text) like '%XXFND_INTEGRATION_ENDPOINTS%';
    check_(l_n = 0, 'no PL/SQL names XXFND_INTEGRATION_ENDPOINTS (' || l_n || ')');
    select count(*) into l_n from user_constraints
     where constraint_name in ('XXFND_STORAGE_CONFIG_FK3', 'XXFND_INT_PURPOSES_FK1', 'XXFND_TRANSMISSIONS_FK1',
                               'XXFND_INT_PURPOSES_CK4', 'XXFND_STORAGE_CONFIG_CK1', 'XXFND_STORAGE_CONFIG_CK2');
    check_(l_n = 0, 'the old foreign keys and checks are gone (' || l_n || ')');
    select count(*) into l_n from user_constraints
     where constraint_name in ('XXFND_STORAGE_CONFIG_FK4', 'XXFND_INT_PURPOSES_FK2', 'XXFND_INT_PURPOSES_CK5',
                               'XXFND_STORAGE_CONFIG_CK4');
    check_(l_n = 4, 'storage rules and purposes refer to XXFND_SERVERS (' || l_n || ' of 4)');
    select count(*) into l_n from user_indexes where index_name = 'XXFND_STORAGE_CONFIG_U2' and uniqueness = 'UNIQUE';
    check_(l_n = 1, 'one enabled storage rule per application and category (U2)');
    select count(*) into l_n from xxfnd_setup_types where setup_type_code = 'SERVERS' and table_name = 'XXFND_SERVERS';
    select count(*) into l_v from xxfnd_setup_types where setup_type_code = 'INTEGRATION_ENDPOINTS';
    check_(l_n = 1 and l_v = '0', 'setup type Servers replaces Integration Endpoints');
    select max(allowed_level) into l_v from xxfnd_setup_types where setup_type_code = 'DOCUMENT_STORAGE';
    check_(l_v = 'B', 'Document Storage is kept for the instance or an application (' || l_v || ')');

    ---------------------------------------------------------------- servers
    select count(*) into l_n from xxfnd_servers where server_code in ('FUSION', 'UCM_MAIN', 'SHAREPOINT_MAIN', 'OUTLOOK_GRAPH');
    check_(l_n = 4, 'the servers COMMON ships are defined (' || l_n || ' of 4)');
    select max(usage) into l_v from xxfnd_servers_v where server_code = 'UCM_MAIN';
    check_(l_v = 'STORAGE', 'UCM is a storage server');
    select max(usage) into l_v from xxfnd_servers_v where server_code = 'FUSION';
    check_(l_v = 'INTEGRATION', 'Fusion is an integration server');
    check_(xxfnd_integration_pkg.server('FUSION').server_type = 'FUSION', 'SERVER returns the defined server with its type');
    xxfnd_integration_pkg.save_server('R87_OS', 'R87 Object Storage', 'OBJECT_STORAGE', 'XXFND_GRAPH_CRED',
                                      p_oauth_token_url => 'https://ignored', p_oci_region => 'eu-frankfurt-1',
                                      p_oci_namespace => 'r87ns');
    select count(*) into l_n from xxfnd_servers
     where server_code = 'R87_OS' and oauth_token_url is null and oci_namespace = 'r87ns';
    check_(l_n = 1, 'the type decides the details kept (Object Storage: no token URL)');
    select max(status) into l_v from xxfnd_servers_v where server_code = 'R87_OS';
    check_(l_v = 'OK', 'an Object Storage server with region, namespace and credential is OK (' || l_v || ')');
    xxfnd_integration_pkg.save_server('R87_SP', 'R87 SharePoint', 'SHAREPOINT', 'XXFND_GRAPH_CRED');
    select max(status) || ' / ' || max(missing) into l_v from xxfnd_servers_v where server_code = 'R87_SP';
    check_(l_v like 'INCOMPLETE%token URL%', 'SharePoint without the OAuth token URL is incomplete (' || l_v || ')');
    xxfnd_integration_pkg.save_server('R87_SP', 'R87 SharePoint', 'SHAREPOINT', 'XXFND_GRAPH_CRED',
                                      p_oauth_token_url => 'https://login.example.com/token',
                                      p_base_url => 'https://graph.microsoft.com/v1.0');
    xxfnd_integration_pkg.save_server('R87_REST', 'R87 REST', 'REST', 'XXFND_GRAPH_CRED');
    expect_error(-20341, 'an unknown server type is refused',
                 q'~begin xxfnd_integration_pkg.save_server('R87_BAD', 'Bad', 'SFTP'); end;~');

    ---------------------------------------------------------------- Object Storage paths (no OCI call)
    l_v := xxfnd_attach_pkg.object_storage_url('R87_OS', 'bkt', 'a/b c.pdf');
    check_(l_v = 'https://objectstorage.eu-frankfurt-1.oraclecloud.com/n/r87ns/b/bkt/o/a%2Fb%20c.pdf',
           'object URL from the region, namespace and bucket, name encoded (' || l_v || ')');
    l_v := xxfnd_attach_pkg.object_storage_url('R87_OS', 'bkt');
    check_(l_v = 'https://objectstorage.eu-frankfurt-1.oraclecloud.com/n/r87ns/b/bkt/o', 'bucket URL');
    l_v := xxfnd_attach_pkg.object_name('/KYC/PARTY/42/', 'id.pdf');
    check_(regexp_like(l_v, '^KYC/PARTY/42/[0-9a-f]{12}_id\.pdf$'), 'object name: folder + unique prefix + file (' || l_v || ')');
    check_(xxfnd_attach_pkg.object_name('/KYC/', 'id.pdf') <> xxfnd_attach_pkg.object_name('/KYC/', 'id.pdf'),
           'a new version never overwrites an object');
    expect_error(-20336, 'Object Storage needs the bucket',
                 q'~declare v varchar2(4000); begin v := xxfnd_attach_pkg.object_storage_url('R87_OS', null, 'x'); end;~');

    ---------------------------------------------------------------- storage resolution
    check_(xxfnd_attach_pkg.storage_application('R87_ENTITY', null) = 'R87TEST', 'the entity decides the application');
    check_(xxfnd_attach_pkg.storage_application('NO_SUCH_ENTITY', 'R87_CAT_X') = 'KYC', 'else the category');
    check_(xxfnd_attach_pkg.storage_application('NO_SUCH_ENTITY', null) = 'COMMON', 'else COMMON');

    xxfnd_attach_pkg.save_app_storage('R87TEST', null);   -- the database
    xxfnd_attach_pkg.save_category_storage('R87TEST', 'R87_CAT_B', null);
    l_cfg := xxfnd_attach_pkg.resolve_storage('R87_ENTITY', 'R87_CAT_B');
    check_(l_cfg.storage_type = 'DATABASE', 'no server for the application: the database');
    check_(line(null).state = 'OK', 'the database is a complete setup');

    xxfnd_attach_pkg.save_app_storage('R87TEST', 'R87_OS');   -- no bucket yet
    l_st := line(null);
    check_(l_st.state = 'INCOMPLETE - using database' and l_st.incomplete_reason = 'the bucket',
           'Object Storage without a bucket: incomplete - using database (' || l_st.state || ')');
    check_(xxfnd_attach_pkg.resolve_storage('R87_ENTITY', 'R87_CAT_B').storage_type = 'DATABASE',
           'an incomplete setup stores in the database (the upload never fails)');

    xxfnd_attach_pkg.save_app_storage('R87TEST', 'R87_OS', p_bucket => 'bkt-app', p_site => 'ignored');
    l_cfg := xxfnd_attach_pkg.resolve_storage('R87_ENTITY', 'R87_CAT_B');
    check_(l_cfg.storage_type = 'OBJECT_STORAGE' and l_cfg.server_code = 'R87_OS' and l_cfg.bucket_name = 'bkt-app'
           and l_cfg.sharepoint_site_id is null,
           'application default: Object Storage, its bucket; fields of other types cleared');
    check_(l_cfg.folder_path_template = '/#CATEGORY#/#ENTITY_NAME#/#PK1_VALUE#', 'the default folder pattern');
    xxfnd_attach_pkg.save_category_storage('R87TEST', 'R87_CAT_E', null);   -- no override (a row emptied stays)
    l_cfg := xxfnd_attach_pkg.resolve_storage('R87_ENTITY', 'R87_CAT_E');
    check_(l_cfg.bucket_name = 'bkt-app'
           and l_cfg.storage_config_id = nvl(line('R87_CAT_E').storage_config_id, line(null).storage_config_id),
           'a category without an override: the application''s values, stored by its own row or the application row');

    xxfnd_attach_pkg.save_category_storage('R87TEST', 'R87_CAT_B', null, p_bucket => 'bkt-b', p_folder => '/b/#PK1_VALUE#');
    l_cfg := xxfnd_attach_pkg.resolve_storage('R87_ENTITY', 'R87_CAT_B');
    check_(l_cfg.bucket_name = 'bkt-b' and l_cfg.folder_path_template = '/b/#PK1_VALUE#' and l_cfg.server_code = 'R87_OS',
           'a category overrides the bucket and the folder, keeps the application''s server');
    check_(l_cfg.storage_config_id = line('R87_CAT_B').storage_config_id, 'stored by the category row');
    check_(xxfnd_attach_pkg.resolve_storage('R87_ENTITY', 'R87_CAT_C').bucket_name = 'bkt-app',
           'a category without an override takes the application''s values');
    check_(xxfnd_attach_pkg.resolve_storage('R87_ENTITY', 'R87_CAT_A').storage_type = 'DATABASE',
           'a category may keep its documents in the database');

    xxfnd_attach_pkg.save_category_storage('R87TEST', 'R87_CAT_C', 'R87_SP', p_site => 'site-c');
    check_(line('R87_CAT_C').state like 'INCOMPLETE%' and line('R87_CAT_C').incomplete_reason like '%library%',
           'another server for a category: SharePoint needs the site and library');
    xxfnd_attach_pkg.save_category_storage('R87TEST', 'R87_CAT_C', 'R87_SP', p_site => 'site-c', p_library => 'lib-c',
                                           p_bucket => 'ignored');
    l_cfg := xxfnd_attach_pkg.resolve_storage('R87_ENTITY', 'R87_CAT_C');
    check_(l_cfg.storage_type = 'SHAREPOINT' and l_cfg.sharepoint_site_id = 'site-c' and l_cfg.sharepoint_drive_id = 'lib-c'
           and l_cfg.bucket_name = 'bkt-app',
           'a category overrides the server, site and library (' || l_cfg.storage_type || ')');

    xxfnd_integration_pkg.save_server('R87_OS', 'R87 Object Storage', 'OBJECT_STORAGE', 'XXFND_GRAPH_CRED',
                                      p_oci_region => 'eu-frankfurt-1', p_oci_namespace => 'r87ns', p_enabled_flag => 'N');
    check_(xxfnd_attach_pkg.resolve_storage('R87_ENTITY', 'R87_CAT_B').storage_type = 'DATABASE'
           and line('R87_CAT_B').incomplete_reason = 'the server is disabled',
           'a disabled server: incomplete - using database');
    xxfnd_integration_pkg.save_server('R87_OS', 'R87 Object Storage', 'OBJECT_STORAGE', 'XXFND_GRAPH_CRED',
                                      p_oci_region => 'eu-frankfurt-1', p_oci_namespace => 'r87ns');

    expect_error(-20333, 'storage of an application that is not registered is refused',
                 q'~begin xxfnd_attach_pkg.save_app_storage('NO_SUCH_APP', null); end;~');
    expect_error(-20334, 'an integration server is not a storage server',
                 q'~begin xxfnd_attach_pkg.save_app_storage('R87TEST', 'R87_REST'); end;~');
    expect_error(-20335, 'a category of another application is refused',
                 q'~begin xxfnd_attach_pkg.save_category_storage('R87TEST', 'R87_CAT_X', null); end;~');
    expect_error(-1, 'only one enabled rule per application and category',
                 q'~begin insert into xxfnd_storage_config (application_code, category_code, storage_type, enabled_flag)
                          values ('R87TEST', 'R87_CAT_B', 'DATABASE', 'Y'); end;~');

    ---------------------------------------------------------------- conversion of the old rules (29 above)
    select count(*) into l_n from xxfnd_storage_config
     where entity_name = 'R87_ENTITY' and category_code = 'R87_CAT_A'
       and server_code = 'UCM_MAIN' and application_code = 'R87TEST' and enabled_flag = 'N';
    check_(l_n = 1, 'an old rule whose place is taken: converted (server, application) and disabled, not deleted');
    l_st := line('R87_CAT_D');
    check_(l_st.server_code = 'UCM_MAIN' and l_st.security_group = 'SG_OLD_D' and l_st.folder = '/old/#PK1_VALUE#',
           'an old entity rule becomes the category override of the entity''s application');
    select count(*) into l_n from xxfnd_storage_config where server_code is null and endpoint_code is not null;
    check_(l_n = 0, 'every old rule is converted (' || l_n || ' left)');
    select count(*) into l_n from xxfnd_documents
     where storage_type in ('UCM', 'SHAREPOINT', 'OBJECT_STORAGE') and server_code is null;
    check_(l_n = 0, 'every stored document knows its server (' || l_n || ' without)');
    select count(*) into l_n from xxfnd_integration_purposes
     where capture_method = 'API' and rest_source_static_id is null and server_code is null;
    check_(l_n = 0, 'every API purpose has a REST Data Source or a server');

    ---------------------------------------------------------------- purposes
    begin
        xxfnd_integration_pkg.save_purpose('R87_TEST', 'R87 purpose', 'R87TEST', 'MANUAL', null, null, 'Y');
    exception
        when others then
            if sqlcode <> -20343 then raise; end if;   -- a re-run: the purpose exists
    end;
    xxfnd_integration_pkg.save_purpose('R87_TEST', 'R87 purpose', 'R87TEST', 'API', 'R87_REST', null);
    select max(server_code) into l_v from xxfnd_integration_purposes where purpose_code = 'R87_TEST';
    check_(l_v = 'R87_REST', 'a purpose picks its server');
    expect_error(-20343, 'a purpose code is created once',
                 q'~begin xxfnd_integration_pkg.save_purpose('R87_TEST', 'x', null, 'MANUAL', null, null, 'Y'); end;~');
    expect_error(-2290, 'an API purpose needs a REST Data Source or a server',
                 q'~begin xxfnd_integration_pkg.save_purpose('R87_TEST', 'x', 'R87TEST', 'API', null, null); end;~');
    expect_error(-20342, 'a server in use cannot be deleted',
                 q'~begin xxfnd_integration_pkg.delete_server('R87_REST'); end;~');
    commit;
end;
/
