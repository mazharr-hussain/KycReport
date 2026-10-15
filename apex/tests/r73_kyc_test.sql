-- Release 73 (KYC, run as XXCUS): approval workflow switched off = auto-approved request with its history row;
-- beneficial owner on the relationship (basis required); request Status in the details. Needs security_test.sql
-- (REQ1). Switches the KYC_REQUEST workflow back on at the end. Request Information by an approver who is the
-- requester (any open document checklist task whose initiator is a potential owner; rolled back).
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
    ok('KYC_REQUEST workflow switched off', xxfnd_workflow_pkg.workflow_enabled('KYC_REQUEST', 'KYC') = 'N');
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
    l_html := xxcmp_request_ui_pkg.details_json(l_req);     -- release 74: data, no HTML
    ok('request details show the Status', dbms_lob.instr(l_html, '"label":"Status"') > 0);
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

    -- Request Information when the approver is the requester
    declare
        l_task number;
        l_user varchar2(255);
        l_rid  number;
    begin
        select max(t.task_id), max(t.initiator) keep (dense_rank last order by t.task_id),
               max(to_number(t.detail_pk)) keep (dense_rank last order by t.task_id)
          into l_task, l_user, l_rid
          from apex_tasks t
         where t.task_def_static_id = 'DOC_CHECKLIST_REVIEW' and t.state_code in ('UNASSIGNED', 'ASSIGNED')
           and exists (select 1 from apex_task_participants p where p.task_id = t.task_id
                          and p.participant_type = 'POTENTIAL_OWNER' and upper(p.participant) = upper(t.initiator));
        if l_task is null then
            dbms_output.put_line('SKIP no open task whose approver is the requester');
        else
            apex_session.create_session(l_app, 1, l_user);
            ok('approver = requester: APEX cannot ask, the page uses return_for_info', xxcmp_request_pkg.can_request_info(l_task) = 'N');
            begin
                xxcmp_request_pkg.return_for_info(l_rid, l_task, null);
                ok('a comment is required', false);
            exception when others then
                ok('a comment is required', sqlcode = -20625);
            end;
            for t in (select 1 from apex_tasks where task_id = l_task and state_code = 'UNASSIGNED') loop
                apex_human_task.claim_task(p_task_id => l_task);
            end loop;
            xxcmp_request_pkg.return_for_info(l_rid, l_task, 'Please attach the trade licence ' || l_tag);
            xxfnd_vpd_pkg.begin_trusted;
            select * into l_r from xxcmp_requests where request_id = l_rid;
            xxfnd_vpd_pkg.end_trusted;
            ok('request back with the requester (Information needed)', l_r.request_status = 'INFO_NEEDED'
               and xxcmp_request_pkg.returned_for_info(l_rid) = 'Y');
            select count(*) into l_n from apex_workflows where workflow_id = l_r.workflow_id and state_code = 'TERMINATED';
            ok('the approval workflow ended', l_n = 1);
            select count(*) into l_n from table(xxcmp_approval_pkg.history_rows(l_rid))
             where action = 'Information requested' and comments like '%' || l_tag;
            ok('history shows the question', l_n = 1);
            select count(*) into l_n from table(xxcmp_approval_pkg.history_rows(l_rid))
             where action = 'Withdrawn' and action_date >= l_start;
            ok('not shown as Withdrawn', l_n = 0);
            ok('the requester can submit again: ' || nvl(xxcmp_request_pkg.submit_error(l_rid), 'no error'),
               nvl(xxcmp_request_pkg.submit_error(l_rid), '#') <> 'This request has already been submitted.');
            rollback;
        end if;
    end;
exception
    when others then
        switch('Y');
        raise;
end;
/
exit
