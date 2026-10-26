--------------------------------------------------------------------------------
-- 19a Grants to the shared schema (release 54). KYC only; install and every upgrade.
--   The shared code in XXFUSION works on registered KYC objects with owner-qualified dynamic SQL
--   (xxfnd_util_pkg.qualified): approvals and flexfields update XXCMP_ tables, Config Change Approvals read
--   XXCMP_CONFIG_CHANGES_V, the flexfield views read the tables, user renames update the user-name columns,
--   the party-details authorization calls XXCMP_PARTY_PKG.
--------------------------------------------------------------------------------
begin
    for o in (select object_name, object_type from user_objects
               where object_name like 'XXCMP\_%' escape '\' and object_type in ('TABLE', 'VIEW', 'PACKAGE')
               order by object_type, object_name) loop
        begin
            execute immediate case o.object_type when 'TABLE' then 'grant select, update on '
                                                 when 'VIEW'  then 'grant select on '
                                                 else 'grant execute on ' end
                              || o.object_name || ' to xxfusion';
        exception
            when others then
                -- an invalid view cannot be granted; it is granted on the next run
                dbms_output.put_line('skipped ' || o.object_name || ': ' || sqlerrm);
        end;
    end loop;
end;
/
