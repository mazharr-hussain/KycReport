--------------------------------------------------------------------------------
-- 16z step 2 (release 105): the old request status check (Draft, In Progress, ...) is dropped, only while it does not
-- have the request stages yet (step 4 adds the new one).
-- Idempotent: nothing happens once the new check is in place.
--------------------------------------------------------------------------------
begin
    for c in (select constraint_name from user_constraints
               where constraint_name = 'XXCMP_REQUESTS_CK3' and search_condition_vc not like '%UNDER_REVIEW%') loop
        xxfnd_ddl_pkg.drop_constraint('XXCMP_REQUESTS', 'XXCMP_REQUESTS_CK3');
    end loop;
end;
/
