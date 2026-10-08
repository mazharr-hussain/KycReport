--------------------------------------------------------------------------------
-- 21b Application functions (release 72). COMMON only (XXFUSION), after 21.
--   IT registers the applications (XXFND_APPLICATIONS, page 160/161) and switches on, per application, the common
--   functions it may use (XXFND_APPLICATION_FUNCTIONS). The functions are the admin features with a COMMON setup
--   page (Lookups, Flexfields, Attachments, Notifications, Retention, Workflow Setup, Integrations, Users and Access,
--   Roles and Privileges, Data Security, Audit Log, Application Settings); a feature added there gets a switch too.
--   XXFND_APP_FUNCTION_PKG.IS_ENABLED(application, function) - Y / N - is what an application asks before it
--   shows or runs a common function; the COMMON setup forms list only applications with the function on.
-- Idempotent (release 69 rule: CREATE_TABLE only when missing; changes as checked steps).
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
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_application_functions is 'Common functions (COMMON admin features) switched on per application by IT; XXFND_APP_FUNCTION_PKG.IS_ENABLED.'~');
    end if;
    xxfnd_schema_pkg.create_who_trigger('XXFND_APPLICATION_FUNCTIONS');
end;
/

create or replace package xxfnd_app_function_pkg authid definer as
    -- Y when the common function (COMMON admin feature code) is switched on for the application, else N.
    function is_enabled(p_application_code in varchar2, p_feature_code in varchar2) return varchar2;
    -- The same for the running application (its code from XXFND_APPLICATIONS by the APEX alias); Y outside APEX.
    function is_enabled(p_feature_code in varchar2) return varchar2;
    -- One row per common function for the application (switched off), so IT only flips switches. Also called for
    -- every registered application by this script.
    procedure ensure_rows(p_application_code in varchar2);
    -- The common functions: the admin features with a COMMON setup page (not Applications itself).
    function common_functions return apex_t_varchar2;
    -- Registration (page 161): grants on the shared objects to the application's schema and the function rows.
    procedure register_application(p_application_code in varchar2);
end xxfnd_app_function_pkg;
/

create or replace package body xxfnd_app_function_pkg as

    function is_enabled(p_application_code in varchar2, p_feature_code in varchar2) return varchar2 is
        l_flag xxfnd_application_functions.enabled_flag%type;
    begin
        select max(enabled_flag) into l_flag
          from xxfnd_application_functions
         where application_code = upper(p_application_code) and feature_code = upper(p_feature_code);
        return nvl(l_flag, 'N');
    end is_enabled;

    function is_enabled(p_feature_code in varchar2) return varchar2 is
        l_code xxfnd_applications.application_code%type;
    begin
        if v('APP_ALIAS') is null then
            return 'Y';   -- outside APEX (jobs, scripts): the caller decides
        end if;
        select max(application_code) into l_code from xxfnd_applications
         where upper(apex_app_alias) = upper(v('APP_ALIAS'));
        return is_enabled(nvl(l_code, upper(v('APP_ALIAS'))), p_feature_code);
    end is_enabled;

    function common_functions return apex_t_varchar2 is
        l_codes apex_t_varchar2;
    begin
        -- the admin features with a COMMON setup page (not the registration itself)
        select distinct f.feature_code bulk collect into l_codes
          from xxfnd_features f
          join xxfnd_feature_pages fp on fp.feature_code = f.feature_code and fp.app_alias = 'COMMON'
         where f.admin_flag = 'Y' and f.feature_code <> 'APPLICATIONS';
        return l_codes;
    end common_functions;

    procedure ensure_rows(p_application_code in varchar2) is
    begin
        insert into xxfnd_application_functions (application_code, feature_code, enabled_flag)
        select upper(p_application_code), f.feature_code, 'N'
          from xxfnd_features f
         where f.feature_code in (select column_value from table(common_functions))
           and not exists (select 1 from xxfnd_application_functions x
                            where x.application_code = upper(p_application_code) and x.feature_code = f.feature_code);
    end ensure_rows;

    procedure register_application(p_application_code in varchar2) is
        l_schema xxfnd_applications.schema_name%type;
        l_n      pls_integer;
    begin
        select max(schema_name) into l_schema from xxfnd_applications where application_code = upper(p_application_code);
        select count(*) into l_n from all_users where username = upper(l_schema);
        if l_n > 0 and upper(l_schema) <> user then
            xxfnd_share_pkg.grant_to(upper(l_schema));
        end if;
        ensure_rows(p_application_code);
    end register_application;

end xxfnd_app_function_pkg;
/

-- every registered application has its switches; the existing applications keep what they use today (all on)
declare
    l_new pls_integer;
begin
    xxfnd_util_pkg.set_install_mode(true);
    select count(*) into l_new from xxfnd_application_functions;
    -- not a common function (any more): no switch
    delete from xxfnd_application_functions
     where feature_code not in (select column_value from table(xxfnd_app_function_pkg.common_functions));
    for a in (select application_code from xxfnd_applications) loop
        xxfnd_app_function_pkg.ensure_rows(a.application_code);
    end loop;
    if l_new = 0 then
        -- first install of this release: nothing changes for the applications already in use
        update xxfnd_application_functions set enabled_flag = 'Y';
    end if;
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
