
create or replace package xxcmp_case_pkg authid definer as

    -- Release 91: a numeric KYC parameter (CASE_SLA_DAYS, PEP_REVIEW_MONTHS, REVIEW_LEAD_DAYS). It is a KYC application
    -- setting; while the setting is empty, the value an administrator kept in the old lookup KYC_PARAMETER (TAG)
    -- applies, then P_DEFAULT. Read from the APEX dictionary, so it also works without an APEX session (views).
    function parameter(p_name in varchar2, p_default in number) return number;

    -- Opens the case of a request and starts the KYC_CASE workflow.
    function create_case(p_request_id in number, p_assigned_to in varchar2 default null) return number;
    -- A case opened by an officer without an intake request (a request is recorded for the trail).
    function create_manual_case(p_party_id in number, p_justification in varchar2) return number;

    procedure assign(p_case_id in number, p_user_name in varchar2, p_comment in varchar2 default null);
    -- Assign on the case and request screens: the Case Assignment privilege (release 76; before: Manage on Cases or the
    -- assignee) and a business administrator of the open investigation task (APEX lets only them move it).
    function can_assign(p_case_id in number) return varchar2;
    -- Release 75: Y when the user may be given a case (an active Compliance officer, manager or head of Compliance):
    -- the list of officers on the Assign screens and the check of a chosen officer.
    function is_case_officer(p_user_name in varchar2) return varchar2;
    -- The approver of the first step of the request's approval path (default assignee of its case).
    function first_approver(p_request_id in number) return varchar2;
    -- Withdraw from approval: back to investigation (the submitter or Manage on Cases, while Pending approval).
    function can_withdraw(p_case_id in number) return varchar2;
    procedure withdraw(p_case_id in number, p_reason in varchar2);

    -- Task participants.
    function investigation_owners(p_case_id in number) return varchar2;
    -- Release 75: business administrators of the investigation task - the workflow administrators and (release 76) the
    -- holders of Case Assignment, who may give the case (and its task) to another officer.
    function investigation_admins(p_case_id in number) return varchar2;
    function level_approvers(p_case_id in number) return varchar2;

    -- Approval levels from the approval matrix (risk tier; Enhanced KYC needs two).
    function required_levels(p_case_id in number) return number;
    function level_role(p_case_id in number, p_level in number) return varchar2;
    function sar_gate(p_case_id in number) return varchar2;

    -- Y when the case is under investigation and the user may manage cases (Case page read-only otherwise).
    function is_editable(p_case_id in number) return varchar2;

    -- Investigation -> approval.
    function submit_error(p_case_id in number) return varchar2;
    procedure submit_for_approval(p_case_id in number);

    -- Approval (CASE_APPROVAL task actions and the decision page).
    function approval_error(p_case_id in number) return varchar2;
    procedure record_decision(p_case_id in number, p_outcome in varchar2, p_comments in varchar2, p_task_id in number);
    -- The case approval history table (release 74: from XXCMP_APPROVAL_PKG): investigation, then each approval level
    -- (who, when, outcome, comments); the current level Pending and the levels to come Waiting (Expected while
    -- investigating), from the Approval Setup (KYC_CASE).
    function case_history_rows(p_case_id in number) return xxcmp_history_tab pipelined;
    -- CASE_APPROVAL task events: the approver asked the requester for information (Pending Information) / the
    -- requester submitted it (Pending Approval again).
    procedure info_requested(p_case_id in number);
    procedure info_submitted(p_case_id in number);
    -- The requester answers a case approver's question on their request screen (they cannot open cases): the case
    -- approval task of the request waiting for the current user's information, and the request of a case.
    function info_task(p_request_id in number) return number;
    function request_of(p_case_id in number) return number;
    function next_review_date(p_case_id in number) return date;

    -- Workflow steps (KYC_CASE).
    procedure start_approval(p_case_id in number);
    -- Release 76 (A-11): Y when the case goes to its approvers - the approval workflow is on and the matching Approval
    -- Setup rule has steps (a rule without steps approves the case at once). The KYC_CASE workflow (version 1.3) asks it.
    function approval_required(p_case_id in number) return varchar2;
    function has_next_level(p_case_id in number) return varchar2;
    -- Release 90: the decision that closes the case (APPROVE_CASE / REJECT_CASE were one routine twice).
    -- P_DECISION = APPROVED or REJECTED; the party's next KYC date follows (KYC_CASE workflow, trusted).
    procedure close_case(p_case_id in number, p_decision in varchar2);

    -- Screening results: a confirmed match or PEP flag forces Enhanced KYC.
    -- release 74: an RFI raised from a case (or its request / party) - its own workflow process (common RFI).
    -- p_recipient_type SETUP (default): the providers come from the Approval Setup (CASE_RFI, default the requester);
    -- REQUESTING_DEPARTMENT: a named user; EXTERNAL_PARTY: a contact person of the party (name and e-mail).
    -- release 89: COMMON's RFI process runs it (XXFND_RFI_PKG): a user answers and the raiser reviews on COMMON's task
    -- page Information Request (143); an outside person answers on COMMON's public page Provide Information (50).
    procedure raise_rfi(p_entity_name      in varchar2,
                        p_pk1_value        in varchar2,
                        p_recipient_type   in varchar2,
                        p_recipient_user   in varchar2,
                        p_party_contact_id in number,
                        p_rfi_category     in varchar2,
                        p_description      in varchar2,
                        p_continue_work    in varchar2,
                        p_due_date         in date);
    -- release 89: the open step of an RFI the signed-in user takes in COMMON's RFI process (the RFI_RESPONSE or RFI_REVIEW
    -- task of COMMON in the user's My Tasks), for the link to COMMON's task page 143; null when there is none.
    function rfi_task(p_rfi_id in number) return number;
    procedure apply_screening(p_case_id in number);

    -- Case screen (211, release 27): the sections an officer works through, in order.
    -- release 29: Contacts and Ownership merged into Party
    -- release 42: Ownership Tree (the whole ownership tree with each party's screening) after Party
    c_sections constant varchar2(200) := 'SUMMARY:PARTY:TREE:SCREENING:DOCUMENTS:RISK:NOTES:REVIEW';
    -- DONE, TODO or WARN (an open request for information) for one section.
    function section_state(p_case_id in number, p_section in varchar2) return varchar2;
    -- release 74 (R5, R11): data for the case screen's section menu (dynamic list CASE-SECTIONS on page 211), no HTML.
    -- The sections in order (c_sections, for SQL) and the progress "done / total".
    function sections return varchar2;
    function section_progress(p_case_id in number) return varchar2;
    -- The case summary (Summary, Review, and Risk when read only) for the standard Value Attribute Pairs report (R7, R11:
    -- moved from the request UI package, data only): JSON array [{"group_name","seq","label","value","tone","url",
    -- "link_text","user_name"}]; a missing required value has tone "missing" and links (url, link_text) to its section.
    function case_summary_json(p_case_id in number, p_task_id in number default null) return clob;

    -- release 74 (R14): screening by hand now, by a provider later. A person saved a provider row: it is marked as
    -- changed by a person (the original response stays unchanged); a person confirms a provider row (reviewed by).
    procedure screening_saved(p_screening_id in number);
    procedure review_screening(p_screening_id in number);
    -- release 74 (R14): FIU / goAML reports of the case. Prepared by the officer; approved by another Compliance
    -- manager (not the preparer); filed with the goAML reference and date. P_ACTION: APPROVE, FILE, CANCEL.
    function fiu_report_error(p_case_id in number, p_report_type in varchar2, p_grounds in varchar2) return varchar2;
    -- Y when the user may create (no report yet) or change (Draft) a report: Cases Create, any case status (the
    -- suspicion is often decided at approval).
    function fiu_editable(p_fiu_report_id in number, p_case_id in number) return varchar2;
    function fiu_action_allowed(p_fiu_report_id in number, p_action in varchar2) return varchar2;
    procedure fiu_action(p_fiu_report_id in number, p_action in varchar2, p_reference in varchar2 default null,
                         p_filed_date in date default null);
    -- release 74 (R19): guided source of funds / wealth. The evidence expected for a category (lookup FUNDS_CATEGORY
    -- tag, codes of FUNDS_EVIDENCE_TYPE), its meanings for the screen, the check of a line and its verification.
    function expected_evidence_text(p_category in varchar2) return varchar2;
    function funds_error(p_case_id in number, p_funds_type in varchar2, p_category in varchar2, p_evidence_type in varchar2,
                         p_amount in number, p_period_from in date, p_period_to in date) return varchar2;
    procedure verify_funds(p_case_funds_id in number);

end xxcmp_case_pkg;
/

create or replace package body xxcmp_case_pkg as

    function parameter(p_name in varchar2, p_default in number) return number is
        l_value number;
    begin
        select max(to_number(value default null on conversion error)) into l_value
          from apex_application_settings
         where application_id = xxfnd_application_pkg.apex_app_id('KYC') and name = upper(p_name);
        if l_value is null then
            -- an existing database: the value kept in the old lookup (no longer registered on a new database)
            select max(to_number(tag default null on conversion error)) into l_value from xxfnd_lookup_values
             where lookup_type = 'KYC_PARAMETER' and lookup_code = upper(p_name) and enabled_flag = 'Y';
        end if;
        return nvl(l_value, p_default);
    end parameter;

    function get_case(p_case_id in number) return xxcmp_cases%rowtype is
        l_case xxcmp_cases%rowtype;
    begin
        select * into l_case from xxcmp_cases where case_id = p_case_id;
        return l_case;
    end get_case;

    function create_case(p_request_id in number, p_assigned_to in varchar2 default null) return number is
        l_req  xxcmp_requests%rowtype;
        l_id   number;
        l_wf   number;
        l_sla  number := parameter('CASE_SLA_DAYS', 10);
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select * into l_req from xxcmp_requests where request_id = p_request_id;
        insert into xxcmp_cases (case_number, request_id, party_id, parent_case_id, assigned_to, sla_due_date,
                                 business_relationship, requesting_department_id)
        values ('CASE-' || lpad(xxcmp_case_number_s.nextval, 6, '0'), p_request_id, l_req.party_id, l_req.parent_case_id,
                -- release 29: by default the case goes to the approver of the request's first approval step
                upper(coalesce(p_assigned_to, first_approver(p_request_id))), trunc(sysdate) + l_sla,
                coalesce(l_req.business_relationship,
                         (select c.business_relationship from xxcmp_cases c where c.case_id = l_req.parent_case_id)),
                -- release 95: the request's department (Department data access on cases); release 96: its ID
                l_req.requesting_department_id)
        returning case_id into l_id;
        -- the officer's investigation questionnaire
        insert into xxcmp_request_answers (request_id, case_id, respondent_type, question_id)
        select p_request_id, l_id, 'OFFICER', q.question_id
          from xxcmp_questions q
          join xxcmp_questionnaires qn on qn.questionnaire_code = q.questionnaire_code
         where qn.audience = 'OFFICER' and qn.enabled_flag = 'Y' and q.enabled_flag = 'Y'
           and not exists (select 1 from xxcmp_request_answers a
                            where a.request_id = p_request_id and a.respondent_type = 'OFFICER' and a.question_id = q.question_id);
        -- release 74: the request and its party are approved by the request package (XXCMP_REQUEST_PKG.OPEN_CASE)
        -- the requester (or whoever opened a manual case) initiates; separation of duties excludes them
        l_wf := xxfnd_workflow_pkg.start_process('KYC_CASE', to_char(l_id), l_req.requester_user_name);
        update xxcmp_cases set workflow_id = l_wf where case_id = l_id;
        xxfnd_vpd_pkg.end_trusted;
        return l_id;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end create_case;

    function create_manual_case(p_party_id in number, p_justification in varchar2) return number is
        l_rel  xxcmp_cases.business_relationship%type;
        l_req  number;
        l_case number;
    begin
        -- the relationship of the party's latest case; the request package records the request behind the case
        select max(c.business_relationship) keep (dense_rank last order by c.case_id) into l_rel
          from xxcmp_cases c where c.party_id = p_party_id;
        l_req  := xxcmp_request_pkg.create_case_request(p_party_id, p_justification, l_rel);
        l_case := create_case(l_req, xxfnd_util_pkg.current_user);
        xxcmp_request_pkg.close_without_case(l_req);       -- the request and its party are Approved (request package)
        return l_case;
    end create_manual_case;

    function first_approver(p_request_id in number) return varchar2 is
        l_user varchar2(255);
    begin
        select max(h.event_creator) keep (dense_rank first order by h.event_timestamp)
          into l_user
          from apex_task_history h
          join apex_tasks t on t.task_id = h.task_id
         where t.detail_pk = to_char(p_request_id)
           and t.task_def_static_id = 'DOC_CHECKLIST_REVIEW'
           and h.event_type_code = 'COMPLETE';
        -- the first step is being completed right now (single-step path): its approver is the current user
        return upper(coalesce(l_user, nullif(xxfnd_util_pkg.current_user, 'nobody')));
    end first_approver;

    -- release 75: Y when the case has no open investigation task, or the current user administers it
    function task_admin(p_case_id in number) return varchar2 is
        l_n pls_integer;
    begin
        select count(*) into l_n from apex_tasks t
         where t.detail_pk = to_char(p_case_id) and t.task_def_static_id = 'CASE_INVESTIGATION'
           and t.state_code in ('UNASSIGNED', 'ASSIGNED')
           and not exists (select 1 from apex_task_participants p
                            where p.task_id = t.task_id and p.participant_type = 'BUSINESS_ADMIN'
                              and upper(p.participant) = upper(xxfnd_util_pkg.current_user));
        return case when l_n = 0 then 'Y' else 'N' end;
    end task_admin;

    function can_assign(p_case_id in number) return varchar2 is
        l_case xxcmp_cases%rowtype;
    begin
        select * into l_case from xxcmp_cases where case_id = p_case_id;
        -- release 76: the Case Assignment privilege (Level 1 approvers), no longer Cases - Manage or the assignee
        return case when l_case.case_status = 'INVESTIGATION'
                         and xxfnd_privilege_pkg.has_privilege('CASE_ASSIGNMENT', 'MANAGE')
                         and task_admin(p_case_id) = 'Y'
                    then 'Y' else 'N' end;
    exception
        when no_data_found then
            return 'N';
    end can_assign;

    function is_case_officer(p_user_name in varchar2) return varchar2 is
        l_n pls_integer;
    begin
        select count(*) into l_n from xxfnd_user_roles_v
         where upper(user_name) = upper(p_user_name) and active_flag = 'Y'
           and role_code in ('COMPLIANCE_OFFICER', 'COMPLIANCE_MANAGER', 'HEAD_OF_COMPLIANCE');
        return case when l_n > 0 then 'Y' else 'N' end;
    end is_case_officer;

    procedure assign(p_case_id in number, p_user_name in varchar2, p_comment in varchar2 default null) is
        l_case xxcmp_cases%rowtype;
        l_note varchar2(4000);
        function emp(p_user in varchar2) return varchar2 is
            l_name xxhr_employees.full_name%type;
        begin
            select max(full_name) into l_name from xxhr_employees where upper(user_name) = upper(p_user);
            return nvl(l_name, p_user);
        end emp;
        function owner(p_task_id in number, p_user in varchar2) return boolean is
            l_n pls_integer;
        begin
            select count(*) into l_n from apex_task_participants
             where task_id = p_task_id and participant_type = 'POTENTIAL_OWNER' and upper(participant) = upper(p_user);
            return l_n > 0;
        end owner;
    begin
        select * into l_case from xxcmp_cases where case_id = p_case_id;
        if can_assign(p_case_id) = 'N' then
            xxfnd_error_pkg.raise_error('KYC_CASE_REASSIGN_NOT_ALLOWED');
        end if;
        if p_user_name is null then
            xxfnd_error_pkg.raise_error('KYC_CASE_OFFICER_REQUIRED');
        elsif is_case_officer(p_user_name) = 'N' then
            xxfnd_error_pkg.raise_error('KYC_CASE_OFFICER_INVALID');   -- release 75
        end if;
        -- the open investigation task follows the case. Release 75: checked first, never by catching an error - a failed
        -- APEX task call rolls the whole transaction back (the case kept its officer while the note said otherwise)
        for t in (select task_id, upper(actual_owner) as actual_owner from apex_tasks
                   where detail_pk = to_char(p_case_id) and task_def_static_id = 'CASE_INVESTIGATION'
                     and state_code in ('UNASSIGNED', 'ASSIGNED')) loop
            if not owner(t.task_id, p_user_name) then
                apex_human_task.add_task_potential_owner(p_task_id => t.task_id, p_potential_owner => upper(p_user_name));
            end if;
            if t.actual_owner is not null and t.actual_owner <> upper(p_user_name) then
                apex_human_task.delegate_task(p_task_id => t.task_id, p_to_user => upper(p_user_name));   -- the owner cannot be removed
            end if;
            if l_case.assigned_to is not null and upper(l_case.assigned_to) <> upper(p_user_name)
               and owner(t.task_id, l_case.assigned_to) then
                apex_human_task.remove_potential_owner(p_task_id => t.task_id, p_potential_owner => upper(l_case.assigned_to));
            end if;
        end loop;
        update xxcmp_cases set assigned_to = upper(p_user_name) where case_id = p_case_id;
        l_note := substr('Assigned to ' || emp(p_user_name)
                         || case when l_case.assigned_to is not null then ' (was ' || emp(l_case.assigned_to) || ')' end
                         || case when p_comment is not null then ': ' || p_comment end, 1, 4000);
        insert into xxcmp_case_notes (case_id, note_text) values (p_case_id, l_note);
    end assign;

    function can_withdraw(p_case_id in number) return varchar2 is
        l_case xxcmp_cases%rowtype;
    begin
        select * into l_case from xxcmp_cases where case_id = p_case_id;
        return case when l_case.case_status in ('PENDING_APPROVAL', 'PENDING_INFORMATION')
                         and (xxfnd_privilege_pkg.has_privilege('CASES', 'MANAGE')
                              or upper(l_case.assigned_to) = upper(xxfnd_util_pkg.current_user))
                    then 'Y' else 'N' end;
    exception
        when no_data_found then
            return 'N';
    end can_withdraw;

    procedure withdraw(p_case_id in number, p_reason in varchar2) is
        l_case  xxcmp_cases%rowtype;
        l_wf    number;
        l_init  varchar2(255);
    begin
        if can_withdraw(p_case_id) = 'N' then
            xxfnd_error_pkg.raise_error('KYC_CASE_WITHDRAW_NOT_ALLOWED');
        end if;
        if trim(p_reason) is null then
            xxfnd_error_pkg.raise_error('KYC_CASE_WITHDRAW_REASON');
        end if;
        xxfnd_vpd_pkg.begin_trusted;
        l_case := get_case(p_case_id);
        insert into xxcmp_case_decisions (case_id, level_no, role_code, decided_by, outcome, comments)
        values (p_case_id, nvl(l_case.current_level, 1), null, xxfnd_util_pkg.current_user, 'WITHDRAWN', substr(p_reason, 1, 4000));
        xxfnd_workflow_pkg.end_process(l_case.workflow_id);
        xxfnd_approval_rule_pkg.cancel('KYC_CASE', to_char(p_case_id));
        update xxcmp_cases
           set case_status = 'INVESTIGATION', current_level = null, investigation_completed_date = null
         where case_id = p_case_id;
        -- a fresh KYC_CASE workflow: the investigation task goes back to the assignee
        select max(requester_user_name) into l_init from xxcmp_requests where request_id = l_case.request_id;
        l_wf := xxfnd_workflow_pkg.start_process('KYC_CASE', to_char(p_case_id), l_init);
        update xxcmp_cases set workflow_id = l_wf where case_id = p_case_id;
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end withdraw;

    function investigation_owners(p_case_id in number) return varchar2 is
        l_case xxcmp_cases%rowtype;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        l_case := get_case(p_case_id);
        xxfnd_vpd_pkg.end_trusted;
        return nvl(l_case.assigned_to, xxfnd_workflow_pkg.users_with_privilege('CASES', 'MANAGE'));
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end investigation_owners;

    function investigation_admins(p_case_id in number) return varchar2 is
        l_list varchar2(32767);
    begin
        select listagg(distinct column_value, ',') within group (order by column_value) into l_list
          from apex_string.split(xxfnd_workflow_pkg.business_admins
                                 || ',' || xxfnd_workflow_pkg.users_with_privilege('CASE_ASSIGNMENT', 'MANAGE'), ',')
         where column_value is not null;
        return l_list;
    end investigation_admins;

    function matrix(p_case in xxcmp_cases%rowtype) return xxcmp_approval_matrix%rowtype is
        l_row xxcmp_approval_matrix%rowtype;
    begin
        select * into l_row from xxcmp_approval_matrix where risk_tier = p_case.risk_tier;
        return l_row;
    exception
        when no_data_found then
            xxfnd_error_pkg.raise_error('KYC_CASE_NO_MATRIX_ROW', apex_t_varchar2(p_case.risk_tier));
    end matrix;

    -- release 74: the approval levels come from the common Approval Setup (transaction type KYC_CASE).
    -- Release 90: private (used only here); the party type is read by the party package.
    function case_attributes(p_case in xxcmp_cases%rowtype) return apex_t_varchar2 is
    begin
        return apex_t_varchar2('RISK_TIER=' || p_case.risk_tier, 'ENHANCED_KYC=' || nvl(p_case.enhanced_kyc_flag, 'N'),
                               'PARTY_TYPE=' || xxcmp_party_pkg.party_type(p_case.party_id),
                               'BUSINESS_RELATIONSHIP=' || p_case.business_relationship);
    end case_attributes;

    function level_step(p_case_id in number, p_level in number) return xxfnd_approval_step_row is
        l_attrs apex_t_varchar2 := case_attributes(get_case(p_case_id));
        l_step  xxfnd_approval_step_row;
    begin
        for s in (select value(t) v from table(xxfnd_approval_rule_pkg.steps('KYC_CASE', to_char(p_case_id), l_attrs)) t
                   where t.position = p_level) loop
            l_step := s.v;
        end loop;
        return l_step;
    end level_step;

    function required_levels(p_case_id in number) return number is
        l_attrs apex_t_varchar2 := case_attributes(get_case(p_case_id));
        l_n     number;
    begin
        select count(*) into l_n from table(xxfnd_approval_rule_pkg.steps('KYC_CASE', to_char(p_case_id), l_attrs));
        return l_n;
    end required_levels;

    function level_role(p_case_id in number, p_level in number) return varchar2 is
        l_step xxfnd_approval_step_row := level_step(p_case_id, p_level);
    begin
        return case when l_step is not null and l_step.approver_type = 'ROLE' then l_step.role_code end;
    end level_role;

    function sar_gate(p_case_id in number) return varchar2 is
        l_case xxcmp_cases%rowtype := get_case(p_case_id);
    begin
        return case when l_case.enhanced_kyc_flag = 'Y' then 'Y' else nvl(matrix(l_case).sar_gate_flag, 'N') end;
    end sar_gate;

    function is_editable(p_case_id in number) return varchar2 is
        l_status xxcmp_cases.case_status%type;
    begin
        select max(case_status) into l_status from xxcmp_cases where case_id = p_case_id;
        return case when l_status = 'INVESTIGATION' and xxfnd_privilege_pkg.has_privilege('CASES', 'MANAGE')
                    then 'Y' else 'N' end;
    end is_editable;

    -- Users who investigated or already decided this case, with the roles they acted under.
    function prior_actors(p_case_id in number) return apex_t_varchar2 is
        l_list apex_t_varchar2;
    begin
        select upper(u) bulk collect into l_list from (
            select assigned_to u from xxcmp_cases where case_id = p_case_id and assigned_to is not null
            union
            select actual_owner from apex_tasks
             where task_def_static_id = 'CASE_INVESTIGATION' and detail_pk = to_char(p_case_id) and actual_owner is not null
            union
            select decided_by from xxcmp_case_decisions where case_id = p_case_id);
        return l_list;
    end prior_actors;

    function level_approvers(p_case_id in number) return varchar2 is
        l_step  xxfnd_approval_step_row;
        l_case  xxcmp_cases%rowtype;
        l_role  varchar2(30);
        l_prior apex_t_varchar2;
        l_out   varchar2(32767);
        l_roles apex_t_varchar2;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        l_case  := get_case(p_case_id);
        l_role  := level_role(p_case_id, l_case.current_level);
        l_prior := prior_actors(p_case_id);
        -- release 74: a level for a named user (or the requester) from the Approval Setup
        if l_role is null then
            l_step := level_step(p_case_id, l_case.current_level);
            if l_step.approver_type = 'USER' then
                l_out := upper(l_step.user_name);
            elsif l_step.approver_type = 'REQUESTER' then
                select max(upper(requester_user_name)) into l_out from xxcmp_requests where request_id = l_case.request_id;
            end if;
            xxfnd_vpd_pkg.end_trusted;
            return l_out;
        end if;
        for u in (select distinct ur.user_name from xxfnd_user_roles_v ur
                   where ur.role_code = l_role and ur.active_flag = 'Y'
                   order by ur.user_name) loop
            -- four eyes: nobody decides a case they investigated or already decided,
            -- nor while holding a role that may never be combined with this one
            select role_code bulk collect into l_roles from xxcmp_case_decisions
             where case_id = p_case_id and decided_by = u.user_name and role_code is not null;
            -- role-based only: the role conflict rules (Segregation of Duties) decide, not who acted before
            if not xxfnd_privilege_pkg.sod_conflict(l_role, l_roles, u.user_name) then
                l_out := l_out || case when l_out is not null then ',' end || u.user_name;
            end if;
        end loop;
        xxfnd_vpd_pkg.end_trusted;
        return l_out;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end level_approvers;

    function submit_error(p_case_id in number) return varchar2 is
        l_case  xxcmp_cases%rowtype := get_case(p_case_id);
        l_count pls_integer;
    begin
        if l_case.case_status <> 'INVESTIGATION' then
            return 'The case is not under investigation.';
        end if;
        if l_case.risk_tier is null then
            return 'Set the risk classification.';
        end if;
        if trim(l_case.report_conclusion) is null or trim(l_case.next_steps) is null then
            return 'Enter the report conclusion and the next steps (Risk Assessment).';
        end if;
        select count(*) into l_count from xxcmp_screenings where case_id = p_case_id;
        if l_count = 0 then
            return 'Record at least one screening.';
        end if;
        select count(*) into l_count from xxfnd_rfis
         where entity_name = 'XXCMP_CASES' and pk1_value = to_char(p_case_id)
           and continue_other_work_flag = 'N' and rfi_status in ('WAITING_FOR_INFORMATION', 'ON_HOLD_PENDING', 'RESPONDED');
        if l_count > 0 then
            return 'A request for information that pauses the case is still open.';
        end if;
        if l_case.enhanced_kyc_flag = 'Y' then
            select count(*) into l_count
              from xxcmp_request_answers a
              join xxcmp_questions q on q.question_id = a.question_id
             where a.case_id = p_case_id and a.respondent_type = 'OFFICER'
               and q.section_name = 'Enhanced Due Diligence'
               and a.answer_option_id is null and a.answer_text is null;
            if l_count > 0 then
                return 'Enhanced KYC: answer the source of funds and source of wealth questions.';
            end if;
        end if;
        -- release 76 (A-11): the Approval Setup rule must have an approver for every step (or no step at all)
        if xxfnd_workflow_pkg.workflow_enabled('KYC_CASE') = 'Y' then
            return xxfnd_approval_rule_pkg.approval_error('KYC_CASE', case_attributes(l_case));
        end if;
        return null;
    end submit_error;

    function approval_required(p_case_id in number) return varchar2 is
        l_steps number;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        l_steps := xxfnd_approval_rule_pkg.step_count('KYC_CASE', to_char(p_case_id));
        xxfnd_vpd_pkg.end_trusted;
        return case when xxfnd_workflow_pkg.workflow_enabled('KYC_CASE') = 'Y' and l_steps > 0 then 'Y' else 'N' end;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end approval_required;

    procedure submit_for_approval(p_case_id in number) is
        l_error varchar2(4000) := submit_error(p_case_id);
    begin
        if l_error is not null then
            raise_application_error(-20613, l_error);
        end if;
        -- release 74 (R16): the risk score behind the case is kept for the approvers (approved risk model)
        xxcmp_risk_pkg.calculate(p_case_id);
        -- completing the investigation task moves the KYC_CASE workflow on
        xxfnd_workflow_pkg.complete_open('CASE_INVESTIGATION', to_char(p_case_id));
    end submit_for_approval;

    function approval_error(p_case_id in number) return varchar2 is
        l_case    xxcmp_cases%rowtype := get_case(p_case_id);
        l_missing pls_integer;
    begin
        if l_case.case_status <> 'PENDING_APPROVAL' then
            return 'The case is not waiting for approval.';
        end if;
        if sar_gate(p_case_id) = 'Y' and l_case.sar_required_flag is null then
            return 'Record whether a Suspicious Activity Report is required.';
        end if;
        -- every mandatory document of the party must be verified in this case
        select count(*) into l_missing
          from table(xxcmp_doc_rule_pkg.mandatory_categories('XXCMP_PARTIES',
                         (select jurisdiction from xxcmp_parties where party_id = l_case.party_id),
                         (select case when party_type = 'PERSON' then registration_type else entity_type end
                            from xxcmp_parties where party_id = l_case.party_id))) m
         where not exists (
                 select 1
                   from xxfnd_attached_documents ad
                   join xxcmp_doc_verifications v on v.attached_document_id = ad.attached_document_id
                  where ad.entity_name = 'XXCMP_PARTIES' and ad.pk1_value = to_char(l_case.party_id)
                    and ad.category_code = m.column_value
                    and v.case_id = p_case_id and v.verification_status = 'VERIFIED');
        if l_missing > 0 then
            return l_missing || ' mandatory document(s) are not verified for this case.';
        end if;
        return null;
    end approval_error;

    procedure set_approval_status(p_case_id in number, p_from in varchar2, p_to in varchar2) is
    begin
        xxfnd_vpd_pkg.begin_trusted;
        update xxcmp_cases set case_status = p_to where case_id = p_case_id and case_status = p_from;
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end set_approval_status;

    procedure info_requested(p_case_id in number) is
    begin
        set_approval_status(p_case_id, 'PENDING_APPROVAL', 'PENDING_INFORMATION');
    end info_requested;

    procedure info_submitted(p_case_id in number) is
    begin
        set_approval_status(p_case_id, 'PENDING_INFORMATION', 'PENDING_APPROVAL');
    end info_submitted;

    function info_task(p_request_id in number) return number is
        l_task_id number;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        for c in (select case_id from xxcmp_cases where request_id = p_request_id and case_status = 'PENDING_INFORMATION') loop
            l_task_id := nvl(l_task_id, xxfnd_workflow_pkg.info_task('CASE_APPROVAL', to_char(c.case_id)));
        end loop;
        xxfnd_vpd_pkg.end_trusted;
        return l_task_id;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end info_task;

    function request_of(p_case_id in number) return number is
        l_request_id number;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select max(request_id) into l_request_id from xxcmp_cases where case_id = p_case_id;
        xxfnd_vpd_pkg.end_trusted;
        return l_request_id;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end request_of;

    procedure record_decision(p_case_id in number, p_outcome in varchar2, p_comments in varchar2, p_task_id in number) is
        l_case xxcmp_cases%rowtype;
        l_more varchar2(1);
    begin
        xxfnd_vpd_pkg.begin_trusted;
        l_case := get_case(p_case_id);
        insert into xxcmp_case_decisions (case_id, level_no, role_code, decided_by, outcome, comments, task_id)
        values (p_case_id, l_case.current_level, level_role(p_case_id, l_case.current_level),
                xxfnd_util_pkg.current_user, p_outcome, p_comments, p_task_id);
        if p_outcome = 'APPROVED' then
            update xxcmp_cases set current_level = current_level + 1 where case_id = p_case_id;
            -- keep the Approval Setup's pointer with the level (N after the last level: the workflow approves next)
            l_more := xxfnd_approval_rule_pkg.next_step('KYC_CASE', to_char(p_case_id));
        end if;
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end record_decision;

    function next_review_date(p_case_id in number) return date is
        l_case   xxcmp_cases%rowtype := get_case(p_case_id);
        l_months number;
    begin
        l_months := xxcmp_risk_pkg.review_months(l_case.risk_tier);     -- release 74: the risk model's review interval
        if l_case.pep_flag = 'Y' then
            l_months := least(nvl(l_months, 12), parameter('PEP_REVIEW_MONTHS', 12));
        end if;
        return add_months(trunc(sysdate), nvl(l_months, 12));
    end next_review_date;

    procedure start_approval(p_case_id in number) is
        l_rule varchar2(100);
    begin
        xxfnd_vpd_pkg.begin_trusted;
        l_rule := xxfnd_approval_rule_pkg.start_approval('KYC_CASE', to_char(p_case_id), case_attributes(get_case(p_case_id)),
                                                         null);
        update xxcmp_cases
           set case_status = 'PENDING_APPROVAL', current_level = 1, investigation_completed_date = systimestamp,
               -- release 73: approval workflow switched off - the workflow (version 1.1) approves the case next
               -- release 76 (A-11): or the matching rule has no steps (APPROVAL_REQUIRED = N)
               auto_approved_date = case when xxfnd_workflow_pkg.workflow_enabled('KYC_CASE') = 'N'
                                           or xxfnd_approval_rule_pkg.step_count('KYC_CASE', to_char(p_case_id)) = 0
                                         then systimestamp end
         where case_id = p_case_id;
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end start_approval;

    function has_next_level(p_case_id in number) return varchar2 is
        l_result varchar2(1);
    begin
        xxfnd_vpd_pkg.begin_trusted;
        l_result := case when get_case(p_case_id).current_level <= required_levels(p_case_id) then 'Y' else 'N' end;
        xxfnd_vpd_pkg.end_trusted;
        return l_result;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end has_next_level;

    -- release 90: one routine for the two outcomes (was APPROVE_CASE / REJECT_CASE); the KYC_CASE workflow calls it
    procedure close_case(p_case_id in number, p_decision in varchar2) is
        l_case xxcmp_cases%rowtype;
        l_next date;
    begin
        if p_decision is null or p_decision not in ('APPROVED', 'REJECTED') then
            raise_application_error(-20615, 'Unknown case decision: ' || p_decision);
        end if;
        xxfnd_vpd_pkg.begin_trusted;
        l_case := get_case(p_case_id);
        -- computed first: the function reads XXCMP_CASES, which would be mutating inside the UPDATE
        l_next := case when p_decision = 'APPROVED' then nvl(l_case.next_review_date, next_review_date(p_case_id)) end;
        update xxcmp_cases
           set case_status      = p_decision,
               decision         = p_decision,
               decision_date    = systimestamp,
               next_review_date = l_next,
               closed_date      = systimestamp
         where case_id = p_case_id;
        -- the party's next KYC date follows its latest decided case (cleared when the KYC is rejected)
        update xxcmp_parties set next_kyc_date = l_next where party_id = l_case.party_id;
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end close_case;

    procedure raise_rfi(p_entity_name      in varchar2,
                        p_pk1_value        in varchar2,
                        p_recipient_type   in varchar2,
                        p_recipient_user   in varchar2,
                        p_party_contact_id in number,
                        p_rfi_category     in varchar2,
                        p_description      in varchar2,
                        p_continue_work    in varchar2,
                        p_due_date         in date) is
        l_name   xxcmp_party_contacts.contact_name%type;
        l_email  xxcmp_party_contacts.email%type;
        l_rfi_id number;
        l_token  varchar2(64);
        l_case   xxcmp_cases%rowtype;
        l_req    varchar2(255);
    begin
        -- release 74 (default): who provides the information comes from the Approval Setup (CASE_RFI: the requester
        -- of the case unless a rule says otherwise); the same workflow options apply (ad-hoc provider, ask again)
        if p_recipient_type = 'SETUP' then
            xxfnd_vpd_pkg.begin_trusted;
            if p_entity_name = 'XXCMP_CASES' then
                l_case := get_case(to_number(p_pk1_value));
                select max(requester_user_name) into l_req from xxcmp_requests where request_id = l_case.request_id;
            elsif p_entity_name = 'XXCMP_REQUESTS' then
                select max(requester_user_name) into l_req from xxcmp_requests where request_id = to_number(p_pk1_value);
            end if;
            xxfnd_vpd_pkg.end_trusted;
            xxfnd_rfi_pkg.create_rfi(
                p_entity_name         => p_entity_name,
                p_pk1_value           => p_pk1_value,
                p_recipient_type      => 'USER',
                p_rfi_category        => p_rfi_category,
                p_description         => p_description,
                p_continue_other_work => p_continue_work,
                p_due_date            => p_due_date,
                p_recipient_user_name => l_req,
                p_application_code    => 'KYC',
                p_approval_type       => 'CASE_RFI',
                p_attributes          => apex_t_varchar2('RFI_CATEGORY=' || p_rfi_category, 'RISK_TIER=' || l_case.risk_tier),
                p_requester           => l_req,
                p_rfi_id              => l_rfi_id,
                p_token               => l_token);
            xxfnd_rfi_pkg.send_email(l_rfi_id);
            return;
        end if;
        if p_recipient_type in ('EXTERNAL_PARTY', 'EXTERNAL') then
            select max(contact_name), max(email) into l_name, l_email
              from xxcmp_party_contacts where party_contact_id = p_party_contact_id;
            if l_email is null then
                xxfnd_error_pkg.raise_error('KYC_CASE_CONTACT_NO_EMAIL');
            end if;
        end if;
        xxfnd_rfi_pkg.create_rfi(
            p_entity_name         => p_entity_name,
            p_pk1_value           => p_pk1_value,
            p_recipient_type      => case when p_recipient_type in ('EXTERNAL_PARTY', 'EXTERNAL') then 'EXTERNAL' else 'USER' end,
            p_rfi_category        => p_rfi_category,
            p_description         => p_description,
            p_continue_other_work => p_continue_work,
            p_due_date            => p_due_date,
            p_recipient_user_name => case when p_recipient_type not in ('EXTERNAL_PARTY', 'EXTERNAL') then p_recipient_user end,
            p_recipient_name      => l_name,
            p_recipient_email     => l_email,
            p_recipient_reference => to_char(p_party_contact_id),
            p_application_code    => 'KYC',
            p_rfi_id              => l_rfi_id,
            p_token               => l_token);
        -- release 89: an outside person answers on COMMON's public page Provide Information (50) through the one-time
        -- link of the RFI_RAISED e-mail (COMMON builds it from the token); a user answers on COMMON's task page 143
        xxfnd_rfi_pkg.send_email(l_rfi_id, p_token => l_token);
    end raise_rfi;

    function rfi_task(p_rfi_id in number) return number is
        l_task number;
    begin
        -- the tasks belong to COMMON's application (workflow RFI); APEX gives only the user's own (or delegated) ones
        select max(t.task_id) into l_task
          from table(apex_human_task.get_tasks(p_context        => 'MY_TASKS',
                                               p_application_id => xxfnd_workflow_pkg.common_application_id)) t
         where t.task_def_static_id in ('RFI_RESPONSE', 'RFI_REVIEW')
           and t.detail_pk = to_char(p_rfi_id)
           and t.state_code in ('UNASSIGNED', 'ASSIGNED');
        return l_task;
    end rfi_task;

    procedure apply_screening(p_case_id in number) is
        l_pep pls_integer;
        l_hit pls_integer;
    begin
        select count(case when pep_flag = 'Y' then 1 end), count(case when match_status = 'CONFIRMED_MATCH' then 1 end)
          into l_pep, l_hit
          from xxcmp_screenings where case_id = p_case_id;
        update xxcmp_cases
           set pep_flag          = case when l_pep > 0 then 'Y' else pep_flag end,
               enhanced_kyc_flag = case when l_pep > 0 or l_hit > 0 then 'Y' else enhanced_kyc_flag end
         where case_id = p_case_id and case_status = 'INVESTIGATION';
    end apply_screening;

    function section_state(p_case_id in number, p_section in varchar2) return varchar2 is
        l_case  xxcmp_cases%rowtype := get_case(p_case_id);
        l_party xxcmp_parties%rowtype;
        l_count pls_integer;
    begin
        select * into l_party from xxcmp_parties where party_id = l_case.party_id;
        case p_section
            when 'SUMMARY' then
                return 'DONE';
            when 'PARTY' then
                -- the party details are complete and, for an organisation, its ownership is recorded
                if xxcmp_party_pkg.party_error(l_party.party_id, l_party.party_type, l_party.party_name,
                                               l_party.jurisdiction, l_party.registration_number, l_party.entity_type,
                                               l_party.incorporation_date, l_party.email, l_party.phone, 'N', 'Y',
                                               l_party.registration_type) is not null then
                    return 'TODO';
                end if;
                if l_party.party_type = 'PERSON' then
                    return 'DONE';
                end if;
                select count(*) into l_count from dual
                 where exists (select 1 from xxcmp_party_relationships where object_party_id = l_party.party_id);
                return case when l_count > 0 then 'DONE' else 'TODO' end;
            when 'TREE' then
                -- every party in the ownership tree has a screening in this case
                select count(*) into l_count
                  from json_table(xxcmp_party_pkg.ownership_tree_json(l_case.party_id, null, p_case_id), '$[*]'
                         columns (screening_id number path '$.screening_id')) j
                 where j.screening_id is null;
                return case when l_count = 0 then 'DONE' else 'TODO' end;
            when 'SCREENING' then
                select count(*) into l_count from xxcmp_screenings where case_id = p_case_id;
                return case when l_count > 0 then 'DONE' else 'TODO' end;
            when 'DOCUMENTS' then
                select count(*) into l_count
                  from table(xxcmp_doc_rule_pkg.mandatory_categories('XXCMP_PARTIES', l_party.jurisdiction,
                                 case when l_party.party_type = 'PERSON' then l_party.registration_type else l_party.entity_type end)) m
                 where not exists (
                         select 1
                           from xxfnd_attached_documents ad
                           join xxcmp_doc_verifications v on v.attached_document_id = ad.attached_document_id
                          where ad.entity_name = 'XXCMP_PARTIES' and ad.pk1_value = to_char(l_case.party_id)
                            and ad.category_code = m.column_value
                            and v.case_id = p_case_id and v.verification_status = 'VERIFIED');
                return case when l_count = 0 then 'DONE' else 'TODO' end;
            when 'RISK' then
                return case when l_case.risk_tier is not null then 'DONE' else 'TODO' end;
            when 'NOTES' then
                select count(*) into l_count from xxfnd_rfis
                 where entity_name = 'XXCMP_CASES' and pk1_value = to_char(p_case_id)
                   and rfi_status in ('WAITING_FOR_INFORMATION', 'ON_HOLD_PENDING', 'RESPONDED');
                return case when l_count > 0 then 'WARN' else 'DONE' end;
            when 'REVIEW' then
                return case when l_case.case_status <> 'INVESTIGATION' or submit_error(p_case_id) is null then 'DONE' else 'TODO' end;
            else
                return null;
        end case;
    end section_state;

    function sections return varchar2 is
    begin
        return c_sections;
    end sections;

    function case_summary_json(p_case_id in number, p_task_id in number default null) return clob is
        l_rows json_array_t := json_array_t();
        l_seq  pls_integer := 0;

        procedure fld(p_group in varchar2, p_label in varchar2, p_value in varchar2, p_tone in varchar2 default null,
                      p_url in varchar2 default null, p_link_text in varchar2 default null, p_user in varchar2 default null) is
            l_row json_object_t := json_object_t();
        begin
            if p_value is not null then
                l_seq := l_seq + 10;
                l_row.put('group_name', p_group);
                l_row.put('seq', l_seq);
                l_row.put('label', p_label);
                l_row.put('value', p_value);
                l_row.put('tone', p_tone);
                l_row.put('url', p_url);
                l_row.put('link_text', p_link_text);
                l_row.put('user_name', p_user);
                l_rows.append(l_row);
            end if;
        end fld;

        procedure missing(p_label in varchar2, p_text in varchar2, p_section in varchar2) is
        begin
            fld('Assessment', p_label, p_text, 'missing',
                apex_page.get_url(p_page => 211, p_items => 'P211_CASE_ID,P211_TASK_ID,P211_SECTION',
                                  p_values => p_case_id || ',' || p_task_id || ',' || p_section),
                xxfnd_lookup_pkg.lookup_meaning('CASE_SECTION', p_section));
        end missing;
    begin
        for c in (select c.*, r.request_number, xxfnd_lookup_pkg.lookup_meaning('KYC_REQUEST_TYPE', r.request_type) as request_type
                    from xxcmp_cases c
                    left join xxcmp_requests r on r.request_id = c.request_id
                   where c.case_id = p_case_id) loop     -- data security applies
            fld('Case', 'Request', c.request_number || nvl2(c.request_type, ' · ' || c.request_type, null));
            fld('Case', 'Business relationship', xxfnd_lookup_pkg.lookup_meaning('BUSINESS_RELATIONSHIP', c.business_relationship));
            fld('Case', 'Assigned to', nvl(xxfnd_ui_pkg.person_name(c.assigned_to), 'Nobody'), null, null, null, c.assigned_to);
            fld('Case', 'Opened', to_char(c.creation_date, 'DD-MON-YYYY'));
            fld('Case', 'SLA due', to_char(c.sla_due_date, 'DD-MON-YYYY'));
            fld('Case', 'Closed', to_char(c.closed_date, 'DD-MON-YYYY'));
            if c.risk_tier is not null then
                fld('Assessment', 'Risk classification', xxfnd_ui_pkg.status_label('RISK', c.risk_tier),
                    xxfnd_ui_pkg.status_tone('RISK', c.risk_tier));
            else
                missing('Risk classification', 'Not classified', 'RISK');
            end if;
            fld('Assessment', 'Due Diligence Type', xxfnd_lookup_pkg.lookup_meaning('DUE_DILIGENCE_TYPE', c.due_diligence_type),
                case when c.enhanced_kyc_flag = 'Y' then 'warning' end);
            fld('Assessment', 'PEP', case when c.pep_flag = 'Y' then 'Yes' else 'No' end,
                case when c.pep_flag = 'Y' then 'danger' end);
            fld('Assessment', 'Next review', to_char(c.next_review_date, 'DD-MON-YYYY'));
            fld('Assessment', 'Report conclusion', c.report_conclusion);
            fld('Assessment', 'Next steps', c.next_steps);
            fld('Assessment', 'Conditions', c.conditions);
        end loop;
        return l_rows.to_clob;
    end case_summary_json;

    function section_progress(p_case_id in number) return varchar2 is
        l_done  pls_integer := 0;
        l_total pls_integer := 0;
    begin
        for s in (select column_value code from table(apex_string.split(c_sections, ':'))) loop
            l_total := l_total + 1;
            if section_state(p_case_id, s.code) = 'DONE' then
                l_done := l_done + 1;
            end if;
        end loop;
        return l_done || ' / ' || l_total;
    end section_progress;

    function case_history_rows(p_case_id in number) return xxcmp_history_tab pipelined is
        l_case   xxcmp_cases%rowtype;
        l_done   number;
        l_attrs  apex_t_varchar2;
    begin
        if p_case_id is null then
            return;
        end if;
        xxfnd_vpd_pkg.begin_trusted;
        select * into l_case from xxcmp_cases where case_id = p_case_id;
        xxfnd_vpd_pkg.end_trusted;
        pipe row (xxcmp_history_row(null, 'Case opened', null, 'Opened',
                                    case when lower(l_case.created_by) = 'nobody' then 'System' else l_case.created_by end,
                                    l_case.creation_date, null));
        for h in (select cast(h.event_timestamp as timestamp) as at_time, h.event_creator,
                         case h.event_type_code when 'COMPLETE' then 'Submitted for approval' when 'CLAIM' then 'Claimed'
                                                when 'DELEGATE' then 'Delegated' end as action
                    from apex_task_history h
                    join apex_tasks t on t.task_id = h.task_id
                   where t.detail_pk = to_char(p_case_id) and t.task_def_static_id = 'CASE_INVESTIGATION'
                     and h.event_type_code in ('COMPLETE', 'CLAIM', 'DELEGATE')
                   order by h.event_timestamp) loop
            pipe row (xxcmp_history_row(null, 'Investigation', l_case.assigned_to, h.action, h.event_creator, h.at_time, null));
        end loop;
        for d in (select level_no, role_code, decided_by, outcome, cast(decision_date as timestamp) as at_time, comments
                    from xxcmp_case_decisions where case_id = p_case_id order by decision_date) loop
            pipe row (xxcmp_history_row(d.level_no, 'Approval level ' || d.level_no, xxfnd_approval_rule_pkg.approver_label('ROLE', d.role_code, null),
                                        initcap(d.outcome), d.decided_by, d.at_time, d.comments));
        end loop;
        if l_case.auto_approved_date is not null then
            -- release 73: approval workflow switched off for the process
            pipe row (xxcmp_history_row(null, 'Approval', null, xxfnd_workflow_pkg.c_auto_approved, 'System',
                                        l_case.auto_approved_date, null));
        end if;
        if l_case.case_status = 'INVESTIGATION' then
            pipe row (xxcmp_history_row(null, 'Investigation', l_case.assigned_to, 'In progress', null, null, null));
        end if;
        if l_case.case_status in ('INVESTIGATION', 'PENDING_APPROVAL', 'PENDING_INFORMATION') and l_case.auto_approved_date is null then
            -- release 74: the levels to come from the Approval Setup (transaction type KYC_CASE)
            select count(*) into l_done from xxcmp_case_decisions where case_id = p_case_id and outcome = 'APPROVED';
            l_attrs := case_attributes(l_case);
            for s in (select * from table(xxfnd_approval_rule_pkg.steps('KYC_CASE', to_char(p_case_id), l_attrs))
                       where position > l_done order by position) loop
                pipe row (xxcmp_history_row(s.position, s.step_name,
                                            xxfnd_approval_rule_pkg.approver_label(s.approver_type, s.role_code, s.user_name),
                                            case when l_case.case_status = 'INVESTIGATION' then 'Expected'
                                                 when s.position = l_done + 1 then 'Pending' else 'Waiting' end,
                                            null, null, null));
            end loop;
        end if;
        return;
    exception
        when no_data_found then
            xxfnd_vpd_pkg.end_trusted;
            return;
    end case_history_rows;

    procedure screening_saved(p_screening_id in number) is
    begin
        update xxcmp_screenings set changed_by_person_flag = 'Y'
         where screening_id = p_screening_id and capture_method = 'API' and changed_by_person_flag = 'N';
    end screening_saved;

    procedure review_screening(p_screening_id in number) is
    begin
        update xxcmp_screenings set reviewed_by = xxfnd_util_pkg.current_user, reviewed_date = trunc(sysdate)
         where screening_id = p_screening_id;
    end review_screening;

    function fiu_report_error(p_case_id in number, p_report_type in varchar2, p_grounds in varchar2) return varchar2 is
    begin
        if p_case_id is null then
            return 'Open the report from its case.';
        elsif p_report_type is null then
            return 'Choose the type of report.';
        elsif trim(p_grounds) is null then
            return 'Enter the grounds for suspicion.';
        end if;
        return null;
    end fiu_report_error;

    function fiu_editable(p_fiu_report_id in number, p_case_id in number) return varchar2 is
        l_status xxcmp_fiu_reports.report_status%type;
    begin
        if p_case_id is null or not xxfnd_privilege_pkg.has_privilege('CASES', 'CREATE') then
            return 'N';
        elsif p_fiu_report_id is null then
            return 'Y';
        end if;
        select max(report_status) into l_status from xxcmp_fiu_reports where fiu_report_id = p_fiu_report_id;
        return case when l_status = 'DRAFT' then 'Y' else 'N' end;
    end fiu_editable;

    function fiu_action_allowed(p_fiu_report_id in number, p_action in varchar2) return varchar2 is
        l_r xxcmp_fiu_reports%rowtype;
    begin
        select * into l_r from xxcmp_fiu_reports where fiu_report_id = p_fiu_report_id;
        return case
                   when p_action = 'APPROVE' then
                       case when l_r.report_status = 'DRAFT' and xxfnd_privilege_pkg.has_privilege('CASES', 'MANAGE')
                                 and upper(l_r.prepared_by) <> upper(xxfnd_util_pkg.current_user) then 'Y' else 'N' end
                   when p_action = 'FILE' then
                       case when l_r.report_status = 'APPROVED' and xxfnd_privilege_pkg.has_privilege('CASES', 'MANAGE')
                            then 'Y' else 'N' end
                   when p_action = 'CANCEL' then
                       case when l_r.report_status in ('DRAFT', 'APPROVED') and xxfnd_privilege_pkg.has_privilege('CASES', 'MANAGE')
                            then 'Y' else 'N' end
                   else 'N' end;
    exception
        when no_data_found then
            return 'N';
    end fiu_action_allowed;

    procedure fiu_action(p_fiu_report_id in number, p_action in varchar2, p_reference in varchar2 default null,
                         p_filed_date in date default null) is
    begin
        if fiu_action_allowed(p_fiu_report_id, p_action) = 'N' then
            xxfnd_error_pkg.raise_error('XXFND_NOT_ALLOWED');
        end if;
        if p_action = 'APPROVE' then
            update xxcmp_fiu_reports set report_status = 'APPROVED', approved_by = xxfnd_util_pkg.current_user,
                                         approved_date = trunc(sysdate)
             where fiu_report_id = p_fiu_report_id;
        elsif p_action = 'FILE' then
            if trim(p_reference) is null or p_filed_date is null then
                xxfnd_error_pkg.raise_error('KYC_CASE_FIU_FILING');
            end if;
            update xxcmp_fiu_reports set report_status = 'FILED', goaml_reference = trim(p_reference), filed_date = p_filed_date,
                                         filed_by = xxfnd_util_pkg.current_user
             where fiu_report_id = p_fiu_report_id;
        elsif p_action = 'CANCEL' then
            update xxcmp_fiu_reports set report_status = 'CANCELLED' where fiu_report_id = p_fiu_report_id;
        end if;
    end fiu_action;

    -- release 90: private (used only here)
    function expected_evidence(p_category in varchar2) return varchar2 is
        l_tag xxfnd_lookup_values.tag%type;
    begin
        select max(tag) into l_tag from xxfnd_lookup_values where lookup_type = 'FUNDS_CATEGORY' and lookup_code = p_category;
        return l_tag;
    end expected_evidence;

    function expected_evidence_text(p_category in varchar2) return varchar2 is
        l_text     varchar2(4000);
        l_expected varchar2(4000) := expected_evidence(p_category);    -- a private function is not called inside SQL
    begin
        select listagg(xxfnd_lookup_pkg.lookup_meaning('FUNDS_EVIDENCE_TYPE', column_value), ', ') within group (order by rownum)
          into l_text
          from table(apex_string.split(l_expected, ','));
        return l_text;
    end expected_evidence_text;

    function funds_error(p_case_id in number, p_funds_type in varchar2, p_category in varchar2, p_evidence_type in varchar2,
                         p_amount in number, p_period_from in date, p_period_to in date) return varchar2 is
        l_expected varchar2(4000) := expected_evidence(p_category);
    begin
        if p_case_id is null then
            return 'Open the source of funds from its case.';
        elsif p_funds_type is null or p_category is null then
            return 'Choose whether it is the source of funds or of wealth, and where the money comes from.';
        elsif p_amount < 0 then
            return 'The amount cannot be negative.';
        elsif p_period_to < p_period_from then
            return 'The statement period ends before it starts.';
        elsif p_evidence_type is not null and l_expected is not null and p_evidence_type <> 'OTHER'
              and instr(',' || l_expected || ',', ',' || p_evidence_type || ',') = 0 then
            return 'For this source the evidence expected is: ' || expected_evidence_text(p_category) || '.';
        end if;
        return null;
    end funds_error;

    procedure verify_funds(p_case_funds_id in number) is
    begin
        update xxcmp_case_funds set verified_flag = 'Y', verified_by = xxfnd_util_pkg.current_user, verified_date = trunc(sysdate)
         where case_funds_id = p_case_funds_id and evidence_type is not null;
        if sql%rowcount = 0 then
            xxfnd_error_pkg.raise_error('KYC_CASE_FUNDS_EVIDENCE');
        end if;
    end verify_funds;

end xxcmp_case_pkg;
/
