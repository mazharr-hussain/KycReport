--------------------------------------------------------------------------------
-- 16m Case status Pending Information (release 74). KYC only (XXCUS).
--   An approver asks for information on the case approval notification: the case is Pending Information until the
--   information is submitted, then Pending Approval again (task actions of CASE_APPROVAL).
--   Checked step: the status check of XXCMP_CASES is replaced only when it does not allow PENDING_INFORMATION yet;
--   a re-run changes nothing.
--------------------------------------------------------------------------------
declare
    l_n pls_integer;
begin
    select count(*) into l_n
      from user_constraints
     where table_name = 'XXCMP_CASES' and constraint_name = 'XXCMP_CASES_CK1'
       and search_condition_vc not like '%PENDING_INFORMATION%';
    if l_n > 0 then
        xxfnd_ddl_pkg.drop_constraint('XXCMP_CASES', 'XXCMP_CASES_CK1');
    end if;
    xxfnd_ddl_pkg.add_constraint('XXCMP_CASES', 'XXCMP_CASES_CK1',
        'check (case_status in (''INVESTIGATION'',''PENDING_APPROVAL'',''PENDING_INFORMATION'',''APPROVED'',''REJECTED'',''CANCELLED''))');
end;
/
