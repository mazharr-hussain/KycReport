begin
    xxfnd_schema_pkg.create_who_trigger('XXCMP_APPROVAL_PATHS');
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'APPROVAL_PATH_NAME', 'varchar2(100)');
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'CURRENT_STEP',       'number');
    -- release 26: paths by business relationship (customer, vendor...)
    xxfnd_ddl_pkg.add_column('XXCMP_APPROVAL_PATHS', 'BUSINESS_RELATIONSHIP', 'varchar2(30)');
end;
/
-- Release 91: XXCMP_APPROVAL_PATHS is retired. Nothing reads it (the approvers come from COMMON's Approval Setup, type
-- KYC_REQUEST) and its 'Default' path is no longer seeded. The table and its rows are kept as history.

-- Release 90: the request approval routines (path, steps, approvers, history) are XXCMP_REQUEST_PKG's (request logic in
-- the request package; 16b specification, 16r body). The old package is dropped (checked: nothing when it is gone).
begin
    xxfnd_ddl_pkg.drop_object('XXCMP_APPROVAL_PKG', 'PACKAGE');
end;
/
