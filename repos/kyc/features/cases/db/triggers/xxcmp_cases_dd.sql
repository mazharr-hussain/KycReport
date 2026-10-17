

--------------------------------------------------------------------------------
-- Cases
--------------------------------------------------------------------------------

-- A closed case cannot change any more (case closure locks it).
-- release 41: the due diligence type and the Enhanced KYC flag stay in step. The officer chooses the type; a
-- screening that forces Enhanced KYC (APPLY_SCREENING sets the flag) makes the type Enhanced.
create or replace trigger xxcmp_cases_dd
before insert or update of due_diligence_type, enhanced_kyc_flag on xxcmp_cases
for each row
begin
    if inserting then
        :new.due_diligence_type := nvl(:new.due_diligence_type,
                                       case when :new.enhanced_kyc_flag = 'Y' then 'ENHANCED' else 'STANDARD' end);
    elsif nvl(:new.due_diligence_type, '#') <> nvl(:old.due_diligence_type, '#') then
        :new.due_diligence_type := nvl(:new.due_diligence_type, 'STANDARD');
    elsif :new.enhanced_kyc_flag <> :old.enhanced_kyc_flag then
        :new.due_diligence_type := case when :new.enhanced_kyc_flag = 'Y' then 'ENHANCED'
                                        when :old.due_diligence_type = 'ENHANCED' then 'STANDARD'
                                        else nvl(:old.due_diligence_type, 'STANDARD') end;
    end if;
    :new.enhanced_kyc_flag := case when :new.due_diligence_type = 'ENHANCED' then 'Y' else 'N' end;
end;
/
