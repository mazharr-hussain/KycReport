
-- release 79: every user has a language preference (lookup LANGUAGE, default English); notifications use the wording
-- in that language and fall back to English
begin
    xxfnd_ddl_pkg.add_column('XXFND_USERS', 'LANGUAGE_CODE', q'~varchar2(10) default 'en' not null~');
end;
/
comment on column xxfnd_users.language_code is 'Language of the user''s notifications (lookup LANGUAGE: en, ar); default English.';

declare
    procedure run(p_sql in varchar2) is
    begin
        execute immediate p_sql;
    exception
        when others then
            -- ORA-02275 / ORA-02261 / ORA-01451 / ORA-00955: the constraint / index already exists or the column is already nullable
            if sqlcode not in (-2275, -2261, -1451, -955) then
                raise;
            end if;
    end run;
begin
    -- roles and grants of the shared module refer to the application and the user
    -- release 47: internal key from the sequence; the APEX ID in its own column; the alias identifies the app
    xxfnd_ddl_pkg.add_column('XXFND_APPLICATIONS', 'APEX_APPLICATION_ID', 'number');
    run('alter table xxfnd_applications modify (application_id default on null xxfnd_applications_s.nextval)');
    run('alter table xxfnd_applications add constraint xxfnd_applications_uk2 unique (apex_app_alias)');
    xxfnd_ddl_pkg.add_column('XXFND_ROLES', 'APPLICATION_ID', 'number');
    xxfnd_ddl_pkg.add_column('XXFND_USER_ROLES', 'USER_ID', 'number');
    run('alter table xxfnd_user_roles modify (employee_id null)');
    run('alter table xxfnd_roles add constraint xxfnd_roles_fk1 foreign key (application_id) references xxfnd_applications (application_id)');
    run('alter table xxfnd_user_roles add constraint xxfnd_user_roles_fk3 foreign key (user_id) references xxfnd_users (user_id)');
    run('create index xxfnd_roles_n2 on xxfnd_roles (application_id)');
    run('create index xxfnd_user_roles_n3 on xxfnd_user_roles (user_id)');
    -- one open-ended grant per user and role
    -- ORA-02264: name already used by an existing constraint
    begin
        execute immediate 'alter table xxfnd_user_roles add constraint xxfnd_user_roles_ck3 check (user_id is not null) enable novalidate';
    exception when others then if sqlcode <> -2264 then raise; end if;
    end;
    run('create unique index xxfnd_user_roles_u2 on xxfnd_user_roles ('
        || 'case when end_date_active is null and user_id is not null then user_id end, '
        || 'case when end_date_active is null and user_id is not null then role_code end)');
    -- release 76: the grants belong to the user (U2); the employee index U1 refused the same role to a second LOCAL user
    -- (no employee) - checked drop, nothing to do when it is gone
    xxfnd_ddl_pkg.drop_index('XXFND_USER_ROLES_U1');
end;
/

comment on column xxfnd_applications.apex_application_id is 'APEX application ID in this environment (may differ between DEV / TEST / PROD); set at sign-in from the alias.';

-- release 86: COMMON no longer registers any business application here (it used to add the KYC row). Each
-- application is onboarded by IT (Applications, or apex/db/admin/onboard-application.sql: XXFND_APPLICATION_PKG.ONBOARD);
-- a row that exists already is kept as it is.

-- existing roles belong to the application of their code
update xxfnd_roles r
   set r.application_id = (select a.application_id from xxfnd_applications a where a.application_code = r.application_code)
 where r.application_id is null
   and exists (select 1 from xxfnd_applications a where a.application_code = r.application_code);

-- every employee with a grant becomes an SSO user, and the grants move to the user
insert into xxfnd_users (user_name, user_type, employee_id, full_name, email_address, enabled_flag,
                         start_date_active, end_date_active,
                         created_by, creation_date, last_updated_by, last_update_date)
select upper(e.user_name), 'SSO', e.employee_id, e.full_name, e.email_address, e.enabled_flag,
       e.start_date_active, e.end_date_active, 'INSTALL', systimestamp, 'INSTALL', systimestamp
  from xxhr_employees e
 where exists (select 1 from xxfnd_user_roles ur where ur.employee_id = e.employee_id)
   and not exists (select 1 from xxfnd_users u where u.employee_id = e.employee_id)
   and not exists (select 1 from xxfnd_users u where u.user_name = upper(e.user_name));

update xxfnd_user_roles ur
   set ur.user_id = (select u.user_id from xxfnd_users u where u.employee_id = ur.employee_id)
 where ur.user_id is null and ur.employee_id is not null;
commit;
