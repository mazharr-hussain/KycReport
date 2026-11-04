-- Release 89 checks (run as XXFUSION): the Data Model - the feature, COMMON's prefix and groups, another application's
-- objects (R86TEST, schema XXCUS, tables of r89_data_model_apps.sql), keys, indexes, routines, the diagram source, the
-- routines for the prefix and the groups, and the views kept to COMMON. Its rows stay (R86TEST's prefix and group).
-- Needs r86_test_apps.sql / common_test_fixture.sql (R86TEST onboarded) and r89_data_model_apps.sql (as XXCUS).
set serveroutput on feedback off
declare
    l_n    number;
    l_txt  varchar2(4000);
    l_src  clob;
    l_full varchar2(1) := xxfnd_data_model_pkg.full_dictionary;
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
begin
    apex_util.set_workspace('XXCUS');
    select count(*) into l_n from user_objects where status <> 'VALID';
    check_(l_n = 0, 'no invalid object (' || l_n || ')');
    dbms_output.put_line('INFO the views read the ' || case l_full when 'Y' then 'DBA_' else 'ALL_' end || ' dictionary');

    ---------------------------------------------------------------- the feature
    select count(*) into l_n from xxfnd_features where feature_code = 'DATA_MODEL' and admin_flag = 'Y' and home_page_id = 175;
    check_(l_n = 1, 'feature DATA_MODEL (Platform, page 175)');
    select count(*) into l_n from xxfnd_feature_pages where app_alias = 'COMMON' and feature_code = 'DATA_MODEL' and page_id in (175, 176, 177);
    check_(l_n = 3, 'pages 175, 176 and 177 belong to it');
    select count(*) into l_n from xxfnd_role_privileges where role_code = 'COMMON_ADMIN' and privilege_code in ('DATA_MODEL.VIEW', 'DATA_MODEL.MANAGE');
    check_(l_n = 2, 'Common Administrator has View and Manage');
    -- release 106: no managed menu entry per application any more (FN_DATA_MODEL, I-059)

    ---------------------------------------------------------------- COMMON's own objects
    -- release 102: the HR tables (XXHR_) are COMMON's too (I-059)
    select count(*) into l_n from xxfnd_dm_app_scopes where application_code = 'COMMON' and object_prefix = 'XXFND_,XXHR_';
    check_(l_n = 1, 'COMMON''s object prefixes are XXFND_ and XXHR_');
    select count(*) into l_n from xxfnd_dm_objects_v where application_code = 'COMMON' and object_type = 'TABLE';
    check_(l_n >= 76, 'COMMON''s tables are listed (' || l_n || ')');
    select count(*) into l_n from xxfnd_dm_objects_v where application_code = 'COMMON'
       and object_name not like 'XXFND\_%' escape '\' and object_name not like 'XXHR\_%' escape '\';
    check_(l_n = 0, 'only the objects with the prefix');
    select count(*) into l_n from xxfnd_dm_table_groups where application_code = 'COMMON';
    check_(l_n >= 74, 'COMMON''s tables are grouped by module (' || l_n || ')');
    select max(real_columns) into l_txt from xxfnd_dm_indexes_v where index_name = 'XXFND_RFIS_N2';
    check_(l_txt = 'RECIPIENT_USER_NAME', 'a function-based index shows the column it reads (' || l_txt || ')');
    select max(parameters) into l_txt from xxfnd_dm_routines_v where object_name = 'XXFND_APPROVAL_RULE_PKG' and routine_name = 'REGISTER_RULE';
    check_(l_txt like 'p_application_code in varchar2, p_type in varchar2, p_rule_name in varchar2%', 'a routine with its parameters');
    select count(*) into l_n from xxfnd_dm_constraints_v where table_name = 'XXFND_ROLES' and type_code = 'R' and ref_table = 'XXFND_APPLICATIONS';
    check_(l_n = 1, 'a foreign key with the table it refers to');
    select count(*) into l_n from xxfnd_dm_dependencies_v where name = 'XXFND_DATA_MODEL_PKG' and referenced_name = 'XXFND_APPLICATION_PKG';
    check_(l_n > 0, 'the objects a package uses');

    ---------------------------------------------------------------- the diagram source
    l_src := xxfnd_data_model_pkg.erd_source('COMMON');
    check_(l_src like 'erDiagram%' and regexp_like(l_src, 'XXFND_APPLICATIONS (\|\||o\|)--o\{ XXFND_ROLES'), 'the overview has every foreign key');
    l_src := xxfnd_data_model_pkg.erd_source('COMMON', 'Security');
    check_(instr(l_src, 'XXFND_ROLES {') > 0 and instr(l_src, 'ROLE_CODE PK') > 0, 'a group shows its tables with their key columns');
    l_src := xxfnd_data_model_pkg.erd_source('COMMON', null, 'XXFND_RFI_ROUNDS');
    check_(instr(l_src, 'XXFND_RFIS {') > 0 and instr(l_src, 'XXFND_ROLES {') = 0, 'a table shows only its neighbours');

    ---------------------------------------------------------------- another application's objects (schema XXCUS)
    xxfnd_data_model_pkg.set_object_prefix('R86TEST', 'r89_');
    commit;
    select max(object_prefix) into l_txt from xxfnd_dm_app_scopes where application_code = 'R86TEST';
    check_(l_txt = 'R89_', 'SET_OBJECT_PREFIX keeps the prefix in capitals');
    select count(*) into l_n from xxfnd_dm_objects_v where application_code = 'R86TEST' and object_name not like 'R89\_%' escape '\';
    check_(l_n = 0, 'the application''s objects are those with its prefix');
    if l_full = 'Y' then
        select count(*) into l_n from xxfnd_dm_objects_v where application_code = 'R86TEST' and object_type = 'TABLE';
        check_(l_n = 2, 'the tables of the application''s schema are read (' || l_n || ')');
        xxfnd_data_model_pkg.register_table_group('R86TEST', 'R89_PARENT', 'Core');
        xxfnd_data_model_pkg.register_table_group('R86TEST', 'r89_child', 'Core');
        commit;
        l_src := xxfnd_data_model_pkg.erd_source('R86TEST', 'Core');
        check_(instr(l_src, 'R89_PARENT ||--o{ R89_CHILD') > 0 and instr(l_src, 'PARENT_ID PK') > 0
               and instr(l_src, 'IX r89_child_n1') > 0, 'its diagram: keys, the mandatory foreign key, the index');
        xxfnd_data_model_pkg.unregister_table_group('R86TEST', 'R89_CHILD');
        select count(*) into l_n from xxfnd_dm_table_groups where application_code = 'R86TEST';
        check_(l_n = 1, 'UNREGISTER_TABLE_GROUP removes one group row');
        xxfnd_data_model_pkg.register_table_group('R86TEST', 'R89_CHILD', 'Core');
        commit;
    else
        dbms_output.put_line('INFO other schemas need the dictionary grants (apex/db/admin/grant-dictionary-to-xxfusion.sql): skipped');
    end if;
    expect_error(-20187, 'an unknown group row is refused',
                 q'~begin xxfnd_data_model_pkg.unregister_table_group('R86TEST', 'R89_NONE'); end;~');
    l_txt := xxfnd_application_pkg.delete_blocker('R86TEST');
    check_(nvl(l_txt, '#') not like '%Dm %', 'the Data Model rows do not block a delete');

    ---------------------------------------------------------------- the views stay in COMMON
    select count(*) into l_n from user_tab_privs_made where table_name like 'XXFND\_DM\_%\_V' escape '\';
    check_(l_n = 0, 'the dictionary views are granted to no application (' || l_n || ')');
    check_(xxfnd_data_model_pkg.app_visible('R86TEST') = 'Y', 'outside an APEX session every application is visible');
end;
/
