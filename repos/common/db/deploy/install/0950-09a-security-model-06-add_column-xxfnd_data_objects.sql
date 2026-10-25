declare
    l_new boolean;
begin
    -- release 102: what DIMENSION_COLUMN holds - CODE (the value code, e.g. FINANCE) or ID (XXHR_ORGANIZATIONS.ORGANIZATION_ID
    -- of the dimension's organization type); access is still assigned by code
    xxfnd_ddl_pkg.add_column('XXFND_DATA_OBJECTS', 'DIMENSION_VALUE_TYPE', q'~varchar2(10) default 'CODE' not null~');
    xxfnd_ddl_pkg.add_constraint('XXFND_DATA_OBJECTS', 'XXFND_DATA_OBJECTS_CK3', q'~check (dimension_value_type in ('CODE','ID'))~');
    xxfnd_ddl_pkg.run(q'~comment on column xxfnd_data_objects.dimension_value_type is 'Release 102: CODE - DIMENSION_COLUMN holds the value code; ID - it holds XXHR_ORGANIZATIONS.ORGANIZATION_ID (dimensions of value source ORGANIZATION).'~');
end;
/
