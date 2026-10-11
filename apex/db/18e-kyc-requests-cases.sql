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
    lvs('KYC_REQUEST_STATUS', 'DRAFT=Draft|IN_PROGRESS=In Progress|INFO_NEEDED=Pending Information|APPROVED=Approved'
        || '|REJECTED=Rejected|CANCELLED=Cancelled');
    -- release 74: an approver's request for information leaves the request Pending Information
    update xxfnd_lookup_values set meaning = 'Pending Information'
     where lookup_type = 'KYC_REQUEST_STATUS' and lookup_code = 'INFO_NEEDED' and meaning = 'Information Needed';
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
    lvs('CASE_STATUS', 'INVESTIGATION=Under investigation|PENDING_APPROVAL=Pending approval|PENDING_INFORMATION=Pending information|APPROVED=Approved|REJECTED=Rejected|CANCELLED=Cancelled');
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
    -- release 74 (R14): party verifications (16n), recorded by hand; the registry check is filled by a provider later
    entity('XXCMP_PARTY_ID_VERIFICATIONS', 'ID Verification', 'ID_VERIFICATION_ID');
    entity('XXCMP_PARTY_REGISTRY_CHECKS', 'Registry Check', 'REGISTRY_CHECK_ID');
    -- release 74 (R27): attachments of the e-mails sent or recorded on the RFI and Notes screens
    entity('XXFND_COMMUNICATIONS', 'E-mail', 'COMMUNICATION_ID');
    lt('ID_VERIFICATION_METHOD', 'ID Verification Methods');
    lvs('ID_VERIFICATION_METHOD', 'ORIGINAL_SEEN=Original seen in person|CERTIFIED_COPY=Certified copy|VIDEO_CALL=Video call'
        || '|GOVERNMENT_PORTAL=Government portal checked by hand');
    lt('ID_VERIFICATION_RESULT', 'ID Verification Results');
    lvs('ID_VERIFICATION_RESULT', 'VERIFIED=Verified|NOT_VERIFIED=Not verified|INCONCLUSIVE=Inconclusive');
    lt('REGISTRY_CHECK_RESULT', 'Registry Check Results');
    lvs('REGISTRY_CHECK_RESULT', 'MATCH=Matches the party record|MISMATCH=Differs from the party record|NOT_FOUND=Not found in the registry');
    lt('REGISTRATION_STATUS', 'Registry Statuses');
    lvs('REGISTRATION_STATUS', 'ACTIVE=Active|SUSPENDED=Suspended|IN_LIQUIDATION=In liquidation|DISSOLVED=Dissolved|UNKNOWN=Unknown');
    lt('RISK_COUNTRY_LIST', 'Risk Country Lists');
    lvs('RISK_COUNTRY_LIST', 'FATF_BLACK=FATF black list (call for action)|FATF_GREY=FATF grey list (increased monitoring)'
        || '|INTERNAL=Company high-risk list');
    lt('RISK_FACTOR_TYPE', 'Risk Factor Types');
    lvs('RISK_FACTOR_TYPE', 'FLAG=Points when it applies|SCORE=Percentage of the questionnaire score');
    lt('DATA_SOURCE', 'Data Sources');
    lvs('DATA_SOURCE', 'MANUAL=Entered by hand|API=From the provider');
    -- release 74 (R14, R19): FIU / goAML reports and guided source of funds / wealth (16s)
    lt('FIU_REPORT_TYPE', 'FIU Report Types');
    lvs('FIU_REPORT_TYPE', 'STR=Suspicious transaction report|SAR=Suspicious activity report');
    lt('FIU_REPORT_STATUS', 'FIU Report Statuses');
    lvs('FIU_REPORT_STATUS', 'DRAFT=Draft|APPROVED=Approved|FILED=Filed with the FIU|CANCELLED=Cancelled');
    lt('FUNDS_TYPE', 'Source of Funds / Wealth');
    lvs('FUNDS_TYPE', 'SOF=Source of funds (this relationship)|SOW=Source of wealth (overall)');
    lt('FUNDS_EVIDENCE_TYPE', 'Source of Funds Evidence');
    lvs('FUNDS_EVIDENCE_TYPE', 'BANK_STATEMENT=Bank statement|PAYSLIP=Payslip|EMPLOYMENT_LETTER=Employment letter'
        || '|AUDITED_ACCOUNTS=Audited accounts|TAX_RETURN=Tax return|SALE_AGREEMENT=Sale agreement|WILL_PROBATE=Will / probate'
        || '|INVESTMENT_STATEMENT=Investment statement|LOAN_AGREEMENT=Loan agreement|SHAREHOLDER_FUNDING=Shareholder funding evidence'
        || '|OTHER=Other');
    -- the tag lists the evidence expected for each source (the form guides the officer with it)
    lt('FUNDS_CATEGORY', 'Source of Funds Categories');
    lvs('FUNDS_CATEGORY', 'SALARY=Salary / employment income=PAYSLIP,BANK_STATEMENT,EMPLOYMENT_LETTER'
        || '|BUSINESS_INCOME=Business income / trading=AUDITED_ACCOUNTS,BANK_STATEMENT,TAX_RETURN'
        || '|CAPITAL=Shareholder capital=SHAREHOLDER_FUNDING,BANK_STATEMENT'
        || '|SALE_OF_ASSETS=Sale of assets=SALE_AGREEMENT,BANK_STATEMENT'
        || '|INVESTMENTS=Investments=INVESTMENT_STATEMENT,BANK_STATEMENT'
        || '|INHERITANCE=Inheritance / gift=WILL_PROBATE,BANK_STATEMENT'
        || '|LOAN=Loan / financing=LOAN_AGREEMENT,BANK_STATEMENT'
        || '|OTHER=Other');
    merge into xxfnd_integration_purposes t
    using (select 'BANK_DATA' code, 'Bank data for source of funds' name from dual
           union all select 'GOAML_FILING', 'FIU goAML filing' from dual) s
       on (t.purpose_code = s.code)
     when not matched then insert (purpose_code, application_code, purpose_name, capture_method, approval_status)
                           values (s.code, 'KYC', s.name, 'MANUAL', 'APPROVED');

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
    for p in (select column_value page_id from table(apex_t_number(210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 34))) loop
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
    -- release 74: the common RFI table, same access
    for r in (select column_value role_code from table(apex_string.split(c_staff || ',SYSTEM_ADMIN', ','))) loop
        rule(r.role_code, 'XXFND_RFIS', 'ALL_ROWS');
    end loop;
    rule('REQUESTER', 'XXFND_RFIS', 'OWN_RECORDS', 'RECIPIENT_USER_NAME');
    -- release 74 (R14): party verifications - the Compliance team (requesters do not see them)
    for r in (select column_value role_code from table(apex_string.split(c_staff || ',SYSTEM_ADMIN', ','))) loop
        rule(r.role_code, 'XXCMP_PARTY_ID_VERIFICATIONS', 'ALL_ROWS');
        rule(r.role_code, 'XXCMP_PARTY_REGISTRY_CHECKS', 'ALL_ROWS');
        rule(r.role_code, 'XXCMP_FIU_REPORTS', 'ALL_ROWS');
        rule(r.role_code, 'XXCMP_CASE_FUNDS', 'ALL_ROWS');
        -- release 74 (R27): e-mails with outside parties (COMMON XXFND_COMMUNICATIONS)
        rule(r.role_code, 'XXFND_COMMUNICATIONS', 'ALL_ROWS');
        -- release 74 (R16): the risk model and the case scores
        rule(r.role_code, 'XXCMP_RISK_FACTORS', 'ALL_ROWS');
        rule(r.role_code, 'XXCMP_RISK_COUNTRIES', 'ALL_ROWS');
        rule(r.role_code, 'XXCMP_RISK_TIERS', 'ALL_ROWS');
        rule(r.role_code, 'XXCMP_CASE_RISK_SCORES', 'ALL_ROWS');
    end loop;

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
    xxfnd_schema_pkg.apply_policies;
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
 where r.approval_status = 'PENDING_APPROVAL'
union all
-- release 74 (R16): risk model changes, one approval per table
select 'XXCMP_RISK_FACTOR_SET:KYC', 'Risk model factors', 'Risk factors',
       listagg(f.factor_name || ': ' || f.points || case when f.enabled_flag = 'N' then ' (off)' end
               || nvl2(f.force_tier, ', forces ' || f.force_tier, null), '; ') within group (order by f.display_sequence),
       max(f.last_updated_by), max(f.last_update_date)
  from xxcmp_risk_factors f
 where f.approval_status = 'PENDING_APPROVAL'
having count(*) > 0
union all
select 'XXCMP_RISK_COUNTRY_SET:KYC', 'Risk model country lists', 'Country lists',
       listagg(c.list_code || ' ' || c.country_code || case when c.enabled_flag = 'N' then ' (removed)' end, '; ')
         within group (order by c.list_code, c.country_code),
       max(c.last_updated_by), max(c.last_update_date)
  from xxcmp_risk_countries c
 where c.approval_status = 'PENDING_APPROVAL'
having count(*) > 0
union all
select 'XXCMP_RISK_TIER_SET:KYC', 'Risk model tiers', 'Risk tiers',
       listagg(t.risk_tier || ' from ' || t.min_score || ', review ' || t.review_months || ' months', '; ')
         within group (order by t.min_score),
       max(t.last_updated_by), max(t.last_update_date)
  from xxcmp_risk_tiers t
 where t.approval_status = 'PENDING_APPROVAL'
having count(*) > 0;
comment on table xxcmp_config_changes_v is 'KYC configuration changes waiting for approval (registered changes view in XXFND_CONFIG_TABLES).';

merge into xxfnd_config_tables t
using (select 'XXCMP_QUESTIONNAIRES' table_name, 'N' approval_flag, null pk_column, null unit_table, null unit_key_column, null changes_view from dual
       union all select 'XXCMP_QUESTIONS', 'N', null, null, null, null from dual
       union all select 'XXCMP_ANSWER_OPTIONS', 'Y', 'ANSWER_OPTION_ID', 'XXCMP_QUESTIONS', 'QUESTION_ID', 'XXCMP_CONFIG_CHANGES_V' from dual
       union all select 'XXCMP_CONCLUSION_TEMPLATES', 'N', null, null, null, null from dual
       union all select 'XXCMP_APPROVAL_MATRIX', 'N', null, null, null, null from dual
       union all select 'XXCMP_ATTACHMENT_RULES', 'Y', 'ATTACHMENT_RULE_ID', null, null, 'XXCMP_CONFIG_CHANGES_V' from dual
       -- release 74 (R16): the risk model; each table is one approval unit (all its changed rows together)
       union all select 'XXCMP_RISK_FACTORS', 'Y', 'FACTOR_CODE', 'XXCMP_RISK_FACTOR_SET', 'MODEL_CODE', 'XXCMP_CONFIG_CHANGES_V' from dual
       union all select 'XXCMP_RISK_COUNTRIES', 'Y', 'RISK_COUNTRY_ID', 'XXCMP_RISK_COUNTRY_SET', 'MODEL_CODE', 'XXCMP_CONFIG_CHANGES_V' from dual
       union all select 'XXCMP_RISK_TIERS', 'Y', 'RISK_TIER', 'XXCMP_RISK_TIER_SET', 'MODEL_CODE', 'XXCMP_CONFIG_CHANGES_V' from dual) s
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
    xxfnd_schema_pkg.create_config_audit_triggers;
end;
/

-- release 74: the messages the party, request and case components raise (message catalogue, COMMON 09f); a text
-- Compliance changed is kept
begin
    xxfnd_error_pkg.register_message('KYC_PARTY_CREATE_NOT_ALLOWED', 'You are not allowed to create parties.', -20701);
    xxfnd_error_pkg.register_message('KYC_PARTY_CHANGE_NOT_ALLOWED', 'You are not allowed to change parties.', -20706);
    xxfnd_error_pkg.register_message('KYC_PARTY_DISABLED', 'A disabled or merged party cannot be changed.', -20707);
    xxfnd_error_pkg.register_message('KYC_PARTY_THIS_NOT_ALLOWED', 'You are not allowed to change this party.', -20706);
    xxfnd_error_pkg.register_message('KYC_PARTY_MERGE_NOT_ALLOWED', 'Only Compliance can merge parties.', -20711);
    xxfnd_error_pkg.register_message('KYC_PARTY_MERGE_TARGET', 'Choose another party to merge into.', -20712);
    xxfnd_error_pkg.register_message('KYC_PARTY_MERGE_TYPE', 'An organisation cannot be merged into an individual, or the reverse.', -20713);
    xxfnd_error_pkg.register_message('KYC_PARTY_MERGE_DISABLED', 'Both parties must be enabled.', -20714);
    xxfnd_error_pkg.register_message('KYC_REQUEST_LOCKED', 'Request {1} can no longer be changed.', -20612);
    xxfnd_error_pkg.register_message('KYC_REQUEST_PARTY_FIXED', 'The counterparty of a submitted request cannot be replaced.', -20617);
    xxfnd_error_pkg.register_message('KYC_REQUEST_PARTY_APPROVED', 'The party of this request has been approved: Compliance maintains it.', -20618);
    xxfnd_error_pkg.register_message('KYC_REQUEST_ANSWERS_LOCKED', 'The request has been submitted; its answers can no longer be changed.', -20613);
    xxfnd_error_pkg.register_message('KYC_REQUEST_QUESTION_UNKNOWN', 'Question {1} does not belong to this request.', -20614);
    xxfnd_error_pkg.register_message('KYC_REQUEST_OPTION_UNKNOWN', 'Answer {1} is not an option of question {2}.', -20615);
    xxfnd_error_pkg.register_message('KYC_REQUEST_NUMBER_EXPECTED', 'Enter a number for: {1}', -20616);
    xxfnd_error_pkg.register_message('KYC_REQUEST_INFO_TEXT', 'Enter the information you need from the requester.', -20625);
    xxfnd_error_pkg.register_message('KYC_REQUEST_NOT_IN_APPROVAL', 'Request {1} is not waiting for approval.', -20625);
    xxfnd_error_pkg.register_message('KYC_REQUEST_NOT_APPROVER', 'You are not an approver of request {1}.', -20625);
    -- release 76: requesting departments from data security
    xxfnd_error_pkg.register_message('KYC_REQUEST_NO_DEPARTMENT', 'No requesting department is set up for you. Ask the administrator to give you a Requesting Entity role.', -20626);
    xxfnd_error_pkg.register_message('KYC_REQUEST_DEPT_NOT_ALLOWED', 'You cannot raise requests for {1}. Choose one of your departments.', -20626);
    xxfnd_error_pkg.register_message('KYC_CASE_REASSIGN_NOT_ALLOWED', 'Only a case under investigation can be reassigned, by Compliance management or its assignee.', -20611);
    xxfnd_error_pkg.register_message('KYC_CASE_OFFICER_REQUIRED', 'Select the officer.', -20611);
    -- release 75: the officer chosen for a case must be an active Compliance officer, manager or head of Compliance
    xxfnd_error_pkg.register_message('KYC_CASE_OFFICER_INVALID', 'Choose an active Compliance officer, manager or head of Compliance.', -20619);
    xxfnd_error_pkg.register_message('KYC_CASE_WITHDRAW_NOT_ALLOWED', 'Only a case waiting for approval can be withdrawn, by its officer or Compliance management.', -20615);
    xxfnd_error_pkg.register_message('KYC_CASE_WITHDRAW_REASON', 'Enter the reason for withdrawing the case from approval.', -20615);
    xxfnd_error_pkg.register_message('KYC_CASE_NO_MATRIX_ROW', 'The approval matrix has no row for risk tier {1}.', -20612);
    xxfnd_error_pkg.register_message('KYC_CASE_CONTACT_NO_EMAIL', 'The contact person has no e-mail address: add one before sending the request.', -20509);
    xxfnd_error_pkg.register_message('KYC_CASE_FIU_FILING', 'Enter the goAML reference and the date the report was filed.', -20616);
    xxfnd_error_pkg.register_message('KYC_CASE_FUNDS_EVIDENCE', 'Record the evidence seen before marking the source as verified.', -20617);
    commit;
end;
/
