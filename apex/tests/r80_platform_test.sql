-- Release 80 checks (run as XXFUSION): C1 Platform and C3 Reference Data - one package per component
-- (XXFND_APPLICATION_PKG, XXFND_APP_SETTING_PKG, XXFND_LOOKUP_PKG, XXFND_DFF_PKG), scope policies and level
-- triggers on the new package, unused views dropped, setup types saved by the package. Changes are rolled back.
set serveroutput on feedback off
declare
    l_n number;
    l_v varchar2(4000);
    procedure check_(p_ok in boolean, p_text in varchar2) is
    begin
        dbms_output.put_line(case when p_ok then 'PASS ' else 'FAIL ' end || p_text);
    end check_;
begin
    -- merged packages and unused views are gone; nothing invalid
    select count(*) into l_n from user_objects
     where object_name in ('XXFND_SETUP_TYPE_PKG', 'XXFND_ADMIN_SCOPE_PKG', 'XXFND_APP_FUNCTION_PKG',
                           'XXFND_DFF_SETUP_PKG', 'XXFND_ADMIN_APPLICATIONS_V', 'XXFND_DF_SEGMENTS_VL');
    check_(l_n = 0, 'merged packages and unused views dropped (' || l_n || ' left)');
    select count(*) into l_n from xxfnd_dropped_objects
     where object_name in ('XXFND_SETUP_TYPE_PKG', 'XXFND_ADMIN_SCOPE_PKG', 'XXFND_APP_FUNCTION_PKG', 'XXFND_DFF_SETUP_PKG');
    -- an upgraded database (it also dropped XXFND_SECURITY_PKG in 79) records the four; a fresh install had none
    select count(*) into l_v from xxfnd_dropped_objects where object_name = 'XXFND_SECURITY_PKG';
    check_((l_v > 0 and l_n >= 4) or (l_v = 0 and l_n = 0), 'their DDL is recorded in XXFND_DROPPED_OBJECTS when they existed (' || l_n || ')');
    select count(*) into l_n from user_objects where status <> 'VALID';
    check_(l_n = 0, 'no invalid object (' || l_n || ')');
    select count(*) into l_n from user_procedures
     where object_name = 'XXFND_UTIL_PKG' and procedure_name in ('LOOKUP_MEANING', 'IS_VALID_LOOKUP', 'ASSERT_LOOKUP');
    check_(l_n = 0, 'lookup helpers left XXFND_UTIL_PKG');

    -- scope policies and level triggers use XXFND_APPLICATION_PKG
    select count(*) into l_n from user_policies
     where policy_name like 'XXFND\_ADMIN\_SCOPE\_%' escape '\' and package <> 'XXFND_APPLICATION_PKG';
    check_(l_n = 0, 'every scope policy calls XXFND_APPLICATION_PKG');
    select count(*) into l_n from user_policies where policy_name like 'XXFND\_ADMIN\_SCOPE\_%' escape '\';
    check_(l_n = 2 * cardinality(xxfnd_application_pkg.scoped_tables), 'read and change policy on every scoped table (' || l_n || ')');
    select count(*) into l_n from user_triggers t
     where t.trigger_name like '%\_LV' escape '\'
       and not exists (select 1 from user_source s where s.name = t.trigger_name and s.type = 'TRIGGER'
                          and lower(s.text) like '%xxfnd_application_pkg.check_level%');
    check_(l_n = 0, 'every level trigger calls XXFND_APPLICATION_PKG.CHECK_LEVEL');

    -- the application package works as the three did
    check_(xxfnd_application_pkg.app_allowed('VALUE_SETS', null) = 'Y', 'setup types: instance-only type allowed for the workspace');
    check_(xxfnd_application_pkg.app_allowed('VALUE_SETS', 'R86TEST') = 'N', 'setup types: instance-only type refused for an application');
    check_(xxfnd_application_pkg.page_type(102) = 'LOOKUPS', 'setup types: the page knows its setup type');
    check_(xxfnd_application_pkg.default_application(null) = 'ALL', 'scope: default application is ALL');
    check_(xxfnd_application_pkg.is_managed('R86TEST', 'LOOKUPS') in ('Y', 'N'), 'functions: managed switch read');
    select count(*) into l_n from table(xxfnd_application_pkg.common_functions);
    check_(l_n > 5, 'functions: the common functions (' || l_n || ')');

    -- page 163: the applications of a setup type saved by the package
    xxfnd_util_pkg.set_install_mode(true);
    xxfnd_application_pkg.save_setup_type_apps('LOOKUPS', 'B', 'N', 'R86TEST');
    select count(*) into l_n from xxfnd_setup_type_apps where setup_type_code = 'LOOKUPS' and application_code = 'R86TEST';
    check_(l_n = 1, 'chosen applications saved');
    xxfnd_application_pkg.save_setup_type_apps('LOOKUPS', 'B', 'Y', 'R86TEST');
    select count(*) into l_n from xxfnd_setup_type_apps where setup_type_code = 'LOOKUPS';
    check_(l_n = 0, 'every application: the list is emptied');
    xxfnd_util_pkg.set_install_mode(false);

    -- lookups and flexfields
    check_(xxfnd_lookup_pkg.lookup_meaning('LANGUAGE', 'en') = 'English', 'lookup meaning from XXFND_LOOKUP_PKG');
    check_(xxfnd_lookup_pkg.is_valid_lookup('LANGUAGE', 'ar'), 'lookup value is active');
    begin
        xxfnd_lookup_pkg.assert_lookup('LANGUAGE', 'xx', 'Language');
        check_(false, 'an invalid value is refused');
    exception
        when others then
            check_(sqlcode = -20100, 'an invalid value is refused (ORA-20100)');
    end;
    select count(*) into l_n from user_procedures
     where object_name = 'XXFND_DFF_PKG' and procedure_name in ('CHECK_SEGMENT', 'CHECK_FLEXFIELD', 'GENERATE_DFV_VIEW',
                                                               'GENERATE_ALL_DFV_VIEWS', 'SAVE_FLEXFIELD_NAME');
    check_(l_n = 5, 'flexfield setup procedures in XXFND_DFF_PKG');
    select count(*) into l_n from user_views v
     where v.view_name like '%\_DFV' escape '\'
       and not exists (select 1 from user_tables t where t.table_name || '_DFV' = v.view_name);
    check_(l_n = 0, 'no reporting view of another schema''s table left in XXFUSION');
    select max(descriptive_flexfield_code) into l_v from xxfnd_df_flexfields;
    if l_v is not null then
        xxfnd_dff_pkg.save_flexfield_name(l_v, 'R80 test name');
        select max(flexfield_name) into l_v from xxfnd_df_flexfields_tl where descriptive_flexfield_code = l_v and language_code = 'en';
        check_(l_v = 'R80 test name', 'flexfield name saved by the package');
    end if;

    -- settings package: refused without the privilege (no APEX session = no privilege)
    begin
        xxfnd_app_setting_pkg.set_value('COMMON', 'X', 'Y');
        check_(false, 'settings: refused without the privilege');
    exception
        when others then
            check_(sqlcode = -20151, 'settings: refused without the privilege (ORA-20151)');
    end;
    rollback;
end;
/
