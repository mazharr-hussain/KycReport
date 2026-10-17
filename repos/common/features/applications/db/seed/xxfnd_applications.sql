
-- the common application (the shared module); its APEX ID is set when it is first used
merge into xxfnd_applications t
using (select 'COMMON' application_code, 'Common' application_name, 'COMMON' apex_app_alias from dual) s
   on (t.application_code = s.application_code)
 when not matched then insert (application_code, application_name, apex_app_alias, description,
                               created_by, creation_date, last_updated_by, last_update_date)
                       values (s.application_code, s.application_name, s.apex_app_alias,
                               'Shared module: security, setup (lookups, flexfields, attachments), workflow.',
                               'INSTALL', systimestamp, 'INSTALL', systimestamp);
update xxfnd_applications set schema_name = user    where application_code = 'COMMON' and schema_name is null;
-- release 86: no KYC default any more (onboarding takes an application's schema from its APEX parsing schema)
commit;
