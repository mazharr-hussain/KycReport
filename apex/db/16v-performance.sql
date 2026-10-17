--------------------------------------------------------------------------------
-- 16v Performance (release 74, R23). KYC only (XXCUS).
--   Indexes on the foreign keys of the transaction tables (joins from the case and request screens, and no table lock
--   on the child when a parent row is deleted) and a function-based index for the data security predicate of the
--   requests (upper(requester_user_name) in (...), written by XXFND_VPD_PKG for the OWN_RECORDS rule).
--   The history tables are left as they are (XXCMP_RFIS, XXCMP_CASE_DECISIONS).
-- Idempotent: each index is created only when missing (XXFND_DDL_PKG.ENSURE_INDEX).
--------------------------------------------------------------------------------
begin
    for i in (select 'XXCMP_ALERTS_N3' n, 'xxcmp_alerts (review_request_id)' d from dual
              union all select 'XXCMP_CASES_N4',              'xxcmp_cases (request_id)' from dual
              union all select 'XXCMP_CASES_N5',              'xxcmp_cases (parent_case_id)' from dual
              union all select 'XXCMP_CASE_FUNDS_N2',         'xxcmp_case_funds (party_id)' from dual
              union all select 'XXCMP_CASE_NOTES_N1',         'xxcmp_case_notes (case_id)' from dual
              union all select 'XXCMP_CASE_NOTES_N2',         'xxcmp_case_notes (related_party_id)' from dual
              union all select 'XXCMP_DOC_VERIFICATIONS_N1',  'xxcmp_doc_verifications (attached_document_id)' from dual
              union all select 'XXCMP_FIU_REPORTS_N2',        'xxcmp_fiu_reports (party_id)' from dual
              union all select 'XXCMP_REQUESTS_N3',           'xxcmp_requests (parent_request_id)' from dual
              union all select 'XXCMP_REQUESTS_N4',           'xxcmp_requests (upper(requester_user_name))' from dual
              union all select 'XXCMP_REQUESTS_N5',           'xxcmp_requests (questionnaire_code)' from dual
              union all select 'XXCMP_REQUEST_ANSWERS_N1',    'xxcmp_request_answers (case_id)' from dual
              union all select 'XXCMP_REQUEST_ANSWERS_N2',    'xxcmp_request_answers (question_id)' from dual
              union all select 'XXCMP_REQUEST_ANSWERS_N3',    'xxcmp_request_answers (answer_option_id)' from dual
              union all select 'XXCMP_SCREENINGS_N1',         'xxcmp_screenings (case_id)' from dual
              union all select 'XXCMP_SCREENINGS_N2',         'xxcmp_screenings (party_id)' from dual) loop
        xxfnd_ddl_pkg.ensure_index(i.n, 'create index ' || lower(i.n) || ' on ' || i.d);
    end loop;
    -- release 92: XXCMP_UBO_DETERMINATIONS is retired (nothing reads it), so its index goes (checked: nothing when gone)
    xxfnd_ddl_pkg.drop_index('XXCMP_UBO_DETERMINATIONS_N1');
end;
/
