--------------------------------------------------------------------------------
-- 18e KYC requests and cases - seed (release R13)
-- Lookups, attachment entities, KYC parameters, starter questionnaires, data
-- security rules, page mapping and task deadlines for Module 1 and Module 2.
-- Idempotent; everything an administrator maintains is insert-only.
--------------------------------------------------------------------------------
declare
    c_staff constant varchar2(200) := 'COMPLIANCE_OFFICER,COMPLIANCE_MANAGER,HEAD_OF_COMPLIANCE';

    procedure lt(p_type in varchar2, p_meaning in varchar2, p_level in varchar2 default 'S') is
    begin
        merge into xxfnd_lookup_types t using (select p_type lookup_type from dual) s on (t.lookup_type = s.lookup_type)
         when not matched then insert (lookup_type, meaning, customization_level, application_code)
                               values (p_type, p_meaning, p_level, 'KYC');
    end lt;

    -- 'CODE=Meaning|CODE=Meaning' ; 'CODE=Meaning=TAG' sets the tag
    procedure lvs(p_type in varchar2, p_list in varchar2) is
        l_parts apex_t_varchar2;
        l_seq   pls_integer := 0;
        l_tag   varchar2(150);
    begin
        for v in (select column_value item from table(apex_string.split(p_list, '|'))) loop
            l_seq   := l_seq + 10;
            l_parts := apex_string.split(v.item, '=');
            l_tag   := case when l_parts.count > 2 then l_parts(3) end;   -- collection attributes: not inside SQL
            merge into xxfnd_lookup_values t
            using (select p_type lookup_type, l_parts(1) lookup_code from dual) s
               on (t.lookup_type = s.lookup_type and t.lookup_code = s.lookup_code)
             when not matched then insert (lookup_type, lookup_code, meaning, display_sequence, tag)
                                   values (p_type, l_parts(1), l_parts(2), l_seq, l_tag);
        end loop;
    end lvs;

    procedure entity(p_name in varchar2, p_user_name in varchar2, p_pk in varchar2) is
    begin
        merge into xxfnd_document_entities t using (select p_name entity_name from dual) s
           on (t.entity_name = s.entity_name)
         when matched then update set t.enabled_flag = 'Y' where t.table_name = p_name and t.enabled_flag = 'N'
         when not matched then insert (entity_name, application_code, table_name, pk1_column, enabled_flag)
                               values (p_name, 'KYC', p_name, p_pk, 'Y');
        merge into xxfnd_document_entities_tl t
        using (select p_name entity_name, 'en' language_code from dual) s
           on (t.entity_name = s.entity_name and t.language_code = s.language_code)
         when not matched then insert (entity_name, language_code, user_entity_name) values (p_name, 'en', p_user_name);
    end entity;

    function question(p_qnr in varchar2, p_seq in number, p_text in varchar2, p_type in varchar2,
                      p_gate in varchar2 default 'N', p_required in varchar2 default 'Y',
                      p_section in varchar2 default null) return number is
        l_id number;
    begin
        insert into xxcmp_questions (questionnaire_code, question_text, answer_type, gate_question_flag, required_flag,
                                     display_sequence, section_name)
        values (p_qnr, p_text, p_type, p_gate, p_required, p_seq, p_section)
        returning question_id into l_id;
        return l_id;
    end question;

    procedure answer(p_question in number, p_seq in number, p_label in varchar2, p_points in number,
                     p_critical in varchar2 default 'N', p_waiver in varchar2 default 'N') is
    begin
        insert into xxcmp_answer_options (question_id, answer_label, risk_points, critical_flag, waiver_qualifying_flag,
                                          display_sequence, approval_status)
        values (p_question, p_label, p_points, p_critical, p_waiver, p_seq, 'APPROVED');
    end answer;

    procedure starter_questions is
        l_q     number;
        l_count pls_integer;
    begin
        -- Starter content only for questionnaires that have no questions yet.
        select count(*) into l_count from xxcmp_questions where questionnaire_code = 'CORPORATE';
        if l_count = 0 then
            l_q := question('CORPORATE', 10, 'Is the counterparty listed on a regulated stock exchange, or a government entity?', 'YES_NO', p_gate => 'Y');
            answer(l_q, 10, 'Yes', 0, p_waiver => 'Y');
            answer(l_q, 20, 'No', 0);
            l_q := question('CORPORATE', 20, 'Risk of the country of incorporation', 'SINGLE_SELECT');
            answer(l_q, 10, 'Low-risk jurisdiction', 0);
            answer(l_q, 20, 'Medium-risk jurisdiction', 5);
            answer(l_q, 30, 'High-risk or sanctioned jurisdiction', 20, p_critical => 'Y');
            l_q := question('CORPORATE', 30, 'Expected annual transaction volume', 'SINGLE_SELECT');
            answer(l_q, 10, 'Below 1 million', 0);
            answer(l_q, 20, '1 to 10 million', 5);
            answer(l_q, 30, 'Above 10 million', 10);
            l_q := question('CORPORATE', 40, 'Is any owner, director or signatory a politically exposed person?', 'YES_NO');
            answer(l_q, 10, 'Yes', 15, p_critical => 'Y');
            answer(l_q, 20, 'No', 0);
            l_q := question('CORPORATE', 50, 'Is the business cash-intensive?', 'YES_NO');
            answer(l_q, 10, 'Yes', 10);
            answer(l_q, 20, 'No', 0);
        end if;
        select count(*) into l_count from xxcmp_questions where questionnaire_code = 'INDIVIDUAL';
        if l_count = 0 then
            l_q := question('INDIVIDUAL', 10, 'Is the individual an employee of the organisation acting in that capacity?', 'YES_NO', p_gate => 'Y');
            answer(l_q, 10, 'Yes', 0, p_waiver => 'Y');
            answer(l_q, 20, 'No', 0);
            l_q := question('INDIVIDUAL', 20, 'Risk of the country of residence', 'SINGLE_SELECT');
            answer(l_q, 10, 'Low-risk jurisdiction', 0);
            answer(l_q, 20, 'Medium-risk jurisdiction', 5);
            answer(l_q, 30, 'High-risk or sanctioned jurisdiction', 20, p_critical => 'Y');
            l_q := question('INDIVIDUAL', 30, 'Is the individual a politically exposed person?', 'YES_NO');
            answer(l_q, 10, 'Yes', 15, p_critical => 'Y');
            answer(l_q, 20, 'No', 0);
        end if;
        select count(*) into l_count from xxcmp_questions where questionnaire_code = 'OFFICER_INVESTIGATION';
        if l_count = 0 then
            l_q := question('OFFICER_INVESTIGATION', 10, 'Summary of findings', 'TEXT', p_required => 'N', p_section => 'Findings');
            l_q := question('OFFICER_INVESTIGATION', 20, 'Source of funds', 'TEXT', p_required => 'N', p_section => 'Enhanced Due Diligence');
            l_q := question('OFFICER_INVESTIGATION', 30, 'Source of wealth', 'TEXT', p_required => 'N', p_section => 'Enhanced Due Diligence');
        end if;
    end starter_questions;

    procedure page(p_feature in varchar2, p_page in number, p_tab in varchar2 default null, p_seq in number default null) is
    begin
        merge into xxfnd_feature_pages d
        using (select 'KYC' app_alias, p_page page_id from dual) s
           on (d.app_alias = s.app_alias and d.page_id = s.page_id)
         when matched then update set d.feature_code = p_feature,
                                      d.tab_label    = nvl(d.tab_label, p_tab),
                                      d.tab_sequence = nvl(d.tab_sequence, p_seq)
         when not matched then insert (app_alias, page_id, feature_code, tab_label, tab_sequence)
                               values ('KYC', p_page, p_feature, p_tab, p_seq);
    end page;

    procedure rule(p_role in varchar2, p_table in varchar2, p_type in varchar2, p_column in varchar2 default null) is
    begin
        merge into xxfnd_data_security_rules t
        using (select p_role r, p_table tb, p_type ty from dual) s
           on (t.role_code = s.r and t.table_name = s.tb and t.rule_type = s.ty)
         when not matched then insert (role_code, table_name, rule_type, column_name)
                               values (p_role, p_table, p_type, p_column);
    end rule;

    procedure task_setting(p_task in varchar2, p_due in number, p_reminder in number, p_role in varchar2, p_desc in varchar2) is
    begin
        merge into xxfnd_task_settings t using (select p_task task_definition from dual) s
           on (t.task_definition = s.task_definition)
         when not matched then insert (task_definition, due_days, reminder_days_before, escalation_role_code, description)
                               values (p_task, p_due, p_reminder, p_role, p_desc);
    end task_setting;
begin
    xxfnd_util_pkg.set_install_mode(true);

    lt('KYC_REQUEST_TYPE', 'KYC Request Types');
    lvs('KYC_REQUEST_TYPE', 'NEW_ONBOARDING=New onboarding|PERIODIC_REVIEW=Periodic review|EVENT_TRIGGERED_REVIEW=Event-triggered review');
    lt('KYC_TRIGGER_SOURCE', 'KYC Request Trigger Sources');
    lvs('KYC_TRIGGER_SOURCE', 'MANUAL=Manual|SCHEDULED=Scheduled|EVENT_DRIVEN=Event driven');
    lt('KYC_REQUEST_STATUS', 'KYC Request Status');
    lvs('KYC_REQUEST_STATUS', 'DRAFT=Draft|SUBMITTED=Submitted|IN_PROGRESS=In progress|COMPLETED=Completed|REJECTED=Rejected|CANCELLED=Cancelled');
    lt('KYC_INTAKE_OUTCOME', 'KYC Intake Outcomes');
    lvs('KYC_INTAKE_OUTCOME', 'NOT_REQUIRED=KYC not required|AUTO_APPROVED=Auto-approved|ASSIGNED=Assigned to Compliance');
    lt('CASE_STATUS', 'Case Status');
    lvs('CASE_STATUS', 'INVESTIGATION=Under investigation|PENDING_APPROVAL=Pending approval|APPROVED=Approved|REJECTED=Rejected|CANCELLED=Cancelled');
    lt('SCREENING_TYPE', 'Screening Types');
    lvs('SCREENING_TYPE', 'REGISTRY=Registry check|SANCTIONS=Sanctions|PEP=Politically exposed person|ADVERSE_MEDIA=Adverse media');
    lt('SCREENING_MATCH_STATUS', 'Screening Match Status');
    lvs('SCREENING_MATCH_STATUS', 'NO_MATCH=No match|POTENTIAL_MATCH=Potential match|CONFIRMED_MATCH=Confirmed match|FALSE_POSITIVE=False positive');
    lt('DOC_VERIFICATION_STATUS', 'Document Verification Status');
    lvs('DOC_VERIFICATION_STATUS', 'VERIFIED=Verified|REJECTED=Rejected|EXPIRED=Expired');
    lt('UBO_BASIS', 'Beneficial Ownership Basis');
    lvs('UBO_BASIS', 'OWNERSHIP=Ownership|CONTROL=Control|FALLBACK=Fallback (senior managing official)');
    lt('REQUESTING_DEPARTMENT', 'Requesting Departments', 'E');
    lvs('REQUESTING_DEPARTMENT', 'FINANCE=Finance|PROCUREMENT=Procurement|SALES=Sales|TREASURY=Treasury|LEGAL=Legal|OTHER=Other');
    -- Parameters administrators maintain in Lookups (value in TAG).
    lt('KYC_PARAMETER', 'KYC Parameters', 'E');
    lvs('KYC_PARAMETER', 'CASE_SLA_DAYS=Case investigation SLA (days)=10|PEP_REVIEW_MONTHS=Review interval for PEP parties (months)=12'
        || '|REVIEW_LEAD_DAYS=Show upcoming reviews this many days ahead=30');
    -- Review interval per risk tier, in months (TAG), until an administrator sets another.
    update xxfnd_lookup_values set tag = decode(lookup_code, 'LOW', '36', 'MEDIUM', '24', 'HIGH', '12')
     where lookup_type = 'RISK_TIER' and tag is null;

    entity('XXCMP_REQUESTS', 'KYC Request', 'REQUEST_ID');
    entity('XXCMP_CASES', 'Case', 'CASE_ID');

    starter_questions;

    -- KYC Requests: list, wizard (3 steps), request; Cases: workbench, case, decision, screening, UBO, document verification, new case, compliance report.
    for p in (select column_value page_id from table(apex_t_number(200, 201, 202, 203, 205))) loop
        page('KYC_REQUESTS', p.page_id);
    end loop;
    for p in (select column_value page_id from table(apex_t_number(210, 211, 212, 213, 214, 215, 216, 217))) loop
        page('CASES', p.page_id);
    end loop;
    -- Attachments on the request (wizard step 3 and the request page) and the party documents on the case.
    merge into xxfnd_attachment_functions t
    using (select 'KYC_REQUEST_SUBMIT' function_code, 'Create Request - Submit' function_name, 203 page_id from dual
           union all select 'KYC_REQUEST', 'KYC Request', 205 from dual
           union all select 'KYC_CASE', 'Case', 211 from dual) s
       on (t.function_code = s.function_code)
     when matched then update set t.apex_page_id = s.page_id
     when not matched then insert (function_code, application_code, function_name, apex_app_alias, apex_page_id)
                           values (s.function_code, 'KYC', s.function_name, 'KYC', s.page_id);
    merge into xxfnd_attachment_blocks t
    using (select 'KYC_REQUEST_SUBMIT' function_code, 'ATTACHMENTS' block_code, 'request_attachments' region, 'Documents' name from dual
           union all select 'KYC_REQUEST', 'ATTACHMENTS', 'request_attachments', 'Documents' from dual
           union all select 'KYC_CASE', 'PARTY_DOCUMENTS', 'party_documents', 'Party Documents' from dual) s
       on (t.function_code = s.function_code and t.block_code = s.block_code)
     when not matched then insert (function_code, block_code, region_static_id, block_name, display_sequence)
                           values (s.function_code, s.block_code, s.region, s.name, 10);
    merge into xxfnd_attachment_blk_entities t
    using (select 'KYC_REQUEST_SUBMIT' function_code, 'ATTACHMENTS' block_code, 'XXCMP_REQUESTS' entity_name, 'P203_REQUEST_ID' item, 'Y' del from dual
           union all select 'KYC_REQUEST', 'ATTACHMENTS', 'XXCMP_REQUESTS', 'P205_REQUEST_ID', 'N' from dual
           union all select 'KYC_CASE', 'PARTY_DOCUMENTS', 'XXCMP_PARTIES', 'P211_PARTY_ID', 'N' from dual) s
       on (t.function_code = s.function_code and t.block_code = s.block_code and t.entity_name = s.entity_name)
     when not matched then insert (function_code, block_code, entity_name, pk1_page_item, delete_allowed_flag, display_sequence)
                           values (s.function_code, s.block_code, s.entity_name, s.item, s.del, 10);

    -- My Tasks tabs: the task list and the requests for information.
    page('MY_TASKS', 40, 'Tasks', 10);
    page('MY_TASKS', 30, 'Requests for Information', 20);

    -- Row access: requesters see their own requests; the Compliance team every request and case.
    for r in (select column_value role_code from table(apex_string.split(c_staff, ','))) loop
        rule(r.role_code, 'XXCMP_REQUESTS', 'ALL_ROWS');
        rule(r.role_code, 'XXCMP_CASES', 'ALL_ROWS');
    end loop;
    rule('REQUESTER', 'XXCMP_REQUESTS', 'OWN_RECORDS', 'REQUESTER_USER_NAME');

    -- KYC Requests: requesters raise and edit their own; Compliance views them and raises reviews.
    for g in (select 'REQUESTER' r, column_value p from table(apex_t_varchar2('KYC_REQUESTS.VIEW','KYC_REQUESTS.CREATE','KYC_REQUESTS.MANAGE'))
              union all
              select s.column_value, p.column_value
                from table(apex_string.split(c_staff, ',')) s,
                     table(apex_t_varchar2('KYC_REQUESTS.VIEW','KYC_REQUESTS.CREATE')) p) loop
        merge into xxfnd_role_privileges t using (select g.r role_code, g.p privilege_code from dual) s
           on (t.role_code = s.role_code and t.privilege_code = s.privilege_code)
         when not matched then insert (role_code, privilege_code) values (s.role_code, s.privilege_code);
    end loop;

    task_setting('DOC_CHECKLIST_REVIEW', 2, 1, 'COMPLIANCE_MANAGER', 'Compliance checks the documents of a request before investigation.');
    task_setting('CASE_INVESTIGATION', 10, 2, 'COMPLIANCE_MANAGER', 'The officer investigates the case.');
    task_setting('CASE_APPROVAL', 3, 1, 'HEAD_OF_COMPLIANCE', 'An approver decides the case (one task per approval level).');

    xxfnd_util_pkg.set_install_mode(false);
    commit;
    xxfnd_vpd_pkg.apply_policies;
    xxfnd_ddl_pkg.mark_release('R13', 'Release 13: KYC requests and cases (intake, investigation, approval workflows)');
    commit;
end;
/
