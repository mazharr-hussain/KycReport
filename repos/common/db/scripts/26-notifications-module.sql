
-- the applications reach the new objects through the usual grants
begin
    -- release 87 (C11): the grants to the applications run once, last (script 99)
    null;
end;
/

-- anything a change above left invalid is compiled again (no install error, no stale package state)
begin
    dbms_utility.compile_schema(schema => user, compile_all => false);
end;
/
