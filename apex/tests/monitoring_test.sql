-- Chunk 6: monitoring watchlist, periodic reviews, early reassessment and alert rules, in APEX sessions.
-- Needs at least three approved parties without an open request (run kyc_flow_test.sql / kyc_ui.py first).
-- Moves review dates of closed cases: the case lock trigger is disabled for the test and enabled again.
set serveroutput on size unlimited feedback off
declare
    l_app    number;
    l_case1  number;  l_party1 number;
    l_case2  number;  l_party2 number;
    l_case3  number;  l_party3 number;
    l_case4  number;
    l_req    number;
    l_cnt    number;
    l_new    number;
    l_txt    varchar2(4000);
    l_w      xxcmp_watchlist_v%rowtype;

    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
    procedure session_as(p_user varchar2) is
    begin
        if apex_application.g_instance is not null then
            apex_session.delete_session;
        end if;
        apex_session.create_session(l_app, 1, p_user);
    end;
    function watch(p_case number) return xxcmp_watchlist_v%rowtype is
        l xxcmp_watchlist_v%rowtype;
    begin
        select * into l from xxcmp_watchlist_v where case_id = p_case;
        return l;
    end;
    procedure set_review(p_case number, p_date date) is
    begin
        update xxcmp_cases set next_review_date = p_date where case_id = p_case;
    end;
begin
    select application_id into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'KYC';
    execute immediate 'alter trigger xxcmp_cases_lock disable';
    session_as('OFFICER1');
    -- three approved parties with nothing in progress
    select max(case when rn = 1 then case_id end), max(case when rn = 1 then party_id end),
           max(case when rn = 2 then case_id end), max(case when rn = 2 then party_id end),
           max(case when rn = 3 then case_id end), max(case when rn = 3 then party_id end)
      into l_case1, l_party1, l_case2, l_party2, l_case3, l_party3
      from (select w.*, row_number() over (order by w.case_id desc) rn
              from xxcmp_watchlist_v w where w.review_request_id is null);
    -- needs three approved parties (the browser tests approve them): without them the test is skipped
    if l_case3 is null then
        dbms_output.put_line('SKIP monitoring checks (fewer than three approved parties on the watchlist yet)');
        execute immediate 'alter trigger xxcmp_cases_lock enable';
        return;
    end if;
    ok('three approved parties on the watchlist', l_case3 is not null);

    ------------------------------------------------------------ watchlist status
    set_review(l_case1, trunc(sysdate) + 200);
    ok('review in 200 days -> ' || watch(l_case1).review_status, watch(l_case1).review_status = 'CURRENT');
    set_review(l_case1, trunc(sysdate) + 10);
    ok('review in 10 days (lead 30) -> ' || watch(l_case1).review_status, watch(l_case1).review_status = 'DUE');
    set_review(l_case2, trunc(sysdate) - 5);
    ok('review 5 days ago -> ' || watch(l_case2).review_status, watch(l_case2).review_status = 'OVERDUE');
    set_review(l_case3, trunc(sysdate) + 300);
    commit;

    ------------------------------------------------------------ alerts
    l_new := xxcmp_monitor_pkg.run_alerts;
    select count(*) into l_cnt from xxcmp_alerts a join xxcmp_alert_rules r on r.alert_rule_id = a.alert_rule_id
     where a.case_id = l_case1 and r.alert_type = 'REVIEW_DUE' and a.alert_status = 'OPEN';
    ok('REVIEW_DUE alert for the party due in 10 days', l_cnt = 1);
    select count(*) into l_cnt from xxcmp_alerts a join xxcmp_alert_rules r on r.alert_rule_id = a.alert_rule_id
     where a.case_id = l_case2 and r.alert_type = 'REVIEW_OVERDUE';
    ok('REVIEW_OVERDUE alert for the overdue party', l_cnt = 1);
    l_new := xxcmp_monitor_pkg.run_alerts;
    select count(*) into l_cnt from xxcmp_alerts where case_id in (l_case1, l_case2);
    ok('running again raises nothing new (' || l_new || ' new, ' || l_cnt || ' alerts for the two cases)', l_cnt = 2);
    ok('the watchlist counts the open alert', watch(l_case1).open_alerts = 1);
    select max(alert_id) into l_cnt from xxcmp_alerts where case_id = l_case2;
    xxcmp_monitor_pkg.acknowledge(l_cnt);
    select alert_status || ' by ' || acknowledged_by into l_txt from xxcmp_alerts where alert_id = l_cnt;
    ok('alert acknowledged: ' || l_txt, l_txt = 'ACKNOWLEDGED by OFFICER1');
    commit;

    ------------------------------------------------------------ periodic reviews
    l_cnt := xxcmp_monitor_pkg.start_periodic_reviews;
    commit;
    l_w := watch(l_case1);
    ok(l_cnt || ' periodic review(s) started; the due party is now ' || l_w.review_status || ' (' || l_w.review_request_number || ')',
       l_cnt = 2 and l_w.review_status = 'IN_REVIEW');
    select request_type || '/' || trigger_source || '/' || parent_case_id into l_txt
      from xxcmp_requests where request_id = l_w.review_request_id;
    ok('review request: ' || l_txt, l_txt = 'PERIODIC_REVIEW/SCHEDULED/' || l_case1);
    select count(*) into l_cnt from xxcmp_alerts where case_id = l_case1 and alert_status = 'OPEN';
    ok('the review closed the party''s alerts', l_cnt = 0);
    ok('the overdue party stays OVERDUE while its review runs', watch(l_case2).review_status = 'OVERDUE'
       and watch(l_case2).review_request_id is not null);
    l_cnt := xxcmp_monitor_pkg.start_periodic_reviews;
    ok('no second review while one is open (' || l_cnt || ' started)', l_cnt = 0);
    -- the review runs through the KYC_REQUEST workflow like any request
    for i in 1 .. 90 loop
        select count(*) into l_cnt from apex_tasks
         where task_def_static_id = 'DOC_CHECKLIST_REVIEW' and detail_pk = to_char(l_w.review_request_id);
        exit when l_cnt > 0;
        dbms_session.sleep(1);
    end loop;
    ok('the review went to Compliance (checklist task)', l_cnt = 1);

    ------------------------------------------------------------ early reassessment
    l_txt := xxcmp_monitor_pkg.early_review_error(l_case1);
    ok('early reassessment refused while a review is open: ' || l_txt, l_txt like '%already in progress%');
    begin
        l_req := xxcmp_monitor_pkg.trigger_early_review(l_case3, null);
        ok('a reason is required', false);
    exception when others then
        ok('a reason is required: ' || regexp_substr(substr(sqlerrm, 12), '[^' || chr(10) || ']+'), true);
    end;
    l_req := xxcmp_monitor_pkg.trigger_early_review(l_case3, 'Negative press about the owners.');
    commit;
    select request_type || '/' || trigger_source || '/' || justification into l_txt from xxcmp_requests where request_id = l_req;
    ok('early reassessment: ' || l_txt, l_txt = 'EVENT_TRIGGERED_REVIEW/MANUAL/Negative press about the owners.');

    ------------------------------------------------------------ adverse screening
    -- a new sanctions hit on a party approved earlier starts an early review by itself
    select max(w.case_id) into l_case4 from xxcmp_watchlist_v w
     where w.review_request_id is null and w.case_id not in (l_case1, l_case2, l_case3);
    if l_case4 is null then
        ok('a fourth approved party for the adverse screening check', false);
    else
        insert into xxcmp_screenings (case_id, party_id, screening_type, match_status, sanctions_flag, capture_method)
        select case_id, party_id, 'SANCTIONS', 'CONFIRMED_MATCH', 'Y', 'MANUAL' from xxcmp_cases where case_id = l_case4;
        commit;
        l_new := xxcmp_monitor_pkg.run_alerts;
        commit;
        select count(*) into l_cnt from xxcmp_alerts a join xxcmp_alert_rules r on r.alert_rule_id = a.alert_rule_id
         where a.case_id = l_case4 and r.alert_type = 'ADVERSE_SCREENING' and a.review_request_id is not null;
        l_w := watch(l_case4);
        ok('adverse screening -> alert and automatic review ' || l_w.review_request_number, l_cnt = 1 and l_w.review_request_id is not null);
        select trigger_source into l_txt from xxcmp_requests where request_id = l_w.review_request_id;
        ok('automatic review is event-driven: ' || l_txt, l_txt = 'EVENT_DRIVEN');
    end if;

    execute immediate 'alter trigger xxcmp_cases_lock enable';
    apex_session.delete_session;
exception
    when others then
        execute immediate 'alter trigger xxcmp_cases_lock enable';
        raise;
end;
/
exit
