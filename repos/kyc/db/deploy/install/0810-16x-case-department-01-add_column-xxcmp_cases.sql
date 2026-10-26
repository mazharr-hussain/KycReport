--------------------------------------------------------------------------------
-- 16x Requesting department of a case (release 95). KYC only (XXCUS).
--   XXCMP_CASES.REQUESTING_DEPARTMENT: the department of the request that opened the case (XXCMP_CASE_PKG.OPEN_CASE
--   copies it), so cases are a data object on COMMON's Department dimension like requests (script 18h): a role with
--   access by values sees only the cases of its departments. Existing cases get their request's department.
--   Runs before the case package body (16s), which writes the column.
-- Idempotent: the column is added only when missing (XXFND_DDL_PKG.ADD_COLUMN); the fill touches only empty rows.
-- Release 95 fix: closed cases are locked (XXCMP_CASES_LOCK): the trigger is disabled during the fill only.
--------------------------------------------------------------------------------
begin
    xxfnd_ddl_pkg.add_column('XXCMP_CASES', 'REQUESTING_DEPARTMENT', 'varchar2(240)');
    execute immediate q'~comment on column xxcmp_cases.requesting_department is 'Release 95: the requesting department of the request that opened the case (Department data access, COMMON security model).'~';
    -- the lock of closed cases (trigger XXCMP_CASES_LOCK) is off for this one-time fill only, and on again even when
    -- it fails; closed cases get the department too, nothing else of them changes
    execute immediate 'alter trigger xxcmp_cases_lock disable';
    begin
        execute immediate q'~
        update xxcmp_cases c
           set c.requesting_department = (select r.requesting_department from xxcmp_requests r where r.request_id = c.request_id)
         where c.requesting_department is null
           and exists (select 1 from xxcmp_requests r where r.request_id = c.request_id and r.requesting_department is not null)~';
        commit;
    exception
        when others then
            rollback;
            execute immediate 'alter trigger xxcmp_cases_lock enable';
            raise;
    end;
    execute immediate 'alter trigger xxcmp_cases_lock enable';
end;
/
