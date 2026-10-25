
begin
    for t in (select column_value table_name from table(apex_t_varchar2(
                 'XXCMP_REQUESTS','XXCMP_CASES','XXCMP_REQUEST_ANSWERS','XXCMP_CASE_DECISIONS','XXCMP_SCREENINGS',
                 'XXCMP_DOC_VERIFICATIONS','XXCMP_UBO_DETERMINATIONS','XXCMP_CASE_NOTES'))) loop
        xxfnd_schema_pkg.create_who_trigger(t.table_name);
    end loop;
    -- release 26: the business relationship of the request goes on to its case
    xxfnd_ddl_pkg.add_column('XXCMP_CASES', 'BUSINESS_RELATIONSHIP', 'varchar2(30)');
    -- release 41: the due diligence type (lookup DUE_DILIGENCE_TYPE); ENHANCED_KYC_FLAG follows it (trigger XXCMP_CASES_DD)
    xxfnd_ddl_pkg.add_column('XXCMP_CASES', 'DUE_DILIGENCE_TYPE', 'varchar2(30)');
    -- release 42: the risk level of the screened party (lookup RISK_TIER); RESULT_NOTES is its conclusion
    xxfnd_ddl_pkg.add_column('XXCMP_SCREENINGS', 'RISK_TIER', 'varchar2(30)');
    -- release 43: the officer's report conclusion and next steps (required to submit for approval)
    xxfnd_ddl_pkg.add_column('XXCMP_CASES', 'REPORT_CONCLUSION', 'varchar2(4000)');
    xxfnd_ddl_pkg.add_column('XXCMP_CASES', 'NEXT_STEPS', 'varchar2(4000)');
    -- release 73: approval workflow switched off for the process (COMMON Workflow Processes) - auto-approved
    xxfnd_ddl_pkg.add_column('XXCMP_CASES', 'AUTO_APPROVED_DATE', 'timestamp');
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'AUTO_APPROVED_DATE', 'timestamp');
end;
/
comment on column xxcmp_cases.report_conclusion is 'Report conclusion written by the officer (case Risk Assessment); required to submit for approval.';
comment on column xxcmp_cases.next_steps is 'Next steps (e.g. on-going monitoring) written by the officer; required to submit for approval.';
comment on column xxcmp_screenings.risk_tier is 'Risk level of the screened party (lookup RISK_TIER). RESULT_NOTES = the conclusion, SOURCE_REFERENCE = the source, MATCH_STATUS = the results.';
comment on column xxcmp_cases.due_diligence_type is 'Due diligence type (lookup DUE_DILIGENCE_TYPE: SIMPLIFIED, STANDARD, ENHANCED). ENHANCED_KYC_FLAG = Y exactly when ENHANCED (trigger XXCMP_CASES_DD).';
comment on column xxcmp_requests.business_relationship is 'What the counterparty is to the company for this request (lookup BUSINESS_RELATIONSHIP: customer, vendor...). One per request; copied to the case.';
comment on column xxcmp_requests.registration_type is 'Type of REGISTRATION_NUMBER: organisation lookup REGISTRATION_TYPE, individual lookup ID_DOCUMENT_TYPE.';

--------------------------------------------------------------------------------
-- Requests
--------------------------------------------------------------------------------
-- the approval path columns the request package uses (also added by 16g; checked, release 69)
begin
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'APPROVAL_PATH_NAME', 'varchar2(100)');
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'CURRENT_STEP',       'number');
end;
/
