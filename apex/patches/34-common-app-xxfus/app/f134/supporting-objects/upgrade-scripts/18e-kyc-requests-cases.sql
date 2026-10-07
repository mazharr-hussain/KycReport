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

    -- release 26: the type of an organisation's registration number, and what a counterparty is to the company
    lt('REGISTRATION_TYPE', 'Registration Types');
    lvs('REGISTRATION_TYPE', 'COMMERCIAL_REGISTRATION=Commercial Registration|TRADE_LICENCE=Trade Licence|TAX_NUMBER=Tax / VAT Number|OTHER=Other');
    lt('BUSINESS_RELATIONSHIP', 'Business Relationships');
    lvs('BUSINESS_RELATIONSHIP', 'CUSTOMER=Customer|VENDOR=Vendor / Supplier|PARTNER=Partner|AGENT=Agent / Intermediary|OTHER=Other');
    -- release 27: the sections of the case screen (labels; codes fixed in XXCMP_CASE_PKG.C_SECTIONS)
    lt('CASE_SECTION', 'Case Screen Sections');
    -- release 42: the Ownership Tree section
    lvs('CASE_SECTION', 'SUMMARY=Summary|PARTY=Party|TREE=Ownership Tree|SCREENING=Screening|DOCUMENTS=Documents|RISK=Risk Assessment|NOTES=Notes and RFIs|REVIEW=Review and Submit');
    -- release 29: Contacts and Ownership is part of Party
    update xxfnd_lookup_values set enabled_flag = 'N' where lookup_type = 'CASE_SECTION' and lookup_code = 'OWNERSHIP';
    lt('KYC_REQUEST_TYPE', 'KYC Request Types');
    lvs('KYC_REQUEST_TYPE', 'NEW_ONBOARDING=New onboarding|PERIODIC_REVIEW=Periodic review|EVENT_TRIGGERED_REVIEW=Event-triggered review');
    lt('KYC_TRIGGER_SOURCE', 'KYC Request Trigger Sources');
    lvs('KYC_TRIGGER_SOURCE', 'MANUAL=Manual|SCHEDULED=Scheduled|EVENT_DRIVEN=Event driven');
    lt('KYC_REQUEST_STATUS', 'KYC Request Status');
    lvs('KYC_REQUEST_STATUS', 'DRAFT=Draft|IN_PROGRESS=In Progress|INFO_NEEDED=Information Needed|APPROVED=Approved'
        || '|REJECTED=Rejected|CANCELLED=Cancelled');
    -- release 23: Submitted and Completed became In Progress and Approved
    update xxfnd_lookup_values set enabled_flag = 'N'
     where lookup_type = 'KYC_REQUEST_STATUS' and lookup_code in ('SUBMITTED', 'COMPLETED') and enabled_flag = 'Y';
    update xxfnd_lookup_values set meaning = 'In Progress', display_sequence = 20
     where lookup_type = 'KYC_REQUEST_STATUS' and lookup_code = 'IN_PROGRESS' and meaning = 'In progress';
    lt('PARTY_STATUS', 'Party Status');
    lvs('PARTY_STATUS', 'PENDING=Pending|APPROVED=Approved|REJECTED=Rejected|CANCELLED=Cancelled');
    lt('ID_DOCUMENT_TYPE', 'Identity Document Types', 'E');
    lvs('ID_DOCUMENT_TYPE', 'PASSPORT=Passport|NATIONAL_ID=National ID card|RESIDENCE_PERMIT=Residence permit');
    lt('REQUEST_MATCH_STATUS', 'Counterparty Match Status');
    lvs('REQUEST_MATCH_STATUS', 'SELECTED=Existing party chosen|NEW=New party|PENDING=Possible match - Compliance to decide'
        || '|MERGED=Merged into an existing party|CONFIRMED_NEW=Confirmed as a new party');
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
    -- Sections for the starter questions (only where an administrator has not set one).
    for q in (select column_value v from table(apex_t_varchar2(
                  'CORPORATE|10|Listing and Status', 'CORPORATE|20|Geographic Risk', 'CORPORATE|30|Business Activity',
                  'CORPORATE|40|Ownership and Control', 'CORPORATE|50|Business Activity',
                  'INDIVIDUAL|10|Relationship', 'INDIVIDUAL|20|Geographic Risk', 'INDIVIDUAL|30|Politically Exposed Persons'))) loop
        update xxcmp_questions
           set section_name = regexp_substr(q.v, '[^|]+', 1, 3)
         where questionnaire_code = regexp_substr(q.v, '[^|]+', 1, 1)
           and display_sequence   = to_number(regexp_substr(q.v, '[^|]+', 1, 2))
           and section_name is null;
    end loop;

    -- KYC Requests: list, wizard (4 steps), request view, request approval; Cases: workbench, case, decision, screening, UBO, document verification, new case, compliance report.
    for p in (select column_value page_id from table(apex_t_number(200, 201, 202, 203, 204, 205, 206))) loop
        page('KYC_REQUESTS', p.page_id);
    end loop;
    for p in (select column_value page_id from table(apex_t_number(210, 211, 212, 213, 214, 215, 216, 217))) loop
        page('CASES', p.page_id);
    end loop;
    -- Attachments on the request (wizard step 3 and the request page) and the party documents on the case.
    merge into xxfnd_attachment_functions t
    using (select 'KYC_REQUEST_SUBMIT' function_code, 'Create Request - Submit' function_name, 203 page_id from dual
           union all select 'KYC_REQUEST', 'KYC Request', 205 from dual
           union all select 'KYC_CASE', 'Case', 211 from dual
           union all select 'KYC_REQUEST_PARTY', 'Create Request - Party Details', 204 from dual
           union all select 'KYC_PARTY_DETAILS', 'Party - Details', 25 from dual) s
       on (t.function_code = s.function_code)
     when matched then update set t.apex_page_id = s.page_id
     when not matched then insert (function_code, application_code, function_name, apex_app_alias, apex_page_id)
                           values (s.function_code, 'KYC', s.function_name, 'KYC', s.page_id);
    merge into xxfnd_attachment_blocks t
    using (select 'KYC_REQUEST_SUBMIT' function_code, 'ATTACHMENTS' block_code, 'request_attachments' region, 'Documents' name from dual
           union all select 'KYC_REQUEST', 'ATTACHMENTS', 'request_attachments', 'Documents' from dual
           union all select 'KYC_CASE', 'PARTY_DOCUMENTS', 'party_documents', 'Party Documents' from dual
           union all select 'KYC_REQUEST_PARTY', 'ATTACHMENTS', 'party_attachments', 'Party Documents' from dual
           union all select 'KYC_PARTY_DETAILS', 'ATTACHMENTS', 'party_attachments', 'Party Documents' from dual) s
       on (t.function_code = s.function_code and t.block_code = s.block_code)
     when not matched then insert (function_code, block_code, region_static_id, block_name, display_sequence)
                           values (s.function_code, s.block_code, s.region, s.name, 10);
    merge into xxfnd_attachment_blk_entities t
    using (select 'KYC_REQUEST_SUBMIT' function_code, 'ATTACHMENTS' block_code, 'XXCMP_REQUESTS' entity_name, 'P203_REQUEST_ID' item, 'Y' del from dual
           union all select 'KYC_REQUEST', 'ATTACHMENTS', 'XXCMP_REQUESTS', 'P205_REQUEST_ID', 'N' from dual
           union all select 'KYC_CASE', 'PARTY_DOCUMENTS', 'XXCMP_PARTIES', 'P211_PARTY_ID', 'N' from dual
           union all select 'KYC_REQUEST_PARTY', 'ATTACHMENTS', 'XXCMP_PARTIES', 'P0_SUMMARY_PARTY_ID', 'Y' from dual
           union all select 'KYC_PARTY_DETAILS', 'ATTACHMENTS', 'XXCMP_PARTIES', 'P0_SUMMARY_PARTY_ID', 'Y' from dual) s
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
    -- release 48 (from 18b): compliance staff and administrators see every party and request for information;
    -- a requester only the requests for information addressed to them
    for r in (select column_value role_code from table(apex_string.split(c_staff || ',SYSTEM_ADMIN', ','))) loop
        rule(r.role_code, 'XXCMP_PARTIES', 'ALL_ROWS');
        rule(r.role_code, 'XXCMP_RFIS',    'ALL_ROWS');
    end loop;
    rule('REQUESTER', 'XXCMP_RFIS', 'OWN_RECORDS', 'RECIPIENT_USER_NAME');

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

    task_setting('COUNTERPARTY_MATCH', 2, 1, 'COMPLIANCE_MANAGER', 'Compliance decides whether a new counterparty is an existing party.');
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

-- release 29: open cases without an assignee go to the approver of their request's first approval step
declare
    l_sgid number;
begin
    select max(workspace_id) into l_sgid from apex_applications where application_id = 134;
    if l_sgid is not null then
        apex_util.set_security_group_id(l_sgid);
    end if;
    xxfnd_vpd_pkg.begin_trusted;
    update xxcmp_cases c
       set c.assigned_to = xxcmp_case_pkg.first_approver(c.request_id)
     where c.assigned_to is null and c.closed_date is null and c.request_id is not null;
    xxfnd_vpd_pkg.end_trusted;
    commit;
exception
    when others then
        xxfnd_vpd_pkg.end_trusted;
        raise;
end;
/

--------------------------------------------------------------------------------
-- release 48: the KYC configuration tables in the shared registry (configuration audit, maker-checker) and the
-- view of their pending changes (answer options are approved per question, rules row by row)
--------------------------------------------------------------------------------
create or replace view xxcmp_config_changes_v as
select 'XXCMP_QUESTIONS:' || q.question_id                                   detail_pk,
       'Risk scoring answers'                                                 change_type,
       q.questionnaire_code || ' / ' || substr(q.question_text, 1, 200)       change_title,
       listagg(nvl(ao.answer_label, ao.lookup_code) || ': ' || ao.risk_points || ' points'
                 || case when ao.critical_flag = 'Y' then ', critical' end
                 || case when ao.waiver_qualifying_flag = 'Y' then ', waiver' end, '; ')
         within group (order by ao.display_sequence)                          change_summary,
       max(ao.last_updated_by)                                                submitted_by,
       max(ao.last_update_date)                                               submitted_date
  from xxcmp_answer_options ao
  join xxcmp_questions q on q.question_id = ao.question_id
 where ao.approval_status = 'PENDING_APPROVAL'
 group by q.question_id, q.questionnaire_code, q.question_text
union all
select 'XXCMP_ATTACHMENT_RULES:' || r.attachment_rule_id,
       'Mandatory document rule',
       r.entity_name || ' / ' || r.category_code,
       nvl(r.jurisdiction, 'any jurisdiction') || ' / ' || nvl(r.entity_type, 'any entity type')
         || ' / ' || case r.mandatory_flag when 'Y' then 'mandatory' else 'optional' end,
       r.last_updated_by,
       r.last_update_date
  from xxcmp_attachment_rules r
 where r.approval_status = 'PENDING_APPROVAL';
comment on table xxcmp_config_changes_v is 'KYC configuration changes waiting for approval (registered changes view in XXFND_CONFIG_TABLES).';

merge into xxfnd_config_tables t
using (select 'XXCMP_QUESTIONNAIRES' table_name, 'N' approval_flag, null pk_column, null unit_table, null unit_key_column, null changes_view from dual
       union all select 'XXCMP_QUESTIONS', 'N', null, null, null, null from dual
       union all select 'XXCMP_ANSWER_OPTIONS', 'Y', 'ANSWER_OPTION_ID', 'XXCMP_QUESTIONS', 'QUESTION_ID', 'XXCMP_CONFIG_CHANGES_V' from dual
       union all select 'XXCMP_CONCLUSION_TEMPLATES', 'N', null, null, null, null from dual
       union all select 'XXCMP_APPROVAL_MATRIX', 'N', null, null, null, null from dual
       union all select 'XXCMP_ATTACHMENT_RULES', 'Y', 'ATTACHMENT_RULE_ID', null, null, 'XXCMP_CONFIG_CHANGES_V' from dual) s
   on (t.table_name = s.table_name)
 when matched then update set t.approval_flag = s.approval_flag, t.pk_column = s.pk_column, t.unit_table = s.unit_table,
                              t.unit_key_column = s.unit_key_column, t.changes_view = s.changes_view
 when not matched then insert (table_name, application_id, audit_flag, approval_flag, pk_column, unit_table, unit_key_column,
                               changes_view, created_by, creation_date, last_updated_by, last_update_date)
                       values (s.table_name, (select application_id from xxfnd_applications where application_code = 'KYC'), 'Y',
                               s.approval_flag, s.pk_column, s.unit_table, s.unit_key_column, s.changes_view,
                               'INSTALL', systimestamp, 'INSTALL', systimestamp);
commit;
-- the configuration audit triggers of the KYC tables registered above
begin
    xxfnd_audit_pkg.create_config_audit_triggers;
end;
/
