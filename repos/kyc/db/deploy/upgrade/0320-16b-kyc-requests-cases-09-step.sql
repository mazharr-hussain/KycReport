-- release 29: an officer can withdraw a case from approval (outcome WITHDRAWN)
declare
    l_cond varchar2(4000);
begin
    select search_condition_vc into l_cond from user_constraints
     where table_name = 'XXCMP_CASE_DECISIONS' and constraint_name = 'XXCMP_CASE_DECISIONS_CK1';
    if instr(l_cond, 'WITHDRAWN') = 0 then
        execute immediate 'alter table xxcmp_case_decisions drop constraint xxcmp_case_decisions_ck1';
        execute immediate q'[alter table xxcmp_case_decisions add constraint xxcmp_case_decisions_ck1
                             check (outcome in ('APPROVED','REJECTED','WITHDRAWN'))]';
    end if;
end;
/
