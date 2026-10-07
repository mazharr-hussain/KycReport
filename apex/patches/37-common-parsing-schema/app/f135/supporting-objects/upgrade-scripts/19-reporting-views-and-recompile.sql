begin
    -- Reporting views for the registered flexfields, then recompile anything
    -- created before its dependencies existed.
    xxfnd_dff_setup_pkg.generate_all_dfv_views;
    dbms_utility.compile_schema(schema => user, compile_all => false);
end;
/
