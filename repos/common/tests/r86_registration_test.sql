-- Release 86 checks, part A (run as XXFUSION): registration routines, onboarding, the application switches and
-- deletion, MOVE_DOCUMENTS.
-- Needs the APEX applications 860 "R86 Onboarding Test" (alias R86TEST) and 861 "R86 Delete Test" (alias R86DEL) of
-- the workspace XXCUS, parsing schema XXCUS (empty test applications made by apex/tests/r86_test_apps.sql as XXCUS).
-- Its rows stay (the user keeps test data): application R86TEST with its R86_* setup rows, the table R86_DFF_TEST and
-- two test records' documents. R86DEL is registered and deleted again by each run.
set serveroutput on feedback off
declare
    l_n      number;
    l_n2     number;
    l_txt    varchar2(4000);
    l_stamp  varchar2(30) := to_char(systimestamp, 'YYYYMMDDHH24MISSFF3');
    l_doc    number;
    l_att    number;
    l_rule   number;
    l_flag   varchar2(1);
    l_common number;
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
            check_(sqlcode = p_code, p_text || ' (' || sqlcode || case when sqlcode <> p_code then ' ' || sqlerrm end || ')');
    end expect_error;
    function cnt(p_sql in varchar2) return number is
        l_c number;
    begin
        execute immediate p_sql into l_c;
        return l_c;
    end cnt;
begin
    apex_util.set_workspace('XXCUS');
    select max(apex_application_id) into l_common from xxfnd_applications where application_code = 'COMMON';
    select count(*) into l_n from user_objects where status <> 'VALID';
    check_(l_n = 0, 'no invalid object (' || l_n || ')');

    ---------------------------------------------------------------- onboarding
    expect_error(-20181, 'an APEX application that is not in the workspace is refused',
                 q'~begin xxfnd_application_pkg.onboard(999999, 'R86BAD'); end;~');
    expect_error(-20182, 'an APEX application registered under another code is refused',
                 'begin xxfnd_application_pkg.onboard(' || l_common || q'~, 'R86X'); end;~');
    expect_error(-20183, 'an application code that is not a code is refused',
                 q'~begin xxfnd_application_pkg.save_application('1 bad', 860); end;~');
    -- the first run makes the application; a later run of this test is a re-run of the onboarding
    select count(*) into l_n from xxfnd_applications where application_code = 'R86TEST';
    select max(workflow_enabled_flag) into l_txt from xxfnd_workflow_processes where application_code = 'R86TEST' and process_code = 'RFI';
    xxfnd_application_pkg.onboard(860, 'r86test', 'Release 86 onboarding test', 'Y', 'ADMIN');
    commit;
    select max(workflow_enabled_flag) into l_flag from xxfnd_workflow_processes where application_code = 'R86TEST' and process_code = 'RFI';
    check_(l_flag = case when l_n = 0 then 'N' else l_txt end,
           case when l_n = 0 then 'the shared RFI process starts off' else 'a re-run keeps the RFI process switch' end);
    select count(*) into l_n from xxfnd_applications
     where application_code = 'R86TEST' and apex_application_id = 860 and apex_app_alias = 'R86TEST'
       and application_name = 'R86 Onboarding Test' and schema_name = 'XXCUS';
    check_(l_n = 1, 'onboarding registers the application with its name, alias and schema from APEX');
    select count(*) into l_n from xxfnd_application_functions where application_code = 'R86TEST';
    select count(*) into l_n2 from xxfnd_application_functions where application_code = 'R86TEST' and managed_in_app_flag = 'N';
    check_(l_n > 0 and l_n = l_n2, 'one row per common function, none managed in the application (' || l_n || ')');
    select count(*) into l_n from xxfnd_roles where role_code = 'R86TEST_ADMIN' and application_code = 'R86TEST';
    check_(l_n = 1, 'the role R86TEST_ADMIN is made');
    select count(*) into l_n from xxfnd_user_roles_v where user_name = 'ADMIN' and role_code = 'R86TEST_ADMIN' and active_flag = 'Y';
    check_(l_n = 1, 'the administrator user holds it');
    -- an administrator changes the registration; a re-run keeps it
    xxfnd_application_pkg.save_application('R86TEST', 860, 'Changed by the administrator', 'Y', 'N');
    xxfnd_workflow_pkg.set_process_enabled('R86TEST', 'RFI', 'Y');
    xxfnd_application_pkg.onboard(860, 'R86TEST', 'Another description', 'Y', 'ADMIN');
    commit;
    select count(*) into l_n from xxfnd_applications
     where application_code = 'R86TEST' and description = 'Changed by the administrator' and email_enabled_flag = 'N';
    check_(l_n = 1, 'a re-run keeps the description and the e-mail switch the administrator set');
    select max(workflow_enabled_flag) into l_flag from xxfnd_workflow_processes where application_code = 'R86TEST' and process_code = 'RFI';
    check_(l_flag = 'Y', 'a re-run keeps the process switch');
    select count(*) into l_n from xxfnd_roles where role_code = 'R86TEST_ADMIN';
    select count(*) into l_n2 from xxfnd_user_roles where role_code = 'R86TEST_ADMIN' and end_date_active is null;
    check_(l_n = 1 and l_n2 = 1, 'a re-run adds no second role or grant');

    ---------------------------------------------------------------- an application that is not registered is refused
    for t in (select column_value blk from table(apex_t_varchar2(
        q'~begin xxfnd_privilege_pkg.register_feature('R86NOPE', 'R86_NOPE', 'x'); end;~',
        q'~begin xxfnd_privilege_pkg.register_feature_page('R86NOPE', 'R86_FEATURE', 1); end;~',
        q'~begin xxfnd_privilege_pkg.register_privilege('R86NOPE', 'R86_FEATURE', 'VIEW'); end;~',
        q'~begin xxfnd_privilege_pkg.register_role('R86NOPE', 'R86_NOPE', 'x'); end;~',
        q'~begin xxfnd_privilege_pkg.add_role_privilege('R86NOPE', 'R86_ROLE', 'R86_FEATURE.VIEW'); end;~',
        q'~begin xxfnd_privilege_pkg.register_sod_rule('R86NOPE', 'R86_ROLE', 'R86_ROLE2'); end;~',
        q'~begin xxfnd_vpd_pkg.register_data_rule('R86NOPE', 'R86_ROLE', 'R86_DFF_TEST', 'ALL_ROWS'); end;~',
        q'~begin xxfnd_lookup_pkg.register_lookup_type('R86NOPE', 'R86_NOPE', 'x'); end;~',
        q'~begin xxfnd_lookup_pkg.register_lookup_value('R86NOPE', 'R86_LOOKUP', 'Z', 'x'); end;~',
        q'~begin xxfnd_dff_pkg.register_value_set('R86NOPE', 'R86_NOPE', 'x'); end;~',
        q'~begin xxfnd_dff_pkg.register_flexfield('R86NOPE', 'R86_NOPE', 'R86_DFF_TEST', 'ID', 'x'); end;~',
        q'~begin xxfnd_dff_pkg.register_context('R86NOPE', 'R86_DFF', 'X', 'x'); end;~',
        q'~begin xxfnd_attach_pkg.register_entity('R86NOPE', 'R86_NOPE', 'R86_DFF_TEST', 'ID', 'x'); end;~',
        q'~begin xxfnd_attach_pkg.register_category('R86NOPE', 'R86_NOPE', 'x'); end;~',
        q'~begin xxfnd_attach_pkg.register_attachment_page('R86NOPE', 'R86_NOPE', 'x', 2, 'B', 'b', 'R86_ENTITY', 'P2_ID'); end;~',
        q'~begin xxfnd_notify_pkg.register_template('R86NOPE', 'R86_NOPE', 's', 'm'); end;~',
        q'~begin xxfnd_workflow_pkg.register_task_setting('R86NOPE', 'R86_NOPE'); end;~',
        q'~begin xxfnd_approval_rule_pkg.register_default_rule('R86NOPE', 'R86_APPROVAL', 'x'); end;~',
        q'~begin xxfnd_approval_pkg.register_config_table('R86NOPE', 'R86_NOPE'); end;~',
        q'~begin xxfnd_integration_pkg.register_purpose('R86NOPE', 'R86_NOPE', 'x'); end;~',
        q'~begin xxfnd_workflow_pkg.set_process_enabled('R86NOPE', 'RFI', 'Y'); end;~',
        q'~begin xxfnd_application_pkg.set_enabled('R86NOPE', 'Y'); end;~',
        q'~begin dbms_output.put_line(xxfnd_application_pkg.delete_blocker('R86NOPE')); end;~'))) loop
        expect_error(-20180, 'refused for an unregistered application: ' || regexp_substr(t.blk, 'xxfnd_\w+\.\w+'), t.blk);
    end loop;

    ---------------------------------------------------------------- security: features, pages, privileges, roles, SoD, data rules
    for i in 1 .. 2 loop
        xxfnd_privilege_pkg.register_feature('R86TEST', 'R86_FEATURE', 'R86 Feature', 'BUSINESS', 10, 'N', 1, 'fa-star', 'Release 86 test feature.');
        xxfnd_privilege_pkg.register_privilege('R86TEST', 'R86_FEATURE', 'VIEW');
        xxfnd_privilege_pkg.register_privilege('R86TEST', 'R86_FEATURE', 'MANAGE');
        xxfnd_privilege_pkg.register_feature_page('R86TEST', 'R86_FEATURE', 1, 'Home', 10);
        xxfnd_privilege_pkg.register_role('R86TEST', 'R86_ROLE', 'R86 Role');
        xxfnd_privilege_pkg.register_role('R86TEST', 'R86_ROLE2', 'R86 Second Role');
        xxfnd_privilege_pkg.add_role_privilege('R86TEST', 'R86_ROLE', 'R86_FEATURE.VIEW');
        xxfnd_privilege_pkg.register_sod_rule('R86TEST', 'R86_ROLE2', 'R86_ROLE', 'SAME_RECORD', 'Release 86 test');
        xxfnd_vpd_pkg.register_data_rule('R86TEST', 'R86_ROLE', 'R86_DFF_TEST', 'OWN_RECORDS', 'CREATED_BY');
    end loop;
    commit;
    check_(cnt(q'~select count(*) from xxfnd_features f join xxfnd_applications a on a.application_id = f.application_id
                 where f.feature_code = 'R86_FEATURE' and a.application_code = 'R86TEST' and f.home_page_id = 1~') = 1,
           'REGISTER_FEATURE adds the feature once, for the application');
    check_(cnt(q'~select count(*) from xxfnd_privileges where feature_code = 'R86_FEATURE'~') = 2,
           'REGISTER_PRIVILEGE adds each privilege once');
    check_(cnt(q'~select count(*) from xxfnd_feature_pages where app_alias = 'R86TEST' and page_id = 1 and feature_code = 'R86_FEATURE'~') = 1,
           'REGISTER_FEATURE_PAGE maps the page of the application once');
    check_(cnt(q'~select count(*) from xxfnd_roles where role_code in ('R86_ROLE', 'R86_ROLE2') and application_code = 'R86TEST'~') = 2,
           'REGISTER_ROLE adds each role once');
    check_(cnt(q'~select count(*) from xxfnd_sod_rules where role_code_1 = 'R86_ROLE' and role_code_2 = 'R86_ROLE2'~') = 1,
           'REGISTER_SOD_RULE adds the pair once, in canonical order');
    check_(cnt(q'~select count(*) from xxfnd_data_security_rules where role_code = 'R86_ROLE' and table_name = 'R86_DFF_TEST'~') = 1
           and cnt(q'~select count(*) from xxfnd_data_rule_assignments a join xxfnd_data_security_rules d on d.rule_id = a.rule_id
                     where d.table_name = 'R86_DFF_TEST' and a.role_code = 'R86_ROLE'~') = 1,
           'REGISTER_DATA_RULE adds the rule once, assigned to the role');
    -- additive grants: a second privilege joins the first
    xxfnd_privilege_pkg.add_role_privilege('R86TEST', 'R86_ROLE', 'R86_FEATURE.MANAGE');
    check_(cnt(q'~select count(*) from xxfnd_role_privileges where role_code = 'R86_ROLE' and privilege_code like 'R86_FEATURE.%'~') = 2,
           'ADD_ROLE_PRIVILEGE adds to what the role holds');
    -- what an administrator changed is kept
    update xxfnd_features set feature_name = 'R86 Feature (renamed)' where feature_code = 'R86_FEATURE';
    update xxfnd_roles set role_name = 'R86 Role (renamed)' where role_code = 'R86_ROLE';
    update xxfnd_data_security_rules set column_name = 'LAST_UPDATED_BY' where role_code = 'R86_ROLE' and table_name = 'R86_DFF_TEST';
    xxfnd_privilege_pkg.register_feature('R86TEST', 'R86_FEATURE', 'R86 Feature');
    xxfnd_privilege_pkg.register_role('R86TEST', 'R86_ROLE', 'R86 Role');
    commit;
    check_(cnt(q'~select count(*) from xxfnd_features where feature_code = 'R86_FEATURE' and feature_name = 'R86 Feature (renamed)'~') = 1
           and cnt(q'~select count(*) from xxfnd_roles where role_code = 'R86_ROLE' and role_name = 'R86 Role (renamed)'~') = 1,
           'a re-run keeps the names the administrator changed');
    update xxfnd_features set feature_name = 'R86 Feature' where feature_code = 'R86_FEATURE';
    update xxfnd_roles set role_name = 'R86 Role' where role_code = 'R86_ROLE';
    update xxfnd_data_security_rules set column_name = 'CREATED_BY' where role_code = 'R86_ROLE' and table_name = 'R86_DFF_TEST';
    commit;
    expect_error(-20186, 'a role of another application is refused',
                 q'~begin xxfnd_privilege_pkg.add_role_privilege('R86TEST', 'COMMON_ADMIN', 'R86_FEATURE.VIEW'); end;~');
    expect_error(-20187, 'an unknown privilege is refused',
                 q'~begin xxfnd_privilege_pkg.add_role_privilege('R86TEST', 'R86_ROLE', 'R86_NOPE.VIEW'); end;~');
    -- the onboarding role gets the privileges registered since it was made, on a re-run
    xxfnd_application_pkg.onboard(860, 'R86TEST');
    commit;
    -- (VIEW: MANAGE is taken away below and stays away on later runs of this test)
    check_(cnt(q'~select count(*) from xxfnd_role_privileges where role_code = 'R86TEST_ADMIN' and privilege_code = 'R86_FEATURE.VIEW'~') = 1,
           'a re-run of the onboarding gives the administrator role the privileges registered since');
    delete from xxfnd_role_privileges where role_code = 'R86TEST_ADMIN' and privilege_code = 'R86_FEATURE.MANAGE';
    xxfnd_application_pkg.onboard(860, 'R86TEST');
    commit;
    check_(cnt(q'~select count(*) from xxfnd_role_privileges where role_code = 'R86TEST_ADMIN' and privilege_code = 'R86_FEATURE.MANAGE'~') = 0,
           'a privilege an administrator took from it stays away');

    ---------------------------------------------------------------- lookups
    for i in 1 .. 2 loop
        xxfnd_lookup_pkg.register_lookup_type('R86TEST', 'R86_LOOKUP', 'R86 Lookup', 'E');
        xxfnd_lookup_pkg.register_lookup_value('R86TEST', 'R86_LOOKUP', 'A', 'Alpha', 10, p_meaning_ar => unistr('\0623\0644\0641\0627'));
        xxfnd_lookup_pkg.register_lookup_type('COMMON', 'R86_COMMON_LOOKUP', 'R86 Common Lookup');
    end loop;
    commit;
    check_(cnt(q'~select count(*) from xxfnd_lookup_types where lookup_type = 'R86_LOOKUP' and application_code = 'R86TEST'~') = 1
           and cnt(q'~select count(*) from xxfnd_lookup_values where lookup_type = 'R86_LOOKUP'~') = 1
           and cnt(q'~select count(*) from xxfnd_lookup_values_tl where lookup_type = 'R86_LOOKUP' and language_code = 'ar'~') = 1,
           'REGISTER_LOOKUP_TYPE / _VALUE add the type, the value and its Arabic meaning once');
    check_(cnt(q'~select count(*) from xxfnd_lookup_types where lookup_type = 'R86_COMMON_LOOKUP' and application_code is null~') = 1,
           'a COMMON lookup type is an instance row (no application)');
    update xxfnd_lookup_values set meaning = 'Alpha (changed)' where lookup_type = 'R86_LOOKUP' and lookup_code = 'A';
    xxfnd_lookup_pkg.register_lookup_value('R86TEST', 'R86_LOOKUP', 'A', 'Alpha', 10);
    commit;
    check_(cnt(q'~select count(*) from xxfnd_lookup_values where lookup_type = 'R86_LOOKUP' and meaning = 'Alpha (changed)'~') = 1,
           'a re-run keeps the meaning the administrator changed');
    update xxfnd_lookup_values set meaning = 'Alpha' where lookup_type = 'R86_LOOKUP' and lookup_code = 'A';
    commit;
    expect_error(-20187, 'a value of an unknown lookup type is refused',
                 q'~begin xxfnd_lookup_pkg.register_lookup_value('R86TEST', 'R86_NO_TYPE', 'A', 'x'); end;~');

    ---------------------------------------------------------------- flexfields (test table R86_DFF_TEST, kept)
    select count(*) into l_n from user_tables where table_name = 'R86_DFF_TEST';
    if l_n = 0 then
        execute immediate 'create table r86_dff_test (id number primary key, created_by varchar2(255),
                           attribute_category varchar2(150), attribute1 varchar2(150))';
    end if;
    for i in 1 .. 2 loop
        xxfnd_dff_pkg.register_value_set('R86TEST', 'R86_VS', 'R86 Value Set', 'NONE', 'CHAR', 30);
        xxfnd_dff_pkg.register_flexfield('R86TEST', 'R86_DFF', 'R86_DFF_TEST', 'ID', 'R86 Flexfield', unistr('\062D\0642\0644'));
        xxfnd_dff_pkg.register_context('R86TEST', 'R86_DFF', 'CTX1', 'Context 1', unistr('\0633\064A\0627\0642'));
    end loop;
    commit;
    check_(cnt(q'~select count(*) from xxfnd_value_sets where value_set_code = 'R86_VS' and application_code = 'R86TEST'~') = 1,
           'REGISTER_VALUE_SET adds the value set once');
    check_(cnt(q'~select count(*) from xxfnd_df_flexfields where descriptive_flexfield_code = 'R86_DFF' and application_code = 'R86TEST'~') = 1
           and cnt(q'~select count(*) from xxfnd_df_flexfields_tl where descriptive_flexfield_code = 'R86_DFF'~') = 2
           and cnt(q'~select count(*) from xxfnd_df_contexts where descriptive_flexfield_code = 'R86_DFF' and context_code = 'GLOBAL' and protected_flag = 'Y'~') = 1,
           'REGISTER_FLEXFIELD adds the flexfield, its names (en, ar) and its GLOBAL context once');
    check_(cnt(q'~select count(*) from xxfnd_df_contexts where descriptive_flexfield_code = 'R86_DFF' and context_code = 'CTX1'~') = 1
           and cnt(q'~select count(*) from xxfnd_df_contexts_tl where descriptive_flexfield_code = 'R86_DFF' and context_code = 'CTX1'~') = 1,
           'REGISTER_CONTEXT adds the context and its Arabic name once');
    update xxfnd_df_contexts set context_name = 'Context 1 (changed)' where descriptive_flexfield_code = 'R86_DFF' and context_code = 'CTX1';
    xxfnd_dff_pkg.register_context('R86TEST', 'R86_DFF', 'CTX1', 'Context 1');
    commit;
    check_(cnt(q'~select count(*) from xxfnd_df_contexts where context_code = 'CTX1' and context_name = 'Context 1 (changed)'~') = 1,
           'a re-run keeps the context name the administrator changed');
    update xxfnd_df_contexts set context_name = 'Context 1' where descriptive_flexfield_code = 'R86_DFF' and context_code = 'CTX1';
    commit;
    expect_error(-20190, 'a second flexfield on the same table is refused',
                 q'~begin xxfnd_dff_pkg.register_flexfield('R86TEST', 'R86_DFF2', 'R86_DFF_TEST', 'ID', 'x'); end;~');

    ---------------------------------------------------------------- attachments
    for i in 1 .. 2 loop
        xxfnd_attach_pkg.register_entity('R86TEST', 'R86_ENTITY', 'R86_DFF_TEST', 'ID', 'R86 record', unistr('\0633\062C\0644'));
        xxfnd_attach_pkg.register_category('R86TEST', 'R86_CATEGORY', 'R86 Category', unistr('\0641\0626\0629'),
                                           p_allowed_file_types => ' .PDF, Jpg ');
        xxfnd_attach_pkg.register_attachment_page('R86TEST', 'R86_PAGE', 'R86 page', 1, 'MAIN', 'documents',
                                                  'R86_ENTITY', 'P1_ID', 'Documents');
    end loop;
    commit;
    check_(cnt(q'~select count(*) from xxfnd_document_entities where entity_name = 'R86_ENTITY' and application_code = 'R86TEST'~') = 1
           and cnt(q'~select count(*) from xxfnd_document_entities_tl where entity_name = 'R86_ENTITY'~') = 2,
           'REGISTER_ENTITY adds the entity and its names (en, ar) once');
    check_(cnt(q'~select count(*) from xxfnd_document_categories where category_code = 'R86_CATEGORY' and allowed_file_types = 'pdf,jpg'~') = 1
           and cnt(q'~select count(*) from xxfnd_document_categories_tl where category_code = 'R86_CATEGORY' and language_code = 'ar'~') = 1,
           'REGISTER_CATEGORY adds the category (English) and its Arabic name once');
    check_(cnt(q'~select count(*) from xxfnd_attachment_functions where function_code = 'R86_PAGE' and apex_app_alias = 'R86TEST' and apex_page_id = 1~') = 1
           and cnt(q'~select count(*) from xxfnd_attachment_blocks where function_code = 'R86_PAGE'~') = 1
           and cnt(q'~select count(*) from xxfnd_attachment_blk_entities where function_code = 'R86_PAGE' and entity_name = 'R86_ENTITY'~') = 1,
           'REGISTER_ATTACHMENT_PAGE adds the page, its region and its entity once');
    update xxfnd_attachment_blk_entities set delete_allowed_flag = 'Y' where function_code = 'R86_PAGE';
    xxfnd_attach_pkg.register_attachment_page('R86TEST', 'R86_PAGE', 'R86 page', 1, 'MAIN', 'documents', 'R86_ENTITY', 'P1_ID');
    commit;
    check_(cnt(q'~select count(*) from xxfnd_attachment_blk_entities where function_code = 'R86_PAGE' and delete_allowed_flag = 'Y'~') = 1,
           'a re-run keeps what the administrator allowed');
    update xxfnd_attachment_blk_entities set delete_allowed_flag = 'N' where function_code = 'R86_PAGE';
    commit;
    expect_error(-20191, 'a page registered under another attachment function is refused',
                 q'~begin xxfnd_attach_pkg.register_attachment_page('R86TEST', 'R86_PAGE2', 'x', 1, 'B', 'b', 'R86_ENTITY', 'P1_ID'); end;~');
    expect_error(-20186, 'a category of another application is refused',
                 q'~begin xxfnd_attach_pkg.register_category('COMMON', 'R86_CATEGORY', 'x'); end;~');

    ---------------------------------------------------------------- MOVE_DOCUMENTS
    -- record A: two documents (one with a second version, one removed); record B: one document
    l_att := xxfnd_attach_pkg.add_text('R86_ENTITY', 'A' || l_stamp, 'R86_CATEGORY', 'SHORT_TEXT', 'R86 first', 'Version 1');
    select document_id into l_doc from xxfnd_attached_documents where attached_document_id = l_att;
    insert into xxfnd_documents (category_code, datatype_code, base_document_id, version_number, text_content, upload_status)
    values ('R86_CATEGORY', 'SHORT_TEXT', l_doc, 2, 'Version 2', 'NOT_APPLICABLE') returning document_id into l_n;
    update xxfnd_attached_documents set document_id = l_n where attached_document_id = l_att;
    l_att := xxfnd_attach_pkg.add_text('R86_ENTITY', 'A' || l_stamp, 'R86_CATEGORY', 'SHORT_TEXT', 'R86 second', 'Removed later');
    xxfnd_attach_pkg.remove(l_att);
    l_att := xxfnd_attach_pkg.add_text('R86_ENTITY', 'B' || l_stamp, 'R86_CATEGORY', 'SHORT_TEXT', 'R86 third', 'Of record B');
    select max(seq_num) into l_n2 from xxfnd_attached_documents where entity_name = 'R86_ENTITY' and pk1_value = 'B' || l_stamp;
    xxfnd_attach_pkg.move_documents('r86_entity', 'A' || l_stamp, 'B' || l_stamp);
    commit;
    check_(cnt(q'~select count(*) from xxfnd_attached_documents where entity_name = 'R86_ENTITY' and pk1_value = 'A~' || l_stamp || q'~'~') = 0
           and cnt(q'~select count(*) from xxfnd_attached_documents where entity_name = 'R86_ENTITY' and pk1_value = 'B~' || l_stamp || q'~'~') = 3,
           'MOVE_DOCUMENTS moves every document of the record (the removed one too)');
    check_(cnt(q'~select count(*) from xxfnd_attached_documents ad join xxfnd_documents d on d.document_id = ad.document_id
                 where ad.entity_name = 'R86_ENTITY' and ad.pk1_value = 'B~' || l_stamp || q'~' and d.base_document_id = ~' || l_doc
               || q'~ and d.version_number = 2~') = 1,
           'with its versions (the latest version still hangs off the first)');
    check_(cnt(q'~select min(seq_num) from xxfnd_attached_documents where entity_name = 'R86_ENTITY' and pk1_value = 'B~' || l_stamp
               || q'~' and attached_document_id <> ~' || l_att) > l_n2,
           'the moved documents come after those the record had');
    xxfnd_attach_pkg.move_documents('R86_ENTITY', 'A' || l_stamp, 'B' || l_stamp);
    xxfnd_attach_pkg.move_documents('R86_ENTITY', 'B' || l_stamp, 'B' || l_stamp);
    commit;
    check_(cnt(q'~select count(*) from xxfnd_attached_documents where entity_name = 'R86_ENTITY' and pk1_value = 'B~' || l_stamp || q'~'~') = 3,
           'nothing happens when there is nothing to move');

    ---------------------------------------------------------------- notifications, deadlines, approvals, configuration tables, purposes
    for i in 1 .. 2 loop
        xxfnd_notify_pkg.register_template('R86TEST', 'R86_TEMPLATE', 'R86 subject #X#', 'R86 message', 'Open',
                                           unistr('\0645\0648\0636\0648\0639'), unistr('\0631\0633\0627\0644\0629'), unistr('\0641\062A\062D'));
        xxfnd_workflow_pkg.register_task_setting('R86TEST', 'R86_TASK', 5, 1, 'R86_ROLE', 'Y', 'Release 86 test');
        xxfnd_approval_rule_pkg.register_type('R86_APPROVAL', 'R86TEST', 'R86 approval', null, apex_t_varchar2('DEPT=Department'));
        xxfnd_approval_rule_pkg.register_default_rule('R86TEST', 'R86_APPROVAL', 'R86 default',
            apex_t_varchar2('Manager=ROLE=R86_ROLE', 'Requester check=REQUESTER'), apex_t_varchar2('DEPT=FIN'));
        xxfnd_approval_pkg.register_config_table('R86TEST', 'R86_DFF_TEST', 'Y', 'N');
        xxfnd_integration_pkg.register_purpose('R86TEST', 'R86_PURPOSE', 'R86 purpose');
    end loop;
    commit;
    check_(cnt(q'~select count(*) from xxfnd_notification_templates where template_code = 'R86_TEMPLATE' and application_code = 'R86TEST'~') = 1
           and cnt(q'~select count(*) from xxfnd_notification_templates_tl where template_code = 'R86_TEMPLATE' and language_code = 'ar'~') = 1,
           'REGISTER_TEMPLATE adds the wording (en, ar) once');
    check_(cnt(q'~select count(*) from xxfnd_task_settings where task_definition = 'R86_TASK' and due_days = 5~') = 1,
           'REGISTER_TASK_SETTING adds the deadline settings once');
    check_(cnt(q'~select count(*) from xxfnd_approval_rules where approval_type_code = 'R86_APPROVAL'~') = 1
           and cnt(q'~select count(*) from xxfnd_approval_rule_steps s join xxfnd_approval_rules r on r.rule_id = s.rule_id
                     where r.approval_type_code = 'R86_APPROVAL'~') = 2
           and cnt(q'~select count(*) from xxfnd_approval_rule_conds c join xxfnd_approval_rules r on r.rule_id = c.rule_id
                     where r.approval_type_code = 'R86_APPROVAL' and c.attribute_code = 'DEPT' and c.attribute_value = 'FIN'~') = 1,
           'REGISTER_DEFAULT_RULE adds the rule with its condition and steps once');
    check_(cnt(q'~select count(*) from xxfnd_config_tables where table_name = 'R86_DFF_TEST'~') = 1,
           'REGISTER_CONFIG_TABLE adds the table once');
    check_(cnt(q'~select count(*) from xxfnd_integration_purposes where purpose_code = 'R86_PURPOSE' and approval_status = 'APPROVED'
                 and application_code = 'R86TEST'~') = 1,
           'REGISTER_PURPOSE adds the purpose once (approved from a script)');
    update xxfnd_notification_templates set subject = 'R86 subject (changed)' where template_code = 'R86_TEMPLATE';
    update xxfnd_task_settings set due_days = 9 where task_definition = 'R86_TASK';
    update xxfnd_approval_rules set rule_name = 'R86 default (changed)' where approval_type_code = 'R86_APPROVAL';
    update xxfnd_config_tables set audit_flag = 'N' where table_name = 'R86_DFF_TEST';
    update xxfnd_integration_purposes set purpose_name = 'R86 purpose (changed)' where purpose_code = 'R86_PURPOSE';
    xxfnd_notify_pkg.register_template('R86TEST', 'R86_TEMPLATE', 'R86 subject #X#', 'R86 message');
    xxfnd_workflow_pkg.register_task_setting('R86TEST', 'R86_TASK', 5);
    xxfnd_approval_rule_pkg.register_default_rule('R86TEST', 'R86_APPROVAL', 'R86 default', apex_t_varchar2('Manager=ROLE=R86_ROLE'));
    xxfnd_approval_pkg.register_config_table('R86TEST', 'R86_DFF_TEST');
    xxfnd_integration_pkg.register_purpose('R86TEST', 'R86_PURPOSE', 'R86 purpose');
    commit;
    check_(cnt(q'~select count(*) from xxfnd_notification_templates where template_code = 'R86_TEMPLATE' and subject = 'R86 subject (changed)'~') = 1
           and cnt(q'~select count(*) from xxfnd_task_settings where task_definition = 'R86_TASK' and due_days = 9~') = 1
           and cnt(q'~select count(*) from xxfnd_approval_rules where approval_type_code = 'R86_APPROVAL' and rule_name = 'R86 default (changed)'~') = 1
           and cnt(q'~select count(*) from xxfnd_config_tables where table_name = 'R86_DFF_TEST' and audit_flag = 'N'~') = 1
           and cnt(q'~select count(*) from xxfnd_integration_purposes where purpose_code = 'R86_PURPOSE' and purpose_name = 'R86 purpose (changed)'~') = 1,
           'a re-run keeps the wording, deadlines, rule, audit switch and purpose the administrator changed');
    update xxfnd_notification_templates set subject = 'R86 subject #X#' where template_code = 'R86_TEMPLATE';
    update xxfnd_task_settings set due_days = 5 where task_definition = 'R86_TASK';
    update xxfnd_approval_rules set rule_name = 'R86 default' where approval_type_code = 'R86_APPROVAL';
    update xxfnd_config_tables set audit_flag = 'Y' where table_name = 'R86_DFF_TEST';
    update xxfnd_integration_purposes set purpose_name = 'R86 purpose' where purpose_code = 'R86_PURPOSE';
    commit;
    xxfnd_approval_rule_pkg.register_type('R86_APPROVAL2', 'R86TEST', 'R86 second approval');
    expect_error(-20188, 'an approval step that is not well formed is refused',
                 q'~begin xxfnd_approval_rule_pkg.register_default_rule('R86TEST', 'R86_APPROVAL2', 'x', apex_t_varchar2('Manager=ROLE')); end;~');
    check_(cnt(q'~select count(*) from xxfnd_approval_rules where approval_type_code = 'R86_APPROVAL2'~') = 0,
           'and nothing of that rule is written');
    expect_error(-20187, 'an unknown approval type is refused',
                 q'~begin xxfnd_approval_rule_pkg.register_default_rule('R86TEST', 'R86_NO_TYPE', 'x'); end;~');
    expect_error(-20186, 'a configuration table of another application is refused',
                 q'~begin xxfnd_approval_pkg.register_config_table('R86TEST', 'XXFND_LOOKUP_TYPES'); end;~');

    ---------------------------------------------------------------- switches: processes, rules, the application
    -- release 106: "managed in the application" is retired (SAVE_FUNCTIONS removed, I-059): no switch to test here
    xxfnd_workflow_pkg.set_process_enabled('R86TEST', 'rfi', 'N');
    commit;
    select max(workflow_enabled_flag) into l_flag from xxfnd_workflow_processes where application_code = 'R86TEST' and process_code = 'RFI';
    check_(l_flag = 'N', 'SET_PROCESS_ENABLED switches the process off');
    xxfnd_workflow_pkg.set_process_enabled('R86TEST', 'RFI', 'Y');
    commit;
    select max(workflow_enabled_flag) into l_flag from xxfnd_workflow_processes where application_code = 'R86TEST' and process_code = 'RFI';
    check_(l_flag = 'Y', 'and on again');
    expect_error(-20187, 'an unknown process is refused',
                 q'~begin xxfnd_workflow_pkg.set_process_enabled('R86TEST', 'R86_NO_PROCESS', 'Y'); end;~');
    select min(rule_id) into l_rule from xxfnd_notify_rules;
    select enabled_flag into l_flag from xxfnd_notify_rules where rule_id = l_rule;
    xxfnd_notify_pkg.set_rule_enabled(l_rule, case l_flag when 'Y' then 'N' else 'Y' end);
    check_(cnt('select count(*) from xxfnd_notify_rules where rule_id = ' || l_rule || q'~ and enabled_flag <> '~' || l_flag || q'~'~') = 1,
           'SET_RULE_ENABLED switches a notification rule');
    xxfnd_notify_pkg.set_rule_enabled(l_rule, l_flag);
    commit;
    check_(cnt('select count(*) from xxfnd_notify_rules where rule_id = ' || l_rule || q'~ and enabled_flag = '~' || l_flag || q'~'~') = 1,
           'and back');
    expect_error(-20187, 'an unknown notification rule is refused', 'begin xxfnd_notify_pkg.set_rule_enabled(-1, ''Y''); end;');
    expect_error(-20185, 'COMMON cannot be disabled', q'~begin xxfnd_application_pkg.set_enabled('COMMON', 'N'); end;~');

    ---------------------------------------------------------------- deleting an application
    l_txt := xxfnd_application_pkg.delete_blocker('COMMON');
    check_(l_txt is not null, 'COMMON may not be deleted: ' || l_txt);
    l_txt := xxfnd_application_pkg.delete_blocker('R86TEST');
    check_(l_txt like '%Disable%', 'an enabled application may not be deleted: ' || l_txt);
    xxfnd_application_pkg.set_enabled('R86TEST', 'N');
    commit;
    check_(cnt(q'~select count(*) from xxfnd_applications where application_code = 'R86TEST' and enabled_flag = 'N'~') = 1,
           'SET_ENABLED disables the application');
    l_txt := xxfnd_application_pkg.delete_blocker('R86TEST');
    -- release 88 (C9): only business data blocks the delete (the setup it registered is removed with it)
    check_(l_txt like '%Documents%' and l_txt not like '%Features%' and l_txt not like '%Lookup Types%',
           'a disabled application its business data refers to may not be deleted: ' || l_txt);
    expect_error(-20184, 'DELETE_APPLICATION refuses it', q'~begin xxfnd_application_pkg.delete_application('R86TEST'); end;~');
    xxfnd_application_pkg.set_enabled('R86TEST', 'Y');
    commit;
    -- an application nothing refers to: registered, disabled, deleted (with its function and process rows)
    xxfnd_application_pkg.onboard(861, 'R86DEL', 'Release 86 delete test');
    commit;
    check_(cnt(q'~select count(*) from xxfnd_application_functions where application_code = 'R86DEL'~') > 0
           and cnt(q'~select count(*) from xxfnd_workflow_processes where application_code = 'R86DEL'
                     and process_code = 'RFI' and workflow_enabled_flag = 'N'~') = 1
           and cnt(q'~select count(*) from xxfnd_roles where role_code = 'R86DEL_ADMIN'~') = 1,
           'a new onboarding: standard rows, the shared RFI process off, the administrator role');
    xxfnd_application_pkg.set_enabled('R86DEL', 'N');
    check_(xxfnd_application_pkg.delete_blocker('R86DEL') is null, 'a disabled application nothing refers to may be deleted');
    xxfnd_application_pkg.delete_application('R86DEL');
    commit;
    check_(cnt(q'~select count(*) from xxfnd_applications where application_code = 'R86DEL'~') = 0
           and cnt(q'~select count(*) from xxfnd_application_functions where application_code = 'R86DEL'~') = 0
           and cnt(q'~select count(*) from xxfnd_workflow_processes where application_code = 'R86DEL'~') = 0
           and cnt(q'~select count(*) from xxfnd_roles where role_code = 'R86DEL_ADMIN'~') = 0,
           'DELETE_APPLICATION deletes it with its standard rows and its unused role');

    ---------------------------------------------------------------- in an APEX session the switches need their privileges
    apex_session.create_session(p_app_id => l_common, p_page_id => 1, p_username => 'R86_NOBODY');
    expect_error(-20002, 'SET_ENABLED needs Applications - Manage',
                 q'~begin xxfnd_application_pkg.set_enabled('R86TEST', 'Y'); end;~');
    expect_error(-20002, 'SET_PROCESS_ENABLED needs Applications or Workflow Setup - Manage',
                 q'~begin xxfnd_workflow_pkg.set_process_enabled('R86TEST', 'RFI', 'Y'); end;~');
    expect_error(-20002, 'SET_RULE_ENABLED needs Applications or Notifications - Manage',
                 'begin xxfnd_notify_pkg.set_rule_enabled(' || l_rule || ', ''Y''); end;');
    apex_session.delete_session;
    select count(*) into l_n from user_objects where status <> 'VALID';
    check_(l_n = 0, 'no invalid object at the end (' || l_n || ')');
end;
/
