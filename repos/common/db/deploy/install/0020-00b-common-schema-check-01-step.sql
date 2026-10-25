--------------------------------------------------------------------------------
-- 00b COMMON parsing-schema check (release 52). COMMON only; runs right after 00a on install and upgrade.
--   The COMMON application and the shared XXFND_ objects belong in XXFUSION (the workspace's default schema
--   XXCUS is for the business applications). Imported with another parsing schema, it stops here.
--------------------------------------------------------------------------------
declare
    l_schema varchar2(128) := sys_context('userenv', 'current_schema');
begin
    if l_schema <> 'XXFUSION' then
        raise_application_error(-20901,
            'ACTION NEEDED - the COMMON application was imported with parsing schema ' || l_schema
            || '; it must be XXFUSION. Nothing was installed.' || chr(10)
            || '1. App Builder > COMMON > Edit Application Definition > Security > Database Session > '
            || 'Parsing Schema = XXFUSION > Apply Changes' || chr(10)
            || '   (or import the zip again and choose Parsing Schema XXFUSION).' || chr(10)
            || '2. Utilities > Supporting Objects > Install Supporting Objects.');
    end if;
end;
/
