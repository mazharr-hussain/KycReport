
-- release 46: a feature belongs to one application (shared access module)
declare
begin
    xxfnd_ddl_pkg.add_column('XXFND_FEATURES', 'APPLICATION_ID', 'number');
    begin
        execute immediate 'alter table xxfnd_features add constraint xxfnd_features_fk1 foreign key (application_id) references xxfnd_applications (application_id)';
    exception when others then if sqlcode not in (-2275, -2264) then raise; end if;
    end;
end;
/
comment on column xxfnd_features.application_id is 'The application (XXFND_APPLICATIONS) the feature belongs to; its privileges and page mappings follow it.';
