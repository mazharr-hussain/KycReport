-- Release 73 (KYC, run as XXCUS): approval workflow switched off = auto-approved request with its history row;
-- beneficial owner on the relationship (basis required); request Status in the details. Needs security_test.sql
-- (REQ1). Switches the KYC_REQUEST workflow back on at the end.
set serveroutput on size unlimited feedback off
declare
    l_app   number;
    l_tag   varchar2(20) := dbms_random.string('U', 10);
    l_req   number;
    l_r     xxcmp_requests%rowtype;
    l_n     number;
    l_html  clob;
    l_owner number;
    l_start timestamp with time zone := systimestamp;
    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
    procedure switch(p_flag varchar2) is
    begin
        execute immediate 'update xxfnd_workflow_processes set workflow_enabled_flag = :f
                            where application_code = ''KYC'' and process_code = ''KYC_REQUEST''' using p_flag;
        commit;
    end;
begin
    select application_id into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'KYC';
    apex_session.create_session(l_app, 1, 'REQ1');
    switch('N');
    ok('KYC_REQUEST workflow switched off', xxfnd_workflow_switch_pkg.workflow_enabled('KYC_REQUEST', 'KYC') = 'N');
    xxcmp_request_pkg.save_request(l_req, 'NEW', null, 'ORGANIZATION', 'Auto Org ' || l_tag, 'AE', 'AU-' || l_tag, 'LLC',
                                   date '2015-01-01', 'auto@example.com', null, null, null, 'FINANCE', 'Auto approval test',
                                   'N', p_registration_type => 'COMMERCIAL_REGISTRATION', p_business_relationship => 'VENDOR');
    update xxcmp_request_answers x
       set answer_option_id = (select max(o.answer_option_id) keep (dense_rank first order by o.risk_points)
                                 from xxcmp_answer_options o where o.question_id = x.question_id and o.approval_status = 'APPROVED')
     where x.request_id = l_req;
    xxcmp_request_pkg.submit(l_req);
    commit;
    xxfnd_vpd_pkg.begin_trusted;
    select * into l_r from xxcmp_requests where request_id = l_req;
    xxfnd_vpd_pkg.end_trusted;
    ok('auto-approved: no workflow, auto-approved date set', l_r.workflow_id is null and l_r.auto_approved_date is not null);
    ok('the request moved on without approval: ' || l_r.request_status, l_r.request_status <> 'IN_PROGRESS');
    select count(*) into l_n from table(xxcmp_approval_pkg.history_rows(l_req)) where action = 'Auto-approved (workflow disabled)';
    ok('history shows "Auto-approved (workflow disabled)"', l_n = 1);
    select count(*) into l_n from apex_tasks where detail_pk = to_char(l_req) and task_def_static_id = 'DOC_CHECKLIST_REVIEW'
       and created_on >= l_start;
    ok('no approval task was created', l_n = 0);
    l_html := xxcmp_request_ui_pkg.details_html(l_req);
    ok('request details show the Status', dbms_lob.instr(l_html, '>Status<') > 0);
    switch('Y');

    -- beneficial owner on the relationship
    xxfnd_vpd_pkg.begin_trusted;
    select max(party_id) into l_owner from xxcmp_parties where party_id <> l_r.party_id and enabled_flag = 'Y' and party_type = 'PERSON';
    begin
        insert into xxcmp_party_relationships (object_party_id, subject_party_id, relationship_type, ownership_percentage,
                                               start_date, beneficial_owner_flag)
        values (l_r.party_id, l_owner, 'SHAREHOLDER', 30, trunc(sysdate), 'Y');
        ok('a beneficial owner without a basis is refused', false);
    exception when others then
        ok('a beneficial owner without a basis is refused (' || regexp_substr(sqlerrm, 'XXCMP_PARTY_REL_CK8') || ')', sqlcode = -2290);
    end;
    insert into xxcmp_party_relationships (object_party_id, subject_party_id, relationship_type, ownership_percentage,
                                           start_date, beneficial_owner_flag, ubo_basis)
    values (l_r.party_id, l_owner, 'SHAREHOLDER', 30, trunc(sysdate), 'Y', 'OWNERSHIP');
    ok('owners list shows the beneficial owner',
       dbms_lob.instr(xxcmp_party_pkg.owners_json(l_r.party_id, null), 'Yes - ') > 0);
    begin
        insert into xxcmp_party_relationships (object_party_id, subject_party_id, relationship_type, start_date)
        values (l_r.party_id, l_r.party_id, 'DIRECTOR', trunc(sysdate));
        ok('a party cannot own itself', false);
    exception when others then
        ok('a party cannot own itself (XXCMP_PARTY_REL_CK1)', sqlcode = -2290);
    end;
    xxfnd_vpd_pkg.end_trusted;
    rollback;
exception
    when others then
        switch('Y');
        raise;
end;
/
exit
