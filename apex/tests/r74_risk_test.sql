-- Release 74 R16 / R24 (KYC, run as XXCUS): the configurable risk model - FATF lists seeded, a case's score and
-- suggested tier with its breakdown, the review interval from the model, maker-checker on changes (the approved model
-- stays in use while a change waits), the impact preview of a pending change, approval by another person.
-- Everything is rolled back.
set serveroutput on size unlimited feedback off
declare
    l_app    number;
    l_case   number;
    l_party  number;
    l_n      number;
    l_score  number;
    l_tier   varchar2(30);
    l_txt    varchar2(4000);
    l_json   clob;
    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
begin
    select application_id into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'KYC';
    apex_session.create_session(l_app, 1, 'OFFICER1');
    select count(*) into l_n from xxcmp_risk_countries where list_code = 'FATF_BLACK' and approved_enabled_flag = 'Y'
       and country_code in ('KP', 'IR', 'MM');
    ok('FATF black list seeded (KP, IR, MM)', l_n = 3);
    select count(*) into l_n from xxcmp_risk_countries where list_code = 'FATF_GREY' and approved_enabled_flag = 'Y';
    ok('FATF grey list seeded: ' || l_n, l_n >= 20);
    ok('review interval from the model: HIGH = ' || xxcmp_risk_pkg.review_months('HIGH'), xxcmp_risk_pkg.review_months('HIGH') = 12);

    -- a case of a party in a FATF black-listed country is suggested HIGH whatever the score
    select max(case_id) into l_case from xxcmp_cases where case_status = 'INVESTIGATION';
    select party_id into l_party from xxcmp_cases where case_id = l_case;
    xxfnd_util_pkg.set_install_mode(true);
    update xxcmp_parties set jurisdiction = 'IR' where party_id = l_party;
    xxfnd_util_pkg.set_install_mode(false);
    l_json := xxcmp_risk_pkg.breakdown_json(l_case);
    ok('breakdown names the FATF black list', dbms_lob.instr(l_json, 'COUNTRY_FATF_BLACK') > 0);
    ok('suggested tier HIGH (forced by the black list): ' || xxcmp_risk_pkg.suggested_tier(l_case),
       xxcmp_risk_pkg.suggested_tier(l_case) = 'HIGH');
    xxcmp_risk_pkg.calculate(l_case);
    select count(*) into l_n from xxcmp_case_risk_scores where case_id = l_case and factor_code = 'COUNTRY_FATF_BLACK';
    ok('the breakdown is kept for the case', l_n = 1);

    -- a change: the black-list factor no longer forces HIGH and gives 10 points
    l_score := xxcmp_risk_pkg.score(l_case);
    update xxcmp_risk_factors set points = 10, force_tier = null where factor_code = 'COUNTRY_FATF_BLACK';
    select approval_status || '|' || approved_points into l_txt from xxcmp_risk_factors where factor_code = 'COUNTRY_FATF_BLACK';
    ok('a change waits for approval; the approved points stay in use: ' || l_txt, l_txt = 'PENDING_APPROVAL|60');
    ok('the model in use is unchanged while the change waits', xxcmp_risk_pkg.score(l_case) = l_score
       and xxcmp_risk_pkg.suggested_tier(l_case) = 'HIGH');
    ok('the proposed model shows the change: ' || xxcmp_risk_pkg.score(l_case, 'PROPOSED'),
       xxcmp_risk_pkg.score(l_case, 'PROPOSED') = l_score - 50);
    l_json := xxcmp_risk_pkg.impact_json;
    ok('impact preview lists the case', dbms_lob.instr(l_json, '"case_id":' || l_case) > 0);
    ok('pending changes reported', xxcmp_risk_pkg.has_pending_changes = 'Y');
    xxcmp_risk_pkg.submit_changes;
    select count(*) into l_n from apex_tasks where task_def_static_id = 'CONFIG_CHANGE' and detail_pk = 'XXCMP_RISK_FACTOR_SET:KYC'
       and state_code in ('UNASSIGNED', 'ASSIGNED');
    ok('submitted: one approval task for the factors', l_n = 1);
    begin
        xxfnd_approval_pkg.approve_change('XXCMP_RISK_FACTOR_SET:KYC');
        ok('the maker cannot approve their own change', false);
    exception when others then
        ok('the maker cannot approve their own change', sqlcode = -20124);
    end;
    apex_session.create_session(l_app, 1, 'HOC1');
    xxfnd_approval_pkg.approve_change('XXCMP_RISK_FACTOR_SET:KYC');
    select approval_status || '|' || approved_points into l_txt from xxcmp_risk_factors where factor_code = 'COUNTRY_FATF_BLACK';
    ok('approved by another person: now in use ' || l_txt, l_txt = 'APPROVED|10');
    ok('the case scores with the approved change', xxcmp_risk_pkg.score(l_case) = l_score - 50);
    rollback;
    -- the approval task is created in its own transaction: cancel it (the change itself was rolled back)
    begin
        xxfnd_vpd_pkg.begin_trusted;
        -- the initiator cancels it
        for t in (select task_id, initiator from apex_tasks where task_def_static_id = 'CONFIG_CHANGE'
                     and detail_pk = 'XXCMP_RISK_FACTOR_SET:KYC' and state_code in ('UNASSIGNED', 'ASSIGNED')) loop
            apex_session.create_session(l_app, 1, t.initiator);
            apex_human_task.cancel_task(p_task_id => t.task_id);
        end loop;
        xxfnd_vpd_pkg.end_trusted;
        commit;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            dbms_output.put_line('cleanup: ' || sqlerrm);
    end;
    apex_session.delete_session;
end;
/
exit
