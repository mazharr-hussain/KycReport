-- KYC release 89 (run as XXCUS): information requests and e-mail through COMMON.
--   - KYC's own RFI pages (30-34) and task definitions (RFI_RESPONSE, RFI_REVIEW) are gone; COMMON has them.
--   - A case raises an RFI (XXCMP_CASE_PKG.RAISE_RFI); COMMON's workflow RFI asks the person (task of the COMMON
--     application), has the answer reviewed by the raiser and ends; XXCMP_CASE_PKG.RFI_TASK gives each user his open step
--     (the link to COMMON's task page 143).
--   - An outside person (contact of the party) gets COMMON's RFI_RAISED e-mail (link to COMMON's public page 50) and the
--     workflow waits for the answer.
--   - The documents of earlier KYC RFIs (entity XXCMP_RFIS) are registered view-only on the case page (211, region notes).
-- The APEX workflow engine runs in the background after each commit: this test commits and waits (settle).
-- Its rows are kept (RFIs on the newest case under investigation): nothing is deleted.
set serveroutput on size unlimited feedback off
declare
    l_app    number;
    l_common number;
    l_case   number;
    l_rfi    number;
    l_wf     number;
    l_task   number;
    l_n      number;
    l_v      varchar2(4000);
    l_cid    number;
    l_email  varchar2(320);
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
    procedure settle is
        l_busy number;
    begin
        commit;
        for i in 1 .. 90 loop
            dbms_session.sleep(2);
            select count(*) into l_busy from apex_workflows w
             where w.workflow_id = l_wf and w.state_code = 'ACTIVE'
               and not exists (select 1 from apex_workflow_activities a
                                where a.workflow_id = w.workflow_id and a.end_time is null
                                  and upper(a.state) in ('WAITING'));
            exit when l_busy = 0 and i > 1;
        end loop;
        dbms_session.sleep(2);
    end settle;
    function open_task(p_def varchar2) return number is
        l_id number;
    begin
        select max(task_id) into l_id from apex_tasks
         where workflow_id = l_wf and task_def_static_id = p_def and state_code in ('UNASSIGNED', 'ASSIGNED');
        return l_id;
    end open_task;
begin
    apex_util.set_workspace('XXCUS');   -- the dictionary shows both applications of the workspace
    select application_id into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'KYC';
    l_common := xxfnd_workflow_pkg.common_application_id;

    ---------------------------------------------------------------- the application
    select count(*) into l_n from apex_application_pages where application_id = l_app and page_id between 30 and 34;
    ok('KYC has no RFI / e-mail pages of its own (30-34): ' || l_n, l_n = 0);
    select count(*) into l_n from apex_appl_taskdefs where application_id = l_app and static_id in ('RFI_RESPONSE', 'RFI_REVIEW');
    ok('KYC has no RFI task definitions of its own: ' || l_n, l_n = 0);
    select count(*) into l_n from apex_appl_taskdefs where application_id = l_common and static_id in ('RFI_RESPONSE', 'RFI_REVIEW');
    ok('COMMON has them (' || l_n || ')', l_n = 2);
    select count(*) into l_n from apex_application_pages
     where application_id = l_common and page_id in (40, 45, 46, 47, 50, 143);
    ok('COMMON has the pages KYC opens (My Tasks 40, Communications 45, E-mail 46, Attachments 47, Provide Information 50, Information Request 143): ' || l_n, l_n = 6);
    select count(*) into l_n from apex_application_page_items
     where application_id = l_app and page_id = 211
       and item_name in ('P211_RFI_RECIPIENT_TYPE', 'P211_RFI_USER', 'P211_RFI_CATEGORY', 'P211_RFI_DESCRIPTION',
                         'P211_RFI_CONTINUE', 'P211_RFI_DUE_DATE');
    ok('the case page raises the RFI itself (dialog items: ' || l_n || ')', l_n = 6);
    select count(*) into l_n from apex_application_page_proc
     where application_id = l_app and page_id = 211 and process_name = 'Raise RFI'
       and lower(process_source) like '%xxcmp_case_pkg.raise_rfi%';
    ok('its process calls XXCMP_CASE_PKG.RAISE_RFI', l_n = 1);
    select count(*) into l_n from user_objects where object_name = 'XXCMP_CASE_PKG' and status <> 'VALID';
    ok('XXCMP_CASE_PKG is valid', l_n = 0);
    select count(*) into l_n from user_source
     where name = 'XXCMP_CASE_PKG' and type = 'PACKAGE BODY' and lower(text) like '%p_page => 33%';
    ok('RAISE_RFI no longer links to KYC page 33', l_n = 0);

    ---------------------------------------------------------------- a case RFI to a colleague: answer, review, end
    session_as('OFFICER1');
    xxfnd_vpd_pkg.begin_trusted;
    select max(case_id) into l_case from xxcmp_cases where case_status = 'INVESTIGATION';
    xxfnd_vpd_pkg.end_trusted;
    if l_case is null then
        dbms_output.put_line('SKIP no case under investigation');
        return;
    end if;
    xxcmp_case_pkg.raise_rfi('XXCMP_CASES', to_char(l_case), 'REQUESTING_DEPARTMENT', 'REQ1', null,
                             'CLARIFICATION', 'R89 please confirm the trade licence number', 'Y', trunc(sysdate) + 7);
    select max(rfi_id) into l_rfi from xxfnd_rfis where entity_name = 'XXCMP_CASES' and pk1_value = to_char(l_case);
    select workflow_id, application_code into l_wf, l_v from xxfnd_rfis where rfi_id = l_rfi;
    settle;
    ok('raised from the case: a KYC RFI (' || l_v || ') in COMMON''s workflow RFI (' || xxfnd_workflow_pkg.state(l_wf) || ')',
       l_v = 'KYC' and xxfnd_workflow_pkg.state(l_wf) = 'ACTIVE');
    l_task := open_task('RFI_RESPONSE');
    select count(*) into l_n from apex_tasks where task_id = l_task and application_id = l_common;
    ok('the workflow asks REQ1 (RFI_RESPONSE task of COMMON: ' || l_task || ')', l_n = 1);
    ok('OFFICER1 has no step to take yet', xxcmp_case_pkg.rfi_task(l_rfi) is null);
    session_as('REQ1');
    ok('REQ1''s open step is that task (the link to COMMON page 143)', xxcmp_case_pkg.rfi_task(l_rfi) = l_task);
    session_as('REQ2');
    ok('REQ2 has none', xxcmp_case_pkg.rfi_task(l_rfi) is null);

    session_as('REQ1');
    xxfnd_rfi_pkg.respond(l_rfi, 'R89 the number is 12345');
    settle;
    l_task := open_task('RFI_REVIEW');
    ok('answered: the workflow has it reviewed (RFI_REVIEW ' || l_task || ')', l_task is not null);
    ok('REQ1 has no step any more', xxcmp_case_pkg.rfi_task(l_rfi) is null);
    session_as('OFFICER1');
    ok('OFFICER1 (who raised it) reviews it', xxcmp_case_pkg.rfi_task(l_rfi) = l_task);
    xxfnd_rfi_pkg.resolve(l_rfi, 'RESOLVED', 'R89 complete');
    settle;
    ok('resolved: the workflow ends (' || xxfnd_workflow_pkg.state(l_wf) || ') and no step is left',
       xxfnd_workflow_pkg.state(l_wf) = 'COMPLETED' and xxcmp_case_pkg.rfi_task(l_rfi) is null);

    ---------------------------------------------------------------- an outside person: COMMON's e-mail and public page
    xxfnd_vpd_pkg.begin_trusted;
    select max(party_contact_id), max(email) keep (dense_rank last order by party_contact_id) into l_cid, l_email
      from xxcmp_party_contacts where email is not null and enabled_flag = 'Y';
    xxfnd_vpd_pkg.end_trusted;
    if l_cid is null then
        dbms_output.put_line('SKIP no contact person with an e-mail');
    else
        xxcmp_case_pkg.raise_rfi('XXCMP_CASES', to_char(l_case), 'EXTERNAL_PARTY', null, l_cid,
                                 'CLARIFICATION', 'R89 send the audited accounts', 'Y', trunc(sysdate) + 7);
        select max(rfi_id) into l_rfi from xxfnd_rfis where entity_name = 'XXCMP_CASES' and pk1_value = to_char(l_case);
        select workflow_id into l_wf from xxfnd_rfis where rfi_id = l_rfi;
        settle;
        select count(*) into l_n from xxfnd_notifications
         where detail_pk = to_char(l_rfi) and event_code = 'RFI_RAISED' and channel_code = 'EMAIL'
           and lower(email_address) = lower(l_email) and user_name is null;
        ok('the contact person gets COMMON''s RFI_RAISED e-mail (' || l_n || ')', l_n = 1);
        select count(*) into l_n from apex_workflow_activities
         where workflow_id = l_wf and static_id = 'WAIT_ANSWER' and end_time is null;
        ok('the workflow waits for the answer on COMMON''s public page', l_n = 1);
        xxfnd_rfi_pkg.resolve(l_rfi, 'CANCELLED', 'R89 test cleanup');
        settle;
        ok('cancelled: the workflow ends (' || xxfnd_workflow_pkg.state(l_wf) || ')',
           xxfnd_workflow_pkg.state(l_wf) in ('TERMINATED', 'COMPLETED'));
    end if;

    ---------------------------------------------------------------- documents of earlier KYC RFIs (history)
    select count(*) into l_n
      from xxfnd_attachment_blocks b
      join xxfnd_attachment_blk_entities e on e.function_code = b.function_code and e.block_code = b.block_code
     where b.function_code = 'KYC_CASE' and b.block_code = 'RFI_DOCUMENTS' and lower(b.region_static_id) = 'notes'
       and e.entity_name = 'XXCMP_RFIS' and e.insert_allowed_flag = 'N' and e.update_allowed_flag = 'N'
       and e.delete_allowed_flag = 'N';
    ok('RFI documents (XXCMP_RFIS) registered view-only on the case page (211, region notes)', l_n = 1);
    ok('nobody may add RFI documents there',
       xxfnd_attach_pkg.block_permission('KYC', 211, 'notes', 'XXCMP_RFIS', 'INSERT') = 'N');
    commit;
    apex_session.delete_session;
end;
/
exit
