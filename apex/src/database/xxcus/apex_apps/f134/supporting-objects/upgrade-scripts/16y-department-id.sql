--------------------------------------------------------------------------------
-- 16y Requesting department by ID (release 96). KYC only (XXCUS).
--   The requesting department of a request and of a case is the department organization of COMMON:
--   XXCMP_REQUESTS.REQUESTING_DEPARTMENT_ID and XXCMP_CASES.REQUESTING_DEPARTMENT_ID hold
--   XXHR_ORGANIZATIONS.ORGANIZATION_ID (organization type DEPARTMENT, schema XXFUSION, COMMON 102), with a foreign key.
--   The old code columns (REQUESTING_DEPARTMENT) are kept read-only: nothing writes them any more.
--   Existing rows get the ID of the department with their code; a code that is no department yet becomes one through
--   COMMON's routine (XXFND_VPD_PKG.SAVE_ORGANIZATION, application KYC, name = the lookup meaning).
--   Runs before the request and case package bodies (16r, 16s), which write the new columns.
-- Idempotent: columns, foreign keys and indexes are added only when missing; the fill touches only empty rows.
--------------------------------------------------------------------------------
declare
    c_common constant varchar2(30) := 'XXFUSION';
    l_n      pls_integer;
begin
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'REQUESTING_DEPARTMENT_ID', 'number');
    xxfnd_ddl_pkg.add_column('XXCMP_CASES', 'REQUESTING_DEPARTMENT_ID', 'number');
    execute immediate q'~comment on column xxcmp_requests.requesting_department_id is 'Release 96: the requesting department - XXHR_ORGANIZATIONS.ORGANIZATION_ID (type DEPARTMENT, COMMON). Department data access (COMMON security model).'~';
    execute immediate q'~comment on column xxcmp_cases.requesting_department_id is 'Release 96: the requesting department of the request that opened the case - XXHR_ORGANIZATIONS.ORGANIZATION_ID (type DEPARTMENT, COMMON).'~';
    execute immediate q'~comment on column xxcmp_requests.requesting_department is 'Release 96: replaced by REQUESTING_DEPARTMENT_ID; kept read-only (the department code of older requests).'~';
    select count(*) into l_n from user_tab_columns where table_name = 'XXCMP_CASES' and column_name = 'REQUESTING_DEPARTMENT';
    if l_n > 0 then
        execute immediate q'~comment on column xxcmp_cases.requesting_department is 'Release 96: replaced by REQUESTING_DEPARTMENT_ID; kept read-only.'~';
    end if;
    xxfnd_ddl_pkg.ensure_index('XXCMP_REQUESTS_N_DEPT', 'create index xxcmp_requests_n_dept on xxcmp_requests (requesting_department_id)');
    xxfnd_ddl_pkg.ensure_index('XXCMP_CASES_N_DEPT', 'create index xxcmp_cases_n_dept on xxcmp_cases (requesting_department_id)');

    -- the departments of the existing requests that COMMON does not have yet (through COMMON's routine)
    xxfnd_vpd_pkg.begin_trusted;
    for d in (select distinct upper(trim(r.requesting_department)) code,
                     max(v.meaning) keep (dense_rank first order by v.display_sequence) meaning
                from xxcmp_requests r
                left join xxfnd_lookup_values v
                  on v.lookup_type = 'REQUESTING_DEPARTMENT' and upper(v.lookup_code) = upper(trim(r.requesting_department))
               where r.requesting_department is not null
                 and not exists (select 1 from xxhr_organizations g
                                  where g.organization_type = 'DEPARTMENT'
                                    and (g.organization_code = upper(trim(r.requesting_department))
                                         or upper(g.organization_name) = upper(trim(r.requesting_department))))
               group by upper(trim(r.requesting_department))) loop
        xxfnd_vpd_pkg.save_organization('KYC', 'DEPARTMENT', d.code, nvl(d.meaning, initcap(d.code)));
        dbms_output.put_line('department created in COMMON: ' || d.code);
    end loop;
    xxfnd_vpd_pkg.end_trusted;

    -- the IDs of the existing requests (by code, else by name)
    execute immediate q'~
    update xxcmp_requests r
       set r.requesting_department_id =
           (select min(g.organization_id) keep (dense_rank first order by
                       case when g.organization_code = upper(trim(r.requesting_department)) then 1 else 2 end)
              from xxhr_organizations g
             where g.organization_type = 'DEPARTMENT'
               and (g.organization_code = upper(trim(r.requesting_department))
                    or upper(g.organization_name) = upper(trim(r.requesting_department))))
     where r.requesting_department_id is null and r.requesting_department is not null~';
    commit;

    -- the cases get their request's department; closed cases are locked (XXCMP_CASES_LOCK): the trigger is off for
    -- this one-time fill only, and on again even when it fails
    execute immediate 'alter trigger xxcmp_cases_lock disable';
    begin
        execute immediate q'~
        update xxcmp_cases c
           set c.requesting_department_id = (select r.requesting_department_id from xxcmp_requests r
                                              where r.request_id = c.request_id)
         where c.requesting_department_id is null
           and exists (select 1 from xxcmp_requests r
                        where r.request_id = c.request_id and r.requesting_department_id is not null)~';
        commit;
    exception
        when others then
            rollback;
            execute immediate 'alter trigger xxcmp_cases_lock enable';
            raise;
    end;
    execute immediate 'alter trigger xxcmp_cases_lock enable';

    -- the foreign keys to COMMON's departments: COMMON grants REFERENCES on its tables to the application schemas
    -- (script 19c); without the grant (an older COMMON) the keys are skipped and come with the next install
    select count(*) into l_n from all_tab_privs
     where table_schema = c_common and table_name = 'XXHR_ORGANIZATIONS' and privilege = 'REFERENCES'
       and grantee in (sys_context('USERENV', 'CURRENT_SCHEMA'), 'PUBLIC');
    if l_n > 0 then
        xxfnd_ddl_pkg.add_constraint('XXCMP_REQUESTS', 'XXCMP_REQUESTS_FK_DEPT',
            'foreign key (requesting_department_id) references ' || c_common || '.xxhr_organizations (organization_id)');
        xxfnd_ddl_pkg.add_constraint('XXCMP_CASES', 'XXCMP_CASES_FK_DEPT',
            'foreign key (requesting_department_id) references ' || c_common || '.xxhr_organizations (organization_id)');
    else
        dbms_output.put_line('skipped: the department foreign keys (no REFERENCES on ' || c_common
                             || '.XXHR_ORGANIZATIONS; install COMMON 102 first, then re-run this script)');
    end if;
exception
    when others then
        xxfnd_vpd_pkg.end_trusted;
        raise;
end;
/
