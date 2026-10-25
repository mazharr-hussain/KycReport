
-- release 80: XXFND_DF_SEGMENTS_VL was not used by any page or package: dropped (checked, DDL recorded)
begin
    xxfnd_ddl_pkg.drop_object('XXFND_DF_SEGMENTS_VL', 'VIEW');
end;
/
