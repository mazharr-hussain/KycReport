--------------------------------------------------------------------------------
-- 16s Case component - XXCMP_CASE_PKG body (release 74: own script, R1). KYC only (XXCUS).
--   The case logic: opening a case (the only CREATE_CASE), sections, screening, investigation, submit for approval,
--   approval levels and decisions, withdraw, case RFIs. The request is approved by XXCMP_REQUEST_PKG; the party by
--   XXCMP_PARTY_PKG. The specification is in 16b (with the tables).
-- Idempotent: the case record tables only when missing, columns as checked steps, then create or replace.
--------------------------------------------------------------------------------
-- release 74 (R14, R19): case records ready for integration, created before the body that uses them.
--   XXCMP_SCREENINGS (checked steps): the provider (ENDPOINT_CODE), its ORIGINAL_RESPONSE kept unchanged, REVIEWED_BY /
--     REVIEWED_DATE and CHANGED_BY_PERSON_FLAG - by hand now (CAPTURE_METHOD MANUAL), from a screening provider later (API).
--   XXCMP_FIU_REPORTS: the suspicious transaction / activity report to the FIU (goAML): draft, approval by a second
--     person, filing reference and date; filed by hand now, by a goAML integration later (SOURCE API).
--   XXCMP_CASE_FUNDS: guided source of funds / wealth - what the money comes from (category), the evidence expected for
--     it (lookup FUNDS_CATEGORY tag), the bank data seen (typed by hand now, from a bank data provider later).
--   Lookups, data security rules and integration purposes: 18e.
begin
    xxfnd_ddl_pkg.add_column('XXCMP_SCREENINGS', 'ENDPOINT_CODE', 'varchar2(30)');
    xxfnd_ddl_pkg.add_column('XXCMP_SCREENINGS', 'ORIGINAL_RESPONSE', 'clob');
    xxfnd_ddl_pkg.add_column('XXCMP_SCREENINGS', 'REVIEWED_BY', 'varchar2(255)');
    xxfnd_ddl_pkg.add_column('XXCMP_SCREENINGS', 'REVIEWED_DATE', 'date');
    xxfnd_ddl_pkg.add_column('XXCMP_SCREENINGS', 'CHANGED_BY_PERSON_FLAG', 'varchar2(1) default ''N'' not null');
    xxfnd_ddl_pkg.add_constraint('XXCMP_SCREENINGS', 'XXCMP_SCREENINGS_CK5', 'check (changed_by_person_flag in (''Y'',''N''))');
end;
/
