-- Release 74 case component (KYC, run as XXCUS): screening provider fields, FIU / goAML reports (maker-checker, filing),
-- guided source of funds / wealth, the case summary and section menu as data. Everything is rolled back.
set serveroutput on size unlimited feedback off
declare
    l_app   number;
    l_case  number;
    l_party number;
    l_scr   number;
    l_fiu   number;
    l_fund  number;
    l_n     number;
    l_txt   varchar2(4000);
    l_json  clob;
    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
begin
    select application_id into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'KYC';
    apex_session.create_session(l_app, 1, 'OFFICER1');
    select max(case_id) into l_case from xxcmp_cases where case_status = 'INVESTIGATION';
    select party_id into l_party from xxcmp_cases where case_id = l_case;

    -- section menu and summary as data
    ok('sections list: ' || xxcmp_case_pkg.sections, xxcmp_case_pkg.sections like 'SUMMARY:%REVIEW');
    ok('progress: ' || xxcmp_case_pkg.section_progress(l_case), regexp_like(xxcmp_case_pkg.section_progress(l_case), '^\d+ / 8$'));
    l_json := xxcmp_case_pkg.case_summary_json(l_case);
    ok('case summary data has the request and the assessment', dbms_lob.instr(l_json, '"label":"Request"') > 0
       and dbms_lob.instr(l_json, '"group_name":"Assessment"') > 0);

    -- screening: a provider row changed by a person is marked; review records who
    insert into xxcmp_screenings (case_id, party_id, screening_type, match_status, capture_method, endpoint_code, original_response)
    values (l_case, l_party, 'SANCTIONS', 'NO_MATCH', 'API', 'TEST_PROVIDER', '{"hits":0}') returning screening_id into l_scr;
    xxcmp_case_pkg.screening_saved(l_scr);
    xxcmp_case_pkg.review_screening(l_scr);
    select count(*) into l_n from xxcmp_screenings
     where screening_id = l_scr and changed_by_person_flag = 'Y' and reviewed_by = 'OFFICER1' and dbms_lob.compare(original_response, to_clob('{"hits":0}')) = 0;
    ok('provider screening: changed by a person, reviewed, original response kept', l_n = 1);

    -- FIU report: grounds required; the preparer cannot approve; filing needs reference and date
    ok('FIU report needs grounds', xxcmp_case_pkg.fiu_report_error(l_case, 'STR', null) is not null);
    insert into xxcmp_fiu_reports (case_id, party_id, report_type, grounds, prepared_by)
    values (l_case, l_party, 'STR', 'Unusual cash deposits', 'OFFICER1') returning fiu_report_id into l_fiu;
    ok('the preparer cannot approve their own report', xxcmp_case_pkg.fiu_action_allowed(l_fiu, 'APPROVE') = 'N');
    apex_session.create_session(l_app, 1, 'MGR1');
    ok('another manager can approve', xxcmp_case_pkg.fiu_action_allowed(l_fiu, 'APPROVE') = 'Y');
    xxcmp_case_pkg.fiu_action(l_fiu, 'APPROVE');
    begin
        xxcmp_case_pkg.fiu_action(l_fiu, 'FILE');
        ok('filing without a reference is refused', false);
    exception when others then
        ok('filing without a reference is refused', sqlcode = -20616);
    end;
    xxcmp_case_pkg.fiu_action(l_fiu, 'FILE', 'GOAML-123', trunc(sysdate));
    select report_status || '|' || approved_by || '|' || goaml_reference into l_txt from xxcmp_fiu_reports where fiu_report_id = l_fiu;
    ok('report approved and filed: ' || l_txt, l_txt = 'FILED|MGR1|GOAML-123');
    ok('a filed report can no longer be changed', xxcmp_case_pkg.fiu_editable(l_fiu, l_case) = 'N');

    -- guided source of funds: the evidence must fit the source; verification needs evidence
    apex_session.create_session(l_app, 1, 'OFFICER1');
    ok('expected evidence for salary: ' || xxcmp_case_pkg.expected_evidence_text('SALARY'),
       xxcmp_case_pkg.expected_evidence_text('SALARY') like '%Payslip%');
    l_txt := xxcmp_case_pkg.funds_error(l_case, 'SOF', 'SALARY', 'WILL_PROBATE', 1000, null, null);
    ok('evidence that does not fit the source is refused: ' || l_txt, l_txt like 'For this source the evidence expected is:%');
    ok('fitting evidence accepted', xxcmp_case_pkg.funds_error(l_case, 'SOF', 'SALARY', 'PAYSLIP', 1000, null, null) is null);
    ok('statement period checked', xxcmp_case_pkg.funds_error(l_case, 'SOF', 'SALARY', 'PAYSLIP', 1000, date '2026-02-01', date '2026-01-01') is not null);
    insert into xxcmp_case_funds (case_id, party_id, funds_type, category, amount, currency_code)
    values (l_case, l_party, 'SOF', 'SALARY', 25000, 'AED') returning case_funds_id into l_fund;
    begin
        xxcmp_case_pkg.verify_funds(l_fund);
        ok('cannot verify without evidence', false);
    exception when others then
        ok('cannot verify without evidence', sqlcode = -20617);
    end;
    update xxcmp_case_funds set evidence_type = 'PAYSLIP', bank_name = 'Test Bank' where case_funds_id = l_fund;
    xxcmp_case_pkg.verify_funds(l_fund);
    select count(*) into l_n from xxcmp_case_funds where case_funds_id = l_fund and verified_flag = 'Y' and verified_by = 'OFFICER1';
    ok('verified with its evidence', l_n = 1);
    rollback;
    apex_session.delete_session;
end;
/
exit
