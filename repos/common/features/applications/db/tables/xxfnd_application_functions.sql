--------------------------------------------------------------------------------
-- 09d XXFND_APPLICATION_PKG - the Applications component of Platform (release 80: one package).
--   Release 72/73: XXFND_APPLICATION_FUNCTIONS (per application and common function: managed in the application).
--   Release 73: setup types (two levels like profile options: the instance and an application; XXFND_SETUP_TYPES,
--   XXFND_SETUP_TYPE_APPS) - the tables move here from 21c in release 80, created only when missing.
--   Release 80 merges XXFND_APP_FUNCTION_PKG, XXFND_SETUP_TYPE_PKG and XXFND_ADMIN_SCOPE_PKG into
--   XXFND_APPLICATION_PKG (the old packages are dropped by 21c; old callers break on purpose: no wrappers).
--   The scope policies and <table>_SC triggers are (re)created by 16i, the <table>_LV triggers by 21c.
--   Release 87: the menu of every application (XXFND_APP_MENU_ENTRIES, made by ONBOARD, read through XXFND_APP_MENU_V);
--   the caller rule of every registration routine (REGISTERED_CODE: an application changes only its own rows); the
--   setup of another application is hidden from an application (scope policy, SQL issued by the application).
--   COMMON only. Idempotent (release 69 rule: CREATE_TABLE only when missing; changes as checked steps).
--------------------------------------------------------------------------------
begin
    if xxfnd_ddl_pkg.create_table('XXFND_APPLICATION_FUNCTIONS', q'~create table xxfnd_application_functions (
    application_code       varchar2(30)   not null,
    feature_code           varchar2(30)   not null,
    enabled_flag           varchar2(1)    default 'N' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_application_functions_pk primary key (application_code, feature_code),
    constraint xxfnd_application_functions_fk1 foreign key (application_code)
        references xxfnd_applications (application_code) on delete cascade,
    constraint xxfnd_application_functions_fk2 foreign key (feature_code)
        references xxfnd_features (feature_code) on delete cascade,
    constraint xxfnd_application_functions_ck1 check (enabled_flag in ('Y','N'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_application_functions is 'Common functions (COMMON admin features) switched on per application by IT; XXFND_APPLICATION_PKG.IS_MANAGED.'~');
    end if;
    -- release 73: no "Available" switch any more (every common function works for every application); instead
    -- IT lets an application's administrators maintain the function's setup for their application themselves
    xxfnd_ddl_pkg.add_column('XXFND_APPLICATION_FUNCTIONS', 'MANAGED_IN_APP_FLAG', q'~varchar2(1) default 'N' not null~');
    xxfnd_ddl_pkg.add_constraint('XXFND_APPLICATION_FUNCTIONS', 'XXFND_APPLICATION_FUNCTIONS_CK2',
                                 q'~check (managed_in_app_flag in ('Y','N'))~');
    xxfnd_ddl_pkg.drop_constraint('XXFND_APPLICATION_FUNCTIONS', 'XXFND_APPLICATION_FUNCTIONS_CK1');
    xxfnd_ddl_pkg.drop_column('XXFND_APPLICATION_FUNCTIONS', 'ENABLED_FLAG');
    xxfnd_ddl_pkg.run(q'~comment on table xxfnd_application_functions is 'Common functions per application: MANAGED_IN_APP_FLAG Y = the application''s administrators maintain its setup for their application (XXFND_APPLICATION_PKG.IS_MANAGED).'~');
    xxfnd_schema_pkg.create_who_trigger('XXFND_APPLICATION_FUNCTIONS');
end;
/
--------------------------------------------------------------------------------
-- 21b Application functions (release 71) - the switches. COMMON only (XXFUSION), after 21. The table and
--   XXFND_APPLICATION_PKG are in 09d (release 72; release 80: XXFND_APPLICATION_PKG).
--   IT registers the applications (XXFND_APPLICATIONS, page 160/161). Every common function works for every
--   application (release 73: no "Available" switch). Per application and function, IT decides whether the
--   application's administrators maintain the function's setup for their application from the application's own
--   menu (XXFND_APPLICATION_FUNCTIONS.MANAGED_IN_APP_FLAG, XXFND_APPLICATION_PKG.IS_MANAGED).
-- Idempotent (release 69 rule: CREATE_TABLE only when missing; changes as checked steps).
--------------------------------------------------------------------------------
-- every registered application has its switches (not managed in the application until IT switches one on)
begin
    xxfnd_util_pkg.set_install_mode(true);
    -- not a common function (any more): no switch
    delete from xxfnd_application_functions
     where feature_code not in (select column_value from table(xxfnd_application_pkg.common_functions));
    for a in (select application_code from xxfnd_applications) loop
        xxfnd_application_pkg.set_apex_id(a.application_code);   -- release 73: APEX ID known before the first sign-in
        xxfnd_application_pkg.ensure_rows(a.application_code);
    end loop;
    xxfnd_workflow_pkg.sync_processes;   -- release 73: the workflow processes and their switches (09e)
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
