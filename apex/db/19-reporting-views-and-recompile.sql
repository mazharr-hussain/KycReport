begin
    -- Reporting views for the registered flexfields, then recompile anything
    -- created before its dependencies existed.
    xxfnd_dff_setup_pkg.generate_all_dfv_views;
    dbms_utility.compile_schema(schema => user, compile_all => false);
    -- release 74: COMPILE_SCHEMA skips synonyms; one whose shared object was re-created (COMMON upgrade) shows
    -- invalid until first used - recompile it so an install ends with no invalid object
    for s in (select object_name from user_objects where object_type = 'SYNONYM' and status <> 'VALID') loop
        begin
            execute immediate 'alter synonym "' || s.object_name || '" compile';
        exception
            when others then
                null;   -- its target is gone: left for the next release's cleanup, never an install error
        end;
    end loop;
end;
/
