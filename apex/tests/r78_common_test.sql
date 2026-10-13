-- Release 78 checks (run as XXFUSION): DROP_OBJECT, the six COMMON modules, Approval Setup and Optional Features as
-- features of their own. Data changes are rolled back at the end; the test view is dropped by DROP_OBJECT itself.
set serveroutput on feedback off
create or replace view xxfnd_r78_test_v as select 1 as n from dual;
declare
    l_n number;
    l_v varchar2(4000);
    procedure check_(p_ok in boolean, p_text in varchar2) is
    begin
        dbms_output.put_line(case when p_ok then 'PASS ' else 'FAIL ' end || p_text);
    end check_;
begin
    -- DROP_OBJECT: drops the view, records its DDL, a second call does nothing; tables are refused
    xxfnd_ddl_pkg.drop_object('XXFND_R78_TEST_V', 'VIEW');
    select count(*) into l_n from user_objects where object_name = 'XXFND_R78_TEST_V';
    check_(l_n = 0, 'DROP_OBJECT dropped the view');
    select count(*) into l_n from xxfnd_dropped_objects
     where object_name = 'XXFND_R78_TEST_V' and object_type = 'VIEW' and dbms_lob.instr(object_ddl, 'XXFND_R78_TEST_V') > 0;
    check_(l_n >= 1, 'its DDL is recorded in XXFND_DROPPED_OBJECTS');
    select count(*) into l_n from xxfnd_dropped_objects where object_name = 'XXFND_R78_TEST_V';
    xxfnd_ddl_pkg.drop_object('XXFND_R78_TEST_V', 'VIEW');
    select count(*) into l_v from xxfnd_dropped_objects where object_name = 'XXFND_R78_TEST_V';
    check_(to_number(l_v) = l_n, 're-run: a missing object is not dropped or recorded again');
    begin
        xxfnd_ddl_pkg.drop_object('XXFND_FEATURES', 'TABLE');
        check_(false, 'DROP_OBJECT refuses a table');
    exception
        when others then
            check_(sqlcode = -20009, 'DROP_OBJECT refuses a table (tables keep their data)');
    end;
    delete from xxfnd_dropped_objects where object_name = 'XXFND_R78_TEST_V';

    -- the six modules
    select listagg(lookup_code, ',') within group (order by display_sequence) into l_v
      from xxfnd_lookup_values where lookup_type = 'XXFND_MODULE' and enabled_flag = 'Y';
    check_(l_v = 'PLATFORM,SECURITY,REFERENCE_DATA,DOCUMENTS_RECORDS,WORKFLOW,INTEGRATIONS', 'six modules in order: ' || l_v);
    select count(*) into l_n from xxfnd_features f
     where f.admin_flag = 'Y' and f.application_id = (select application_id from xxfnd_applications where application_code = 'COMMON')
       and f.feature_group not in (select lookup_code from xxfnd_lookup_values where lookup_type = 'XXFND_MODULE');
    check_(l_n = 0, 'every COMMON admin feature belongs to a module (' || l_n || ' outside)');
    select count(*) into l_n from xxfnd_features
     where feature_group in ('BASIC_SETUP', 'WORKFLOW_INTEGRATION', 'APPLICATION')
       and application_id = (select application_id from xxfnd_applications where application_code = 'COMMON');
    check_(l_n = 0, 'old groups no longer used by COMMON features (' || l_n || ')');
    select feature_group into l_v from xxfnd_features where feature_code = 'NOTIFICATIONS';
    check_(l_v = 'WORKFLOW', 'Notifications is in Workflow');
    select feature_group into l_v from xxfnd_features where feature_code = 'RETENTION';
    check_(l_v = 'DOCUMENTS_RECORDS', 'Retention is in Documents and Records');

    -- Approval Setup and Optional Features: own feature, pages, the same rights as before
    select max(feature_code) into l_v from xxfnd_feature_pages where app_alias = 'COMMON' and page_id = 148;
    check_(l_v = 'APPROVAL_SETUP', 'page 148 belongs to Approval Setup');
    select max(feature_code) into l_v from xxfnd_feature_pages where app_alias = 'COMMON' and page_id = 10020;
    check_(l_v = 'OPTIONAL_FEATURES', 'page 10020 belongs to Optional Features');
    select count(*) into l_n from xxfnd_role_privileges rp
     where rp.privilege_code like 'WORKFLOW_SETUP.%'
       and not exists (select 1 from xxfnd_role_privileges n
                        where n.role_code = rp.role_code
                          and n.privilege_code = replace(rp.privilege_code, 'WORKFLOW_SETUP.', 'APPROVAL_SETUP.'));
    check_(l_n = 0, 'every role with a Workflow Setup right has the same Approval Setup right');
    select count(*) into l_n from xxfnd_role_privileges rp
     where rp.privilege_code like 'APP_SETTINGS.%'
       and not exists (select 1 from xxfnd_role_privileges n
                        where n.role_code = rp.role_code
                          and n.privilege_code = replace(rp.privilege_code, 'APP_SETTINGS.', 'OPTIONAL_FEATURES.'));
    check_(l_n = 0, 'every role with an Application Settings right has the same Optional Features right');
    select max(feature_code) into l_v from xxfnd_feature_pages where app_alias = 'COMMON' and page_id = 164;
    check_(l_v = 'APPLICATIONS', 'Subscriptions (164) is a page of Applications');

    rollback;
end;
/
