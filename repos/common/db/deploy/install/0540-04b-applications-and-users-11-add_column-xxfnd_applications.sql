
-- release 54: the database schema of each application. Its own objects live there; the shared XXFND_ objects
-- live only in the COMMON application's schema (XXFUSION), and each application schema reaches them through
-- synonyms and grants (xxfnd_share_pkg).
begin
    xxfnd_ddl_pkg.add_column('XXFND_APPLICATIONS', 'SCHEMA_NAME', 'varchar2(128)');
end;
/
comment on column xxfnd_applications.schema_name is 'Database schema of the application''s own objects (KYC: XXCUS; COMMON: XXFUSION, which owns the shared XXFND_ objects).';
update xxfnd_applications set schema_name = user    where application_code = 'COMMON' and schema_name is null;
-- release 86: no KYC default any more (onboarding takes an application's schema from its APEX parsing schema)
commit;
