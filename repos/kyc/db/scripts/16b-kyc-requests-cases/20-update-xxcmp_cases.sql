
-- release 41: existing cases get their due diligence type from the Enhanced KYC flag
update xxcmp_cases set due_diligence_type = case when enhanced_kyc_flag = 'Y' then 'ENHANCED' else 'STANDARD' end
 where due_diligence_type is null;
commit;
