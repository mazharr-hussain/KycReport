-- KYC release 90 (run as XXCUS): requests, parties, cases cleanup.
--   - one copy of each routine: PARAM only in the case package; the request approval (was XXCMP_APPROVAL_PKG, dropped)
--     in XXCMP_REQUEST_PKG; party reads (GET_PARTY, PARTY_STATUS) in XXCMP_PARTY_PKG; CLOSE_CASE instead of
--     APPROVE_CASE / REJECT_CASE (workflow KYC_CASE calls it)
--   - routines used only inside their package are private
--   - no HTML built in the request / party packages (page 202: KYC Question template component; the flexfield is COMMON's
--     XXFND_DFF_PKG.RENDER)
--   - page 206: the task checks are XXCMP_REQUEST_PKG.CAN_DECIDE / CAN_ADD_APPROVER, its employee list is the shared LOV;
--     pages 205 / 206 share the request details and the document checklist from the Global Page; page 165 = SAR gate
-- Reads only; no test rows are added.
set serveroutput on size unlimited feedback off
declare
    l_n     number;
    l_app   number;
    l_req   number;
    l_case  number;
    l_party xxcmp_parties%rowtype;
    l_txt   varchar2(4000);

    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
    function cnt(p_sql varchar2) return number is
        l number;
    begin
        execute immediate p_sql into l;
        return l;
    end;
    -- public routines of a package (in its specification)
    function pub(p_pkg varchar2, p_names varchar2) return number is
    begin
        return cnt('select count(distinct procedure_name) from user_procedures where object_name = ''' || p_pkg
                   || ''' and procedure_name in (' || p_names || ')');
    end;
    function src(p_pkg varchar2, p_like varchar2) return number is
    begin
        return cnt('select count(*) from user_source where name = ''' || p_pkg || ''' and type = ''PACKAGE BODY'''
                   || ' and lower(text) like ''' || p_like || '''');
    end;
begin
    select max(application_id) into l_app from apex_applications where upper(alias) = 'KYC';

    ---------------------------------------------------------------- one package per component, one copy per routine
    ok('XXCMP_APPROVAL_PKG is dropped',
       cnt(q'[select count(*) from user_objects where object_name = 'XXCMP_APPROVAL_PKG']') = 0);
    ok('the history types stay (XXCMP_HISTORY_ROW / _TAB)',
       cnt(q'[select count(*) from user_types where type_name in ('XXCMP_HISTORY_ROW', 'XXCMP_HISTORY_TAB')]') = 2);
    ok('no invalid KYC package',
       cnt(q'[select count(*) from user_objects where object_name like 'XXCMP%PKG' and status <> 'VALID']') = 0);
    ok('the request approval is public in XXCMP_REQUEST_PKG (STEP_APPROVERS, STEP_NAME, NEXT_STEP, HISTORY_ROWS)',
       pub('XXCMP_REQUEST_PKG', q'['STEP_APPROVERS','STEP_NAME','NEXT_STEP','HISTORY_ROWS']') = 4);
    ok('page 206 checks and the request''s case are request routines (CAN_DECIDE, CAN_ADD_APPROVER, REQUEST_CASE)',
       pub('XXCMP_REQUEST_PKG', q'['CAN_DECIDE','CAN_ADD_APPROVER','REQUEST_CASE']') = 3);
    ok('private in XXCMP_REQUEST_PKG: QUESTIONNAIRE_FOR, CREATE_REQUEST, PATH_FOR, START_PATH, IS_LAST_STEP',
       pub('XXCMP_REQUEST_PKG', q'['QUESTIONNAIRE_FOR','CREATE_REQUEST','PATH_FOR','START_PATH','IS_LAST_STEP']') = 0);
    ok('gone from XXCMP_REQUEST_PKG: QUESTIONNAIRE_HTML, PARAM, GET_PARTY, PARTY_STATUS',
       pub('XXCMP_REQUEST_PKG', q'['QUESTIONNAIRE_HTML','PARAM','GET_PARTY','PARTY_STATUS']') = 0
       and src('XXCMP_REQUEST_PKG', '%function param(%') = 0
       and src('XXCMP_REQUEST_PKG', '%function get_party(%') = 0
       and src('XXCMP_REQUEST_PKG', '%function party_status(%') = 0);
    -- release 91: the one copy is the public XXCMP_CASE_PKG.PARAMETER (KYC application settings)
    ok('PARAMETER: one copy, in the case package', src('XXCMP_CASE_PKG', '%function parameter(%') = 1);
    ok('the party reads are the party package''s (GET_PARTY, PARTY_STATUS public)',
       pub('XXCMP_PARTY_PKG', q'['GET_PARTY','PARTY_STATUS','PARTY_TYPE']') = 3);
    ok('PARTY_CANDIDATE_COUNT is private', pub('XXCMP_PARTY_PKG', q'['PARTY_CANDIDATE_COUNT']') = 0
       and src('XXCMP_PARTY_PKG', '%function party_candidate_count(%') = 1);
    ok('XXCMP_CASE_PKG: CLOSE_CASE replaces APPROVE_CASE / REJECT_CASE',
       pub('XXCMP_CASE_PKG', q'['CLOSE_CASE']') = 1 and pub('XXCMP_CASE_PKG', q'['APPROVE_CASE','REJECT_CASE']') = 0);
    ok('private in XXCMP_CASE_PKG: CASE_ATTRIBUTES, EXPECTED_EVIDENCE (EXPECTED_EVIDENCE_TEXT stays public)',
       pub('XXCMP_CASE_PKG', q'['CASE_ATTRIBUTES','EXPECTED_EVIDENCE']') = 0
       and pub('XXCMP_CASE_PKG', q'['EXPECTED_EVIDENCE_TEXT']') = 1);
    ok('the case package reads the party type through the party package',
       src('XXCMP_CASE_PKG', '%xxcmp_party_pkg.party_type(p_case.party_id)%') = 1);

    ---------------------------------------------------------------- no HTML in PL/SQL
    ok('no HTML built in XXCMP_REQUEST_PKG', src('XXCMP_REQUEST_PKG', '%<fieldset%') + src('XXCMP_REQUEST_PKG', '%<div%')
                                             + src('XXCMP_REQUEST_PKG', '%<input%') = 0);
    ok('no HTML built in XXCMP_PARTY_PKG (the flexfield is COMMON''s XXFND_DFF_PKG.RENDER)',
       src('XXCMP_PARTY_PKG', '%<div%') + src('XXCMP_PARTY_PKG', '%<input%') = 0
       and src('XXCMP_PARTY_PKG', '%xxfnd_dff_pkg.render(%') = 1);

    ---------------------------------------------------------------- behaviour
    begin
        xxcmp_case_pkg.close_case(-1, 'MAYBE');
        ok('close_case refuses an unknown decision', false);
    exception
        when others then
            ok('close_case refuses an unknown decision (' || sqlcode || ')', sqlcode = -20615);
    end;
    ok('can_decide / can_add_approver: N without a task',
       xxcmp_request_pkg.can_decide(null) = 'N' and xxcmp_request_pkg.can_add_approver(null, null) = 'N');
    select max(request_id) into l_req from xxcmp_requests where submitted_date is not null;
    if l_req is not null then
        select count(*) into l_n from table(xxcmp_request_pkg.history_rows(l_req)) where action = 'Submitted';
        ok('history_rows (request package) shows the submit of request ' || l_req, l_n = 1);
    end if;
    select max(c.case_id) keep (dense_rank last order by c.case_id), max(c.request_id) keep (dense_rank last order by c.case_id)
      into l_case, l_req from xxcmp_cases c where c.request_id is not null;
    if l_req is not null then
        select max(case_id) into l_case from xxcmp_cases where request_id = l_req;
        ok('request_case gives the request''s case', xxcmp_request_pkg.request_case(l_req) = l_case);
    end if;
    select max(party_id) into l_n from xxcmp_parties;
    if l_n is not null then
        l_party := xxcmp_party_pkg.get_party(l_n);
        ok('get_party / party_status read the party', l_party.party_id = l_n
           and xxcmp_party_pkg.party_status(l_n) = l_party.party_status);
    end if;
    ok('party_status of no party is null', xxcmp_party_pkg.party_status(-1) is null);

    ---------------------------------------------------------------- application
    ok('no page, task definition or workflow calls a removed routine',
       cnt('select count(*) from apex_application_page_regions where application_id = ' || l_app
           || q'[ and (lower(region_source) like '%xxcmp_approval_pkg%' or lower(region_source) like '%questionnaire_html(%')]') = 0
       and cnt('select count(*) from apex_appl_workflow_activities where application_id = ' || l_app
           || q'[ and (lower(activity_code) like '%approve_case%' or lower(activity_code) like '%reject_case%'
                       or lower(activity_code) like '%xxcmp_approval_pkg%')]') = 0
       and cnt('select count(*) from apex_appl_taskdef_participants where application_id = ' || l_app
           || q'[ and lower(value) like '%xxcmp_approval_pkg%']') = 0);
    ok('the KYC_CASE workflow closes the case with CLOSE_CASE',
       cnt('select count(*) from apex_appl_workflow_activities where application_id = ' || l_app
           || q'[ and lower(activity_code) like '%xxcmp_case_pkg.close_case(%']') >= 2);
    ok('page 202: the questionnaire is the KYC Question template component',
       cnt('select count(*) from apex_application_page_regions where application_id = ' || l_app
           || q'[ and page_id = 202 and static_id = 'answers' and source_type = 'KYC Question']') = 1);
    ok('the request details and the document checklist are defined once, on the Global Page',
       cnt('select count(*) from apex_application_page_regions where application_id = ' || l_app
           || q'[ and static_id in ('request_details', 'checklist') and page_id = 0]') = 2
       and cnt('select count(*) from apex_application_page_regions where application_id = ' || l_app
           || q'[ and static_id in ('request_details', 'checklist') and page_id in (205, 206)]') = 0);
    ok('page 206: no task check repeated in the page',
       cnt('select count(*) from apex_application_page_buttons where application_id = ' || l_app
           || q'[ and page_id = 206 and lower(condition_expression1) like '%apex_human_task.is_allowed%']') = 0
       and cnt('select count(*) from apex_application_page_buttons where application_id = ' || l_app
           || q'[ and page_id = 206 and lower(condition_expression1) like '%xxcmp_request_pkg.can_decide%']') = 6);
    ok('page 206: Approver to Add uses the shared employee list',
       cnt('select count(*) from apex_application_page_items where application_id = ' || l_app
           || q'[ and item_name = 'P206_ADD_USER' and lov_named_lov = 'EMPLOYEES BY USER NAME']') = 1);
    ok('page 165 keeps only the SAR gate',
       cnt('select count(*) from apex_application_page_regions where application_id = ' || l_app
           || q'[ and page_id = 165 and static_id = 'matrix' and lower(region_source) not like '%required_levels%'
                 and lower(region_source) like '%sar_gate_flag%']') = 1);
end;
/
