--------------------------------------------------------------------------------
-- 16r Request component - XXCMP_REQUEST_PKG body (release 74: own script, R1). KYC only (XXCUS).
--   The request logic: the request form and its rules, the questionnaire, submit / cancel / withdraw, the
--   KYC_REQUEST workflow steps and statuses. Party logic is in XXCMP_PARTY_PKG; the case is opened by
--   XXCMP_CASE_PKG.CREATE_CASE (OPEN_CASE calls it). The specification is in 16b (with the tables), so the request,
--   case and other packages compile in any order.
--   Release 90: + the request approval (path, steps, approvers, history; was XXCMP_APPROVAL_PKG); party reads through
--   XXCMP_PARTY_PKG; PARAM removed (unused here; the case package keeps the one copy); QUESTIONNAIRE_HTML removed.
-- Idempotent: create or replace only.
--------------------------------------------------------------------------------
create or replace package body xxcmp_request_pkg as

    c_type constant varchar2(30) := 'KYC_REQUEST';     -- Approval Setup transaction type of the request approval

    -- release 90: private (used only here). Requester questionnaire for a party type (PERSON -> INDIVIDUAL,
    -- ORGANIZATION -> CORPORATE).
    function questionnaire_for(p_party_type in varchar2) return varchar2 is
    begin
        return case p_party_type when 'PERSON' then 'INDIVIDUAL' else 'CORPORATE' end;
    end questionnaire_for;

    function questionnaire_code(p_party_type in varchar2) return varchar2 is
    begin
        return questionnaire_for(p_party_type);
    end questionnaire_code;

    -- private (release 99): the intake rule on the request's REQUESTER answers (risk points of the chosen options),
    -- shared by SCREENING_OUTCOME and EVALUATE
    function intake_rule(p_request_id in number, p_questionnaire in varchar2,
                         o_score out number, o_critical out pls_integer) return varchar2 is
        l_waiver pls_integer;
        l_low    number;
    begin
        select nvl(sum(o.risk_points), 0),
               count(case when o.critical_flag = 'Y' then 1 end),
               count(case when q.gate_question_flag = 'Y' and o.waiver_qualifying_flag = 'Y' then 1 end)
          into o_score, o_critical, l_waiver
          from xxcmp_request_answers a
          join xxcmp_questions q on q.question_id = a.question_id
          left join xxcmp_answer_options o on o.answer_option_id = a.answer_option_id
         where a.request_id = p_request_id and a.respondent_type = 'REQUESTER';
        select max(low_risk_max_score) into l_low from xxcmp_questionnaires where questionnaire_code = p_questionnaire;
        return case when o_critical > 0 then 'ASSIGNED'
                    when l_waiver > 0 then 'NOT_REQUIRED'
                    when l_low is not null and o_score <= l_low then 'AUTO_APPROVED'
                    else 'ASSIGNED' end;
    end intake_rule;

    procedure add_answer_rows(p_request_id in number, p_case_id in number, p_questionnaire in varchar2,
                              p_respondent in varchar2) is
    begin
        insert into xxcmp_request_answers (request_id, case_id, respondent_type, question_id)
        select p_request_id, p_case_id, p_respondent, q.question_id
          from xxcmp_questions q
         where q.questionnaire_code = p_questionnaire
           and q.enabled_flag = 'Y'
           and not exists (select 1 from xxcmp_request_answers a
                            where a.request_id = p_request_id and a.respondent_type = p_respondent
                              and a.question_id = q.question_id);
    end add_answer_rows;

    function get_request(p_request_id in number) return xxcmp_requests%rowtype is
        l_req xxcmp_requests%rowtype;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select * into l_req from xxcmp_requests where request_id = p_request_id;
        xxfnd_vpd_pkg.end_trusted;
        return l_req;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end get_request;

    -- release 90: the party reads (row, status) are the party package's (XXCMP_PARTY_PKG.GET_PARTY / PARTY_STATUS)

    -- release 90 (from XXCMP_APPROVAL_PKG): the request approval. The approvers come from the common Approval Setup
    -- (transaction type KYC_REQUEST, C_TYPE); the request's own columns (APPROVAL_PATH_NAME = the rule, CURRENT_STEP = the
    -- position) are kept up to date for the screens.
    -- private (release 96): the code of a requesting department (XXHR_ORGANIZATIONS.ORGANIZATION_ID), or null
    function department_code(p_department_id in number) return varchar2 is
        l_code xxhr_organizations.organization_code%type;
    begin
        select max(organization_code) into l_code from xxhr_organizations
         where organization_id = p_department_id and organization_type = 'DEPARTMENT';
        return l_code;
    end department_code;

    function attributes(p_req in xxcmp_requests%rowtype) return apex_t_varchar2 is
    begin
        -- release 96: the approval rules keep naming the department by its code
        return apex_t_varchar2('REQUESTING_DEPARTMENT=' || department_code(p_req.requesting_department_id),
                               'PARTY_TYPE=' || p_req.party_type,
                               'JURISDICTION=' || p_req.jurisdiction, 'REQUEST_TYPE=' || p_req.request_type,
                               'BUSINESS_RELATIONSHIP=' || p_req.business_relationship);
    end attributes;

    -- private: the rule (path) that applies to the request (most matching criteria, then lowest priority)
    function path_for(p_request_id in number) return varchar2 is
        l_rule number := xxfnd_approval_rule_pkg.matching_rule(c_type, attributes(get_request(p_request_id)));
        l_name varchar2(100);
    begin
        select max(rule_name) into l_name from xxfnd_approval_rules where rule_id = l_rule;
        return l_name;
    end path_for;

    -- private: starts the path on submit (first step); no rule or a step nobody can approve raises the rule's error
    procedure start_path(p_request_id in number) is
        l_req  xxcmp_requests%rowtype := get_request(p_request_id);
        l_rule varchar2(100);
    begin
        l_rule := xxfnd_approval_rule_pkg.start_approval(c_type, to_char(p_request_id), attributes(l_req),
                                                         l_req.requester_user_name);
        xxfnd_vpd_pkg.begin_trusted;
        update xxcmp_requests set approval_path_name = l_rule, current_step = 1 where request_id = p_request_id;
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end start_path;

    function step_approvers(p_request_id in number) return varchar2 is
    begin
        return coalesce(xxfnd_approval_rule_pkg.current_approvers(c_type, to_char(p_request_id)),
                        -- a request whose approval started before the Approval Setup: Compliance, as before
                        xxfnd_workflow_pkg.users_with_privilege('CASES', 'CREATE'));
    end step_approvers;

    function step_name(p_request_id in number) return varchar2 is
    begin
        return nvl(xxfnd_approval_rule_pkg.current_step_name(c_type, to_char(p_request_id)), 'Compliance review');
    end step_name;

    -- private (release 75): Y when the current step is the last one (a request approved before the Approval Setup has one)
    function is_last_step(p_request_id in number) return varchar2 is
        l_pos number := xxfnd_approval_rule_pkg.current_position(c_type, to_char(p_request_id));
    begin
        return case when l_pos is null or l_pos >= xxfnd_approval_rule_pkg.step_count(c_type, to_char(p_request_id))
                    then 'Y' else 'N' end;
    end is_last_step;

    function next_step(p_request_id in number) return varchar2 is
        l_more varchar2(1) := xxfnd_approval_rule_pkg.next_step(c_type, to_char(p_request_id));
        l_pos  number      := xxfnd_approval_rule_pkg.current_position(c_type, to_char(p_request_id));
    begin
        if l_more = 'N' then
            return 'N';
        end if;
        xxfnd_vpd_pkg.begin_trusted;
        update xxcmp_requests set current_step = l_pos, last_action_date = sysdate where request_id = p_request_id;
        xxfnd_vpd_pkg.end_trusted;
        return 'Y';
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end next_step;

    -- a Pending party created with a request that no other open or approved request uses gets P_STATUS
    procedure release_party(p_party_id in number, p_request_id in number, p_status in varchar2) is
        l_other pls_integer;
    begin
        if p_party_id is null or xxcmp_party_pkg.party_status(p_party_id) <> 'PENDING' then
            return;
        end if;
        xxfnd_vpd_pkg.begin_trusted;
        select count(*) into l_other from xxcmp_requests
         where party_id = p_party_id and request_id <> p_request_id
           and request_status not in ('CANCELLED', 'REJECTED');
        xxfnd_vpd_pkg.end_trusted;
        if l_other = 0 then
            xxcmp_party_pkg.set_status(p_party_id, p_status);
        end if;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end release_party;

    -- release 90: private. New DRAFT request with one empty answer row per question of its questionnaire. The
    -- counterparty columns are shared by organisations and individuals (see XXCMP_PARTY_PKG).
    function create_request(p_party_type            in varchar2,
                            p_party_name            in varchar2,
                            p_registration_number   in varchar2 default null,
                            p_jurisdiction          in varchar2 default null,
                            p_entity_type           in varchar2 default null,
                            p_incorporation_date    in date     default null,
                            p_requesting_department_id in number default null,
                            p_justification         in varchar2 default null,
                            p_request_type          in varchar2 default 'NEW_ONBOARDING',
                            p_trigger_source        in varchar2 default 'MANUAL',
                            p_parent_request_id     in number   default null,
                            p_parent_case_id        in number   default null,
                            p_party_id              in number   default null,
                            p_registration_type     in varchar2 default null,
                            p_business_relationship in varchar2 default null) return number is
        l_id  number;
        l_qnr varchar2(30) := case when p_request_type = 'NEW_ONBOARDING' then questionnaire_for(p_party_type) end;
    begin
        insert into xxcmp_requests (request_number, request_type, trigger_source, parent_request_id, parent_case_id,
                                    party_id, party_type, party_name, registration_number, jurisdiction, entity_type,
                                    incorporation_date, requesting_department_id, requester_user_name,
                                    questionnaire_code, justification, last_action_date,
                                    registration_type, business_relationship)
        values ('REQ-' || lpad(xxcmp_request_number_s.nextval, 6, '0'), p_request_type, p_trigger_source,
                p_parent_request_id, p_parent_case_id, p_party_id, p_party_type, p_party_name, p_registration_number,
                p_jurisdiction, p_entity_type, p_incorporation_date, p_requesting_department_id,
                xxfnd_util_pkg.current_user, l_qnr, p_justification, sysdate,
                p_registration_type, p_business_relationship)
        returning request_id into l_id;
        if l_qnr is not null then
            add_answer_rows(l_id, null, l_qnr, 'REQUESTER');
        end if;
        return l_id;
    end create_request;

    -- release 96: the department is COMMON's organization of type DEPARTMENT (XXHR_ORGANIZATIONS.ORGANIZATION_ID)
    function default_department return number is
        l_id number;
    begin
        select min(g.organization_id) keep (dense_rank first order by
                   case when g.organization_code = upper(trim(e.department_name)) then 1 else 2 end)
          into l_id
          from xxhr_employees e
          join xxhr_organizations g
            on g.organization_type = 'DEPARTMENT' and g.enabled_flag = 'Y'
           and (g.organization_code = upper(trim(e.department_name))
                or upper(g.organization_name) = upper(trim(e.department_name)))
         where e.user_name = upper(xxfnd_util_pkg.current_user) and e.enabled_flag = 'Y';
        return l_id;
    end default_department;

    function department_name(p_department_id in number) return varchar2 is
        l_name xxhr_organizations.organization_name%type;
    begin
        select max(organization_name) into l_name from xxhr_organizations
         where organization_id = p_department_id and organization_type = 'DEPARTMENT';
        return l_name;
    end department_name;

    function allowed_departments return varchar2 is
    begin
        return xxfnd_vpd_pkg.allowed_values('XXCMP_REQUESTS', 'REQUESTING_DEPARTMENT_ID');
    end allowed_departments;

    function can_choose_department return varchar2 is
    begin
        return case when xxfnd_privilege_pkg.has_privilege('CASES', 'VIEW') then 'Y' else 'N' end;
    end can_choose_department;

    function duplicate_party_id(p_request_id          in number,
                                p_party_type          in varchar2,
                                p_registration_number in varchar2,
                                p_jurisdiction        in varchar2,
                                p_registration_type   in varchar2) return number is
        l_own number;
    begin
        if p_request_id is not null then
            l_own := get_request(p_request_id).party_id;
        end if;
        return xxcmp_party_pkg.exact_party_id(p_party_type, p_registration_number, p_jurisdiction, l_own,
                                              p_registration_type);
    end duplicate_party_id;

    function request_error(p_request_id          in number,
                           p_party_selection     in varchar2,
                           p_party_id            in number,
                           p_party_type          in varchar2,
                           p_party_name          in varchar2,
                           p_jurisdiction        in varchar2,
                           p_registration_number in varchar2,
                           p_entity_type         in varchar2,
                           p_incorporation_date  in date,
                           p_email               in varchar2,
                           p_phone               in varchar2,
                           p_justification       in varchar2,
                           p_draft               in varchar2 default 'N',
                           p_match_ack           in varchar2 default 'Y',
                           p_registration_type   in varchar2 default null,
                           p_business_relationship in varchar2 default null,
                           p_use_existing        in varchar2 default null) return varchar2 is
        l_own   number;
        l_dup   number;
        l_party xxcmp_parties%rowtype;
        l_error varchar2(4000);
    begin
        if p_party_selection = 'EXISTING' then
            if p_party_id is null then
                return 'Choose the existing counterparty.';
            elsif xxcmp_party_pkg.party_status(p_party_id) in ('REJECTED', 'CANCELLED')
                  or xxcmp_party_pkg.is_enabled(p_party_id) = 'N' then
                return 'Choose an enabled party that is not rejected or cancelled.';
            end if;
        else
            -- the request's own party is not a duplicate of itself
            if p_request_id is not null then
                l_own := get_request(p_request_id).party_id;
            end if;
            -- release 100: no duplicate counterparty - the requester uses the existing party (Yes) or changes the
            -- details (No)
            l_dup := duplicate_party_id(p_request_id, p_party_type, p_registration_number, p_jurisdiction,
                                        p_registration_type);
            if l_dup is not null and nvl(p_use_existing, '#') <> 'Y' then
                l_party := xxcmp_party_pkg.get_party(l_dup);
                return case when p_use_existing = 'N'
                            then 'Change the registration type, registration number or country: party '
                                 || l_party.party_number || ' - ' || l_party.party_name || ' already has them.'
                            else 'Party ' || l_party.party_number || ' - ' || l_party.party_name
                                 || ' already has this registration type, registration number and country. Use the'
                                 || ' existing party? Choose Yes or No under the counterparty.' end;
            end if;
            -- Yes: SAVE_REQUEST links the existing party - its own rules apply, not the form's
            if l_dup is null then
                l_error := xxcmp_party_pkg.party_error(l_own, p_party_type, p_party_name, p_jurisdiction,
                                                       p_registration_number, p_entity_type, p_incorporation_date,
                                                       p_email, p_phone, p_draft, p_match_ack, p_registration_type,
                                                       p_request_form => 'Y');
                if l_error is not null then
                    return l_error;
                end if;
            end if;
        end if;
        -- release 104: the business relationship is required whatever the risk screening finds; the business
        -- justification is optional
        if p_draft = 'N' and p_business_relationship is null then
            return 'Choose the business relationship (what the counterparty is to the company).';
        end if;
        return null;
    end request_error;

    -- release 103 (shared by steps 1 and 2): a rejected request is corrected and submitted again - back to Draft, its
    -- own party back to Pending
    procedure reopen_rejected(p_old in out nocopy xxcmp_requests%rowtype) is
    begin
        if p_old.request_status = 'REJECTED' then
            if p_old.party_selection = 'NEW' and p_old.party_id is not null and xxcmp_party_pkg.party_status(p_old.party_id) = 'REJECTED' then
                xxcmp_party_pkg.set_status(p_old.party_id, 'PENDING');
            end if;
            update xxcmp_requests
               set request_status = 'DRAFT', completed_date = null, approval_path_name = null, current_step = null
             where request_id = p_old.request_id;
            p_old.request_status := 'DRAFT';
        end if;
    end reopen_rejected;

    -- release 103 (shared by steps 1 and 2): the department the request is raised for
    function request_department(p_department_id in number) return number is
        l_dept    number := p_department_id;
        l_allowed varchar2(4000) := allowed_departments;
    begin
        -- a requester raises requests for the department of the employee profile; Compliance for any department
        if can_choose_department = 'N' and default_department is not null then
            l_dept := default_department;
        end if;
        -- release 76: only the departments the user's data security allows (Level 1 / Compliance: any)
        if l_allowed = '#NONE' then
            xxfnd_error_pkg.raise_error('KYC_REQUEST_NO_ENTITY');   -- release 95
        elsif l_allowed is not null and l_dept is not null
              and to_char(l_dept) not member of apex_string.split(l_allowed, ',') then
            xxfnd_error_pkg.raise_error('KYC_REQUEST_DEPT_NOT_ALLOWED', apex_t_varchar2(department_name(l_dept)));
        end if;
        return l_dept;
    end request_department;

    -- release 103: the request is locked once submitted, and only its requester changes it
    procedure check_changeable(p_old in xxcmp_requests%rowtype) is
    begin
        if p_old.request_status not in ('DRAFT', 'INFO_NEEDED', 'REJECTED')
           or upper(p_old.requester_user_name) <> upper(xxfnd_util_pkg.current_user) then
            xxfnd_error_pkg.raise_error('KYC_REQUEST_LOCKED', apex_t_varchar2(p_old.request_number));
        end if;
    end check_changeable;

    procedure save_request(p_request_id            in out number,
                           p_party_selection       in varchar2,
                           p_party_id              in number,
                           p_party_type            in varchar2,
                           p_party_name            in varchar2,
                           p_jurisdiction          in varchar2,
                           p_registration_number   in varchar2,
                           p_entity_type           in varchar2,
                           p_incorporation_date    in date,
                           p_email                 in varchar2,
                           p_phone                 in varchar2,
                           p_website               in varchar2,
                           p_fax                   in varchar2,
                           p_requesting_department_id in number,
                           p_justification         in varchar2,
                           p_draft                 in varchar2 default 'N',
                           p_contact_name          in varchar2 default null,
                           p_contact_email         in varchar2 default null,
                           p_contact_phone         in varchar2 default null,
                           p_match_ack             in varchar2 default 'Y',
                           p_registration_type     in varchar2 default null,
                           p_address               in varchar2 default null,
                           p_business_relationship in varchar2 default null,
                           p_use_existing          in varchar2 default null) is
        l_error    varchar2(4000);
        l_old      xxcmp_requests%rowtype;
        l_party    xxcmp_parties%rowtype;
        l_party_id number;
        l_new      boolean := false;
        l_dept     xxcmp_requests.requesting_department_id%type;
        l_qnr      varchar2(30);
        l_selection xxcmp_requests.party_selection%type := p_party_selection;
        l_party_in  number := p_party_id;
    begin
        if p_request_id is not null then
            l_old := get_request(p_request_id);
            check_changeable(l_old);
            if l_old.request_status = 'INFO_NEEDED'
                  and (p_party_selection <> l_old.party_selection
                       or (p_party_selection = 'EXISTING' and p_party_id <> l_old.party_id)) then
                xxfnd_error_pkg.raise_error('KYC_REQUEST_PARTY_FIXED');
            end if;
        end if;
        l_error := request_error(p_request_id, p_party_selection, p_party_id, p_party_type, p_party_name, p_jurisdiction,
                                 p_registration_number, p_entity_type, p_incorporation_date, p_email, p_phone,
                                 p_justification, p_draft, p_match_ack, p_registration_type, p_business_relationship,
                                 p_use_existing);
        if l_error is not null then
            raise_application_error(-20611, l_error);
        end if;
        -- release 100: Yes to the duplicate - the request uses the existing party instead of a new one
        if p_party_selection <> 'EXISTING' and p_use_existing = 'Y' then
            l_party_in := duplicate_party_id(p_request_id, p_party_type, p_registration_number, p_jurisdiction,
                                             p_registration_type);
            if l_party_in is not null then
                l_selection := 'EXISTING';
            end if;
        end if;
        reopen_rejected(l_old);
        l_dept := request_department(p_requesting_department_id);

        if l_selection = 'EXISTING' then
            l_party_id := l_party_in;
            -- the Pending party this request created before is no longer needed
            if l_old.party_selection = 'NEW' and l_old.party_id is not null and l_old.party_id <> l_party_in then
                release_party(l_old.party_id, p_request_id, 'CANCELLED');
            end if;
        else
            -- the request's own Pending party is updated; otherwise a new Pending party is created
            if l_old.party_selection = 'NEW' and xxcmp_party_pkg.party_status(l_old.party_id) = 'PENDING' then
                l_party_id := l_old.party_id;
            elsif l_old.party_selection = 'NEW' and l_old.party_id is not null then
                xxfnd_error_pkg.raise_error('KYC_REQUEST_PARTY_APPROVED');
            end if;
            l_new := l_party_id is null;
            xxcmp_party_pkg.put_party(l_party_id, p_party_type, p_party_name, p_jurisdiction, p_registration_number,
                                      p_entity_type, p_incorporation_date, p_email, p_phone, p_website, p_fax,
                                      p_party_status => 'PENDING', p_registration_type => p_registration_type,
                                      p_address => p_address);
            if l_new and trim(p_contact_name) is not null then
                xxfnd_vpd_pkg.begin_trusted;
                begin
                    insert into xxcmp_party_contacts (party_id, contact_name, email, phone, primary_flag)
                    values (l_party_id, trim(p_contact_name), trim(p_contact_email), trim(p_contact_phone), 'Y');
                exception
                    when others then
                        xxfnd_vpd_pkg.end_trusted;
                        raise;
                end;
                xxfnd_vpd_pkg.end_trusted;
            end if;
        end if;
        l_party := xxcmp_party_pkg.get_party(l_party_id);
        l_qnr   := questionnaire_for(l_party.party_type);    -- a private function is not called inside SQL

        if p_request_id is null then
            p_request_id := create_request(p_party_type => l_party.party_type, p_party_name => l_party.party_name,
                                           p_requesting_department_id => l_dept, p_justification => p_justification,
                                           p_party_id => l_party_id);
            l_old := get_request(p_request_id);
        end if;
        update xxcmp_requests
           set party_selection       = l_selection,
               party_id              = l_party_id,
               party_type            = l_party.party_type,
               party_name            = l_party.party_name,
               registration_number   = l_party.registration_number,
               entity_type           = l_party.entity_type,
               registration_type     = l_party.registration_type,
               business_relationship = p_business_relationship,
               incorporation_date    = l_party.incorporation_date,
               jurisdiction          = l_party.jurisdiction,
               match_status          = case when l_selection = 'EXISTING' then 'SELECTED' else 'NEW' end,
               match_ack_flag        = case when p_match_ack = 'Y' then 'Y' else 'N' end,
               contact_name          = trim(p_contact_name),
               contact_email         = trim(p_contact_email),
               contact_phone         = trim(p_contact_phone),
               requesting_department_id = case when l_old.request_status = 'DRAFT' then l_dept
                                               else requesting_department_id end,
               justification         = p_justification,
               questionnaire_code    = case when l_old.request_status = 'DRAFT' then l_qnr else questionnaire_code end,
               last_action_date      = sysdate
         where request_id = p_request_id;
        -- another type answers another questionnaire
        if l_old.request_status = 'DRAFT' and nvl(l_old.questionnaire_code, '#') <> l_qnr then
            delete from xxcmp_request_answers where request_id = p_request_id and respondent_type = 'REQUESTER';
            add_answer_rows(p_request_id, null, l_qnr, 'REQUESTER');
        end if;
    end save_request;

    function is_editable(p_request_id in number) return varchar2 is
        l_req xxcmp_requests%rowtype;
    begin
        if p_request_id is null then
            return 'Y';
        end if;
        l_req := get_request(p_request_id);
        return case when l_req.request_status in ('DRAFT', 'INFO_NEEDED', 'REJECTED')
                     and upper(l_req.requester_user_name) = upper(xxfnd_util_pkg.current_user) then 'Y' else 'N' end;
    exception
        when no_data_found then
            return 'N';
    end is_editable;

    function party_editable(p_request_id in number) return varchar2 is
        l_req xxcmp_requests%rowtype;
    begin
        if p_request_id is null then
            return 'Y';
        end if;
        l_req := get_request(p_request_id);
        return case when is_editable(p_request_id) = 'Y' and nvl(l_req.party_selection, 'NEW') = 'NEW'
                     and nvl(l_req.match_status, '-') <> 'MERGED' then 'Y' else 'N' end;
    exception
        when no_data_found then
            return 'N';
    end party_editable;

    function request_candidates_json(p_request_id in number) return clob is
        l_req xxcmp_requests%rowtype := get_request(p_request_id);
    begin
        return xxcmp_party_pkg.party_candidates_json(l_req.party_type, l_req.party_name, l_req.registration_number,
                                     l_req.incorporation_date, l_req.jurisdiction, l_req.party_id);
    end request_candidates_json;

    function match_pending(p_request_id in number) return varchar2 is
    begin
        return case when get_request(p_request_id).match_status = 'PENDING' then 'Y' else 'N' end;
    exception
        when no_data_found then
            return 'N';
    end match_pending;

    -- release 90: QUESTIONNAIRE_HTML removed - page 202 shows the questionnaire with the KYC Question template component
    -- fed by SQL (no HTML built here).

    function screening_outcome(p_request_id in number) return varchar2 is
        l_req      xxcmp_requests%rowtype;
        l_missing  pls_integer;
        l_score    number;
        l_critical pls_integer;
    begin
        l_req := get_request(p_request_id);
        if l_req.request_type <> 'NEW_ONBOARDING' or l_req.questionnaire_code is null then
            return 'ASSIGNED';
        end if;
        select count(*) into l_missing
          from xxcmp_request_answers a
          join xxcmp_questions q on q.question_id = a.question_id
         where a.request_id = p_request_id and a.respondent_type = 'REQUESTER'
           and q.required_flag = 'Y' and a.answer_option_id is null and a.answer_text is null;
        if l_missing > 0 then
            return null;
        end if;
        return intake_rule(p_request_id, l_req.questionnaire_code, l_score, l_critical);
    exception
        when no_data_found then
            return null;
    end screening_outcome;

    function outcome_kyc_required(p_outcome in varchar2) return varchar2 is
    begin
        return case when p_outcome = 'ASSIGNED' then 'Yes'
                    when p_outcome in ('NOT_REQUIRED', 'AUTO_APPROVED') then 'No' end;
    end outcome_kyc_required;

    function answers_error(p_request_id in number, p_answers in clob) return varchar2 is
        l_missing varchar2(4000);
    begin
        select listagg(qu.question_text, '; ') within group (order by qu.display_sequence)
          into l_missing
          from xxcmp_request_answers a
          join xxcmp_questions qu on qu.question_id = a.question_id
         where a.request_id = p_request_id
           and a.respondent_type = 'REQUESTER'
           and qu.required_flag = 'Y'
           and not exists (select 1 from json_table(nvl(p_answers, '[]'), '$[*]'
                                            columns (q number path '$.q', o number path '$.o', t varchar2(4000) path '$.t')) j
                            where j.q = a.question_id and (j.o is not null or trim(j.t) is not null));
        return case when l_missing is not null then 'Answer the required questions: ' || l_missing end;
    end answers_error;

    procedure save_answers(p_request_id in number, p_answers in clob) is
        l_status xxcmp_requests.request_status%type;
        l_type   xxcmp_questions.answer_type%type;
        l_option number;
        l_text   varchar2(4000);
    begin
        select request_status into l_status from xxcmp_requests where request_id = p_request_id;
        if l_status not in ('DRAFT', 'INFO_NEEDED') then
            xxfnd_error_pkg.raise_error('KYC_REQUEST_ANSWERS_LOCKED');
        end if;
        for j in (select q, o, t from json_table(nvl(p_answers, '[]'), '$[*]'
                          columns (q number path '$.q', o number path '$.o', t varchar2(4000) path '$.t'))) loop
            begin
                select qu.answer_type into l_type
                  from xxcmp_request_answers a join xxcmp_questions qu on qu.question_id = a.question_id
                 where a.request_id = p_request_id and a.respondent_type = 'REQUESTER' and a.question_id = j.q;
            exception
                when no_data_found then
                    xxfnd_error_pkg.raise_error('KYC_REQUEST_QUESTION_UNKNOWN', apex_t_varchar2(j.q));
            end;
            l_option := null;
            l_text   := null;
            if l_type in ('YES_NO', 'SINGLE_SELECT', 'MULTI_SELECT') then
                if j.o is not null then
                    select max(answer_option_id) into l_option
                      from xxcmp_answer_options
                     where answer_option_id = j.o and question_id = j.q and approval_status = 'APPROVED' and enabled_flag = 'Y';
                    if l_option is null then
                        xxfnd_error_pkg.raise_error('KYC_REQUEST_OPTION_UNKNOWN', apex_t_varchar2(j.o, j.q));
                    end if;
                end if;
            elsif l_type = 'NUMBER' and trim(j.t) is not null
                  and validate_conversion(trim(j.t) as number) = 0 then
                xxfnd_error_pkg.raise_error('KYC_REQUEST_NUMBER_EXPECTED', apex_t_varchar2(j.t));
            else
                l_text := trim(j.t);
            end if;
            update xxcmp_request_answers
               set answer_option_id = l_option,
                   answer_text      = case when l_type in ('YES_NO', 'SINGLE_SELECT', 'MULTI_SELECT') then answer_text else l_text end
             where request_id = p_request_id and respondent_type = 'REQUESTER' and question_id = j.q;
        end loop;
    end save_answers;

    procedure save_screening(p_request_id in number, p_answers in clob) is
        l_known clob;
    begin
        select json_arrayagg(json_object('q' value j.q, 'o' value j.o, 't' value j.t) returning clob)
          into l_known
          from json_table(nvl(p_answers, '[]'), '$[*]'
                          columns (q number path '$.q', o number path '$.o', t varchar2(4000) path '$.t')) j
         where exists (select 1 from xxcmp_request_answers a
                        where a.request_id = p_request_id and a.respondent_type = 'REQUESTER' and a.question_id = j.q);
        save_answers(p_request_id, nvl(l_known, '[]'));
    end save_screening;

    function submit_error(p_request_id in number) return varchar2 is
        l_req     xxcmp_requests%rowtype := get_request(p_request_id);
        l_party   xxcmp_parties%rowtype;
        l_missing pls_integer;
        l_error   varchar2(4000);
        l_docs    varchar2(4000);
    begin
        if l_req.request_status <> 'DRAFT' and returned_for_info(p_request_id) = 'N' then
            return 'This request has already been submitted.';
        end if;
        select count(*) into l_missing
          from xxcmp_request_answers a
          join xxcmp_questions q on q.question_id = a.question_id
         where a.request_id = p_request_id and a.respondent_type = 'REQUESTER'
           and q.required_flag = 'Y' and a.answer_option_id is null and a.answer_text is null;
        if l_missing > 0 then
            return l_missing || ' required question(s) are not answered.';
        end if;
        -- reviews of an existing case (monitoring) come with their party: only a requester's counterparty is checked
        if l_req.parent_case_id is not null then
            return null;
        end if;
        if l_req.party_id is null then
            return 'Choose or enter the counterparty.';
        end if;
        if l_req.party_selection = 'NEW' then
            l_party := xxcmp_party_pkg.get_party(l_req.party_id);
            l_error := request_error(p_request_id, 'NEW', null, l_party.party_type, l_party.party_name, l_party.jurisdiction,
                                     l_party.registration_number, l_party.entity_type, l_party.incorporation_date,
                                     l_party.email, l_party.phone, l_req.justification,
                                     p_registration_type => l_party.registration_type,
                                     p_business_relationship => nvl(l_req.business_relationship, 'X'));
        else
            l_error := request_error(p_request_id, 'EXISTING', l_req.party_id, null, null, null, null, null, null, null,
                                     null, l_req.justification, p_business_relationship => nvl(l_req.business_relationship, 'X'));
        end if;
        if l_error is not null then
            return l_error;
        end if;
        -- mandatory documents of the entity / ID type and country (Mandatory Document Rules), attached to the
        -- request or to the party
        for c in (select c.column_value as category_code,
                         nvl((select max(tl.category_name) from xxfnd_document_categories_tl tl
                               where tl.category_code = c.column_value and tl.language_code = xxfnd_util_pkg.current_lang),
                             (select max(dc.category_name) from xxfnd_document_categories dc
                               where dc.category_code = c.column_value)) as category_name
                    from table(xxcmp_doc_rule_pkg.mandatory_categories('XXCMP_PARTIES', l_req.jurisdiction,
                                 case when l_req.party_type = 'PERSON' then l_req.registration_type else l_req.entity_type end)) c
                   where not exists (select 1 from xxfnd_attached_documents_v a
                                      where a.category_code = c.column_value and nvl(a.expired_flag, 'N') = 'N'
                                        and ((a.entity_name = 'XXCMP_REQUESTS' and a.pk1_value = to_char(p_request_id))
                                          or (a.entity_name = 'XXCMP_PARTIES' and a.pk1_value = to_char(l_req.party_id))))) loop
            l_docs := l_docs || case when l_docs is not null then ', ' end || c.category_name;
        end loop;
        if l_docs is not null then
            return 'Attach the mandatory documents: ' || l_docs || '.';
        end if;
        return null;
    end submit_error;

    procedure submit(p_request_id in number) is
        l_error varchar2(4000) := submit_error(p_request_id);
        l_wf    number;
        l_auto  boolean;
    begin
        if l_error is not null then
            raise_application_error(-20601, l_error);
        end if;
        update xxcmp_requests
           set request_status = 'IN_PROGRESS', submitted_date = systimestamp, last_action_date = sysdate
         where request_id = p_request_id;
        -- release 73: the requester's answer to a question returned by the approver (return_for_info) is the resubmitted
        -- request (release 74: the common RFI)
        for f in (select rfi_id from xxfnd_rfis
                   where entity_name = 'XXCMP_REQUESTS' and pk1_value = to_char(p_request_id)
                     and rfi_status = 'WAITING_FOR_INFORMATION') loop
            xxfnd_rfi_pkg.resolve(f.rfi_id, 'RESOLVED', 'Answered by submitting the request again.');
        end loop;
        if xxfnd_workflow_pkg.workflow_enabled('KYC_REQUEST') = 'Y' then
            -- release 76 (A-11): the Approval Setup rule - no rule or a step nobody can approve stops the submit with its
            -- message; a rule without steps approves the request at once, like the switched-off approval below
            start_path(p_request_id);
            xxfnd_vpd_pkg.begin_trusted;       -- the approval steps are not the requester's to see
            l_auto := xxfnd_approval_rule_pkg.step_count('KYC_REQUEST', to_char(p_request_id)) = 0;
            xxfnd_vpd_pkg.end_trusted;
        else
            l_auto := true;
        end if;
        if l_auto then
            -- release 73: approval workflow switched off - auto-approved: the steps of KYC_REQUEST without the approval
            update xxcmp_requests set auto_approved_date = systimestamp where request_id = p_request_id;
            evaluate(p_request_id);
            if outcome(p_request_id) = 'ASSIGNED' then
                open_case(p_request_id);
            else
                close_without_case(p_request_id);
            end if;
            return;
        end if;
        l_wf := xxfnd_workflow_pkg.start_process('KYC_REQUEST', to_char(p_request_id));
        update xxcmp_requests set workflow_id = l_wf where request_id = p_request_id;
    end submit;

    function cancel_error(p_request_id in number) return varchar2 is
        l_req   xxcmp_requests%rowtype := get_request(p_request_id);
        l_cases pls_integer;
    begin
        if upper(l_req.requester_user_name) <> upper(xxfnd_util_pkg.current_user) then
            return 'Only the requester can cancel request ' || l_req.request_number || '.';
        elsif l_req.request_status = 'IN_PROGRESS' then
            return 'Request ' || l_req.request_number || ' is waiting for approval: withdraw it first.';
        elsif l_req.request_status not in ('DRAFT', 'INFO_NEEDED', 'REJECTED') then
            return 'Request ' || l_req.request_number || ' is closed and cannot be cancelled.';
        end if;
        select count(*) into l_cases from xxcmp_cases where request_id = p_request_id;
        if l_cases > 0 then
            return 'A case has been opened for request ' || l_req.request_number || ': it cannot be cancelled.';
        end if;
        return null;
    end cancel_error;

    procedure cancel(p_request_id in number, p_reason in varchar2 default null) is
        l_error varchar2(4000) := cancel_error(p_request_id);
        l_req   xxcmp_requests%rowtype := get_request(p_request_id);
    begin
        if l_error is not null then
            raise_application_error(-20623, l_error);
        end if;
        -- the running workflow and its open task end with the request
        xxfnd_workflow_pkg.end_process(l_req.workflow_id);
        update xxcmp_requests
           set request_status = 'CANCELLED', completed_date = systimestamp, last_action_date = sysdate,
               match_note = nvl(substr(p_reason, 1, 1000), match_note)
         where request_id = p_request_id;
        release_party(l_req.party_id, p_request_id, 'CANCELLED');
    end cancel;

    function can_request_info(p_task_id in number) return varchar2 is
    begin
        return xxfnd_workflow_pkg.can_request_info(p_task_id);
    end can_request_info;

    function withdraw_error(p_request_id in number) return varchar2 is
        l_req   xxcmp_requests%rowtype := get_request(p_request_id);
        l_cases pls_integer;
    begin
        if upper(l_req.requester_user_name) <> upper(xxfnd_util_pkg.current_user) then
            return 'Only the requester can withdraw request ' || l_req.request_number || '.';
        elsif l_req.request_status <> 'IN_PROGRESS' then
            return 'Only a request waiting for approval can be withdrawn.';
        end if;
        select count(*) into l_cases from xxcmp_cases where request_id = p_request_id;
        if l_cases > 0 then
            return 'A case has been opened for request ' || l_req.request_number || ': it cannot be withdrawn.';
        end if;
        return null;
    end withdraw_error;

    procedure withdraw(p_request_id in number) is
        l_error varchar2(4000) := withdraw_error(p_request_id);
        l_req   xxcmp_requests%rowtype := get_request(p_request_id);
    begin
        if l_error is not null then
            raise_application_error(-20623, l_error);
        end if;
        xxfnd_vpd_pkg.begin_trusted;
        begin
            xxfnd_workflow_pkg.end_process(l_req.workflow_id);
            update xxcmp_requests
               set request_status = 'DRAFT', approval_path_name = null, current_step = null, last_action_date = sysdate
             where request_id = p_request_id;
        exception
            when others then
                xxfnd_vpd_pkg.end_trusted;
                raise;
        end;
        xxfnd_vpd_pkg.end_trusted;
    end withdraw;

    procedure set_status(p_request_id in number, p_from in varchar2, p_to in varchar2) is
    begin
        xxfnd_vpd_pkg.begin_trusted;
        update xxcmp_requests set request_status = p_to, last_action_date = sysdate
         where request_id = p_request_id and request_status = p_from;
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end set_status;

    procedure return_for_info(p_request_id in number, p_task_id in number, p_comment in varchar2) is
        l_req   xxcmp_requests%rowtype := get_request(p_request_id);
        l_rfi_id number;
        l_token  varchar2(64);
    begin
        if p_comment is null then
            xxfnd_error_pkg.raise_error('KYC_REQUEST_INFO_TEXT');
        elsif l_req.request_status <> 'IN_PROGRESS' then
            xxfnd_error_pkg.raise_error('KYC_REQUEST_NOT_IN_APPROVAL', apex_t_varchar2(l_req.request_number));
        elsif not (apex_human_task.is_allowed(p_task_id => p_task_id, p_operation => apex_human_task.c_task_op_approve)
                   or apex_human_task.is_allowed(p_task_id => p_task_id, p_operation => apex_human_task.c_task_op_claim)) then
            xxfnd_error_pkg.raise_error('KYC_REQUEST_NOT_APPROVER', apex_t_varchar2(l_req.request_number));
        end if;
        xxfnd_vpd_pkg.begin_trusted;
        begin
            -- the question is a common RFI to the requester, answered by resubmitting the request (no response task)
            xxfnd_rfi_pkg.create_rfi(p_entity_name => 'XXCMP_REQUESTS', p_pk1_value => to_char(p_request_id),
                                     p_recipient_type => 'USER', p_rfi_category => 'CLARIFICATION',
                                     p_description => substr(p_comment, 1, 4000), p_continue_other_work => 'Y',
                                     p_recipient_user_name => l_req.requester_user_name, p_with_tasks => 'N',
                                     p_rfi_id => l_rfi_id, p_token => l_token);
            xxfnd_workflow_pkg.end_process(l_req.workflow_id);
            update xxcmp_requests set request_status = 'INFO_NEEDED', last_action_date = sysdate
             where request_id = p_request_id;
        exception
            when others then
                xxfnd_vpd_pkg.end_trusted;
                raise;
        end;
        xxfnd_vpd_pkg.end_trusted;
    end return_for_info;

    function returned_for_info(p_request_id in number) return varchar2 is
        l_count pls_integer;
    begin
        select count(*) into l_count from xxcmp_requests r
         where r.request_id = p_request_id and r.request_status = 'INFO_NEEDED'
           and exists (select 1 from xxfnd_rfis f
                        where f.entity_name = 'XXCMP_REQUESTS' and f.pk1_value = to_char(r.request_id)
                          and f.rfi_status = 'WAITING_FOR_INFORMATION');
        return case when l_count > 0 then 'Y' else 'N' end;
    end returned_for_info;

    procedure info_requested(p_request_id in number) is
    begin
        set_status(p_request_id, 'IN_PROGRESS', 'INFO_NEEDED');
    end info_requested;

    procedure info_submitted(p_request_id in number) is
    begin
        set_status(p_request_id, 'INFO_NEEDED', 'IN_PROGRESS');
    end info_submitted;

    -- The request's party: the one chosen or created with the request. Requests saved before release 23 may
    -- still have none: a Pending party is created from what was typed.
    procedure link_party(p_req in out xxcmp_requests%rowtype) is
    begin
        if p_req.party_id is null then
            xxcmp_party_pkg.put_party(p_req.party_id, p_req.party_type, p_req.party_name, p_req.jurisdiction,
                                      p_req.registration_number, p_req.entity_type, p_req.incorporation_date,
                                      p_req.contact_email, p_req.contact_phone, null, null, p_party_status => 'PENDING',
                                      p_registration_type => p_req.registration_type);
            update xxcmp_requests set party_id = p_req.party_id, match_status = 'NEW' where request_id = p_req.request_id;
        end if;
    end link_party;

    procedure evaluate(p_request_id in number) is
        l_req      xxcmp_requests%rowtype;
        l_score    number;
        l_critical pls_integer;
        l_outcome  varchar2(30);
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select * into l_req from xxcmp_requests where request_id = p_request_id for update;
        link_party(l_req);
        if l_req.request_type <> 'NEW_ONBOARDING' or l_req.questionnaire_code is null then
            l_outcome := 'ASSIGNED';                          -- reviews always go to Compliance
        else
            update xxcmp_request_answers a
               set risk_points = (select o.risk_points from xxcmp_answer_options o where o.answer_option_id = a.answer_option_id)
             where a.request_id = p_request_id and a.respondent_type = 'REQUESTER';
            -- release 99: the rule is shared with the risk screening of step 1 (SCREENING_OUTCOME)
            l_outcome := intake_rule(p_request_id, l_req.questionnaire_code, l_score, l_critical);
            update xxcmp_requests set intake_score = l_score, intake_critical_flag = case when l_critical > 0 then 'Y' else 'N' end
             where request_id = p_request_id;
        end if;
        update xxcmp_requests
           set intake_outcome = l_outcome, request_status = 'IN_PROGRESS', last_action_date = sysdate
         where request_id = p_request_id;
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end evaluate;

    function outcome(p_request_id in number) return varchar2 is
    begin
        return get_request(p_request_id).intake_outcome;
    end outcome;

    procedure close_without_case(p_request_id in number) is
        l_party number;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        update xxcmp_requests
           set request_status = 'APPROVED', completed_date = systimestamp, last_action_date = sysdate
         where request_id = p_request_id
        returning party_id into l_party;
        xxfnd_vpd_pkg.end_trusted;
        if xxcmp_party_pkg.party_status(l_party) = 'PENDING' then
            xxcmp_party_pkg.set_status(l_party, 'APPROVED');
        end if;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end close_without_case;

    procedure open_case(p_request_id in number) is
        l_case     number;
        l_assignee xxcmp_requests.case_assignee%type;
    begin
        -- release 75: the officer chosen on the approval (null: the approver, as before)
        -- release 76: locked, so an Assign Case on the request (ASSIGN_CASE) waits for the case or is read here
        select case_assignee into l_assignee from xxcmp_requests where request_id = p_request_id for update;
        l_case := xxcmp_case_pkg.create_case(p_request_id, l_assignee);
        close_without_case(p_request_id);      -- Compliance approved the request: the request and its party are Approved
    end open_case;

    procedure set_case_assignee(p_request_id in number, p_user_name in varchar2) is
    begin
        if p_user_name is not null and xxcmp_case_pkg.is_case_officer(p_user_name) = 'N' then
            xxfnd_error_pkg.raise_error('KYC_CASE_OFFICER_INVALID');
        end if;
        update xxcmp_requests set case_assignee = upper(p_user_name) where request_id = p_request_id;
    end set_case_assignee;

    function request_case(p_request_id in number) return number is
        l_case number;
    begin
        select max(case_id) into l_case from xxcmp_cases where request_id = p_request_id;
        return l_case;
    end request_case;

    function can_assign_case(p_request_id in number) return varchar2 is
        l_case number := request_case(p_request_id);
        l_req  xxcmp_requests%rowtype;
    begin
        if l_case is not null then
            return xxcmp_case_pkg.can_assign(l_case);
        end if;
        select * into l_req from xxcmp_requests where request_id = p_request_id;
        return case when l_req.request_status in ('IN_PROGRESS', 'APPROVED') and l_req.intake_outcome = 'ASSIGNED'
                         and l_req.workflow_id is not null
                         and xxfnd_approval_rule_pkg.is_started('KYC_REQUEST', to_char(p_request_id)) = 'N'
                         and xxfnd_privilege_pkg.has_privilege('CASE_ASSIGNMENT', 'MANAGE')
                    then 'Y' else 'N' end;
    exception
        when no_data_found then
            return 'N';
    end can_assign_case;

    procedure assign_case(p_request_id in number, p_user_name in varchar2, p_comment in varchar2 default null) is
        l_case number;
        l_lock number;
    begin
        select request_id into l_lock from xxcmp_requests where request_id = p_request_id for update;
        l_case := request_case(p_request_id);
        if l_case is not null then
            xxcmp_case_pkg.assign(l_case, p_user_name, p_comment);       -- the case logic stays in the case package
        elsif can_assign_case(p_request_id) = 'Y' then
            if p_user_name is null then
                xxfnd_error_pkg.raise_error('KYC_CASE_OFFICER_REQUIRED');
            end if;
            set_case_assignee(p_request_id, p_user_name);
        else
            xxfnd_error_pkg.raise_error('KYC_CASE_REASSIGN_NOT_ALLOWED');
        end if;
    end assign_case;

    function opens_case_on_approval(p_request_id in number) return varchar2 is
    begin
        return case when outcome(p_request_id) = 'ASSIGNED' and is_last_step(p_request_id) = 'Y'
                    then 'Y' else 'N' end;
    end opens_case_on_approval;

    function create_case_request(p_party_id in number, p_justification in varchar2, p_business_relationship in varchar2)
        return number is
        l_party xxcmp_parties%rowtype;
        l_req   number;
    begin
        l_party := xxcmp_party_pkg.get_party(p_party_id);
        l_req := create_request(
                     p_party_type            => l_party.party_type,
                     p_party_name            => l_party.party_name,
                     p_registration_number   => l_party.registration_number,
                     p_jurisdiction          => l_party.jurisdiction,
                     p_entity_type           => l_party.entity_type,
                     p_registration_type     => l_party.registration_type,
                     p_business_relationship => p_business_relationship,
                     p_incorporation_date    => l_party.incorporation_date,
                     p_justification         => p_justification,
                     p_request_type          => 'EVENT_TRIGGERED_REVIEW',
                     p_trigger_source        => 'MANUAL',
                     p_party_id              => p_party_id);
        update xxcmp_requests set request_status = 'IN_PROGRESS', intake_outcome = 'ASSIGNED', submitted_date = systimestamp,
                                  party_selection = 'EXISTING', match_status = 'SELECTED', last_action_date = sysdate
         where request_id = l_req;
        return l_req;
    end create_case_request;

    procedure reject(p_request_id in number) is
        l_party number;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        update xxcmp_requests
           set request_status = 'REJECTED', completed_date = systimestamp, last_action_date = sysdate
         where request_id = p_request_id
        returning party_id into l_party;
        xxfnd_vpd_pkg.end_trusted;
        release_party(l_party, p_request_id, 'REJECTED');
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end reject;

    function stage(p_request_id in number) return varchar2 is
    begin
        return xxfnd_lookup_pkg.lookup_meaning('KYC_REQUEST_STATUS', get_request(p_request_id).request_status);
    exception
        when no_data_found then
            return null;
    end stage;

    function kyc_required(p_request_id in number) return varchar2 is
        l_outcome xxcmp_requests.intake_outcome%type;
    begin
        l_outcome := get_request(p_request_id).intake_outcome;
        return outcome_kyc_required(l_outcome);
    exception
        when no_data_found then
            return null;
    end kyc_required;

    function pending_with(p_request_id in number) return varchar2 is
        l_req   xxcmp_requests%rowtype;
        l_owner varchar2(255);
        l_open  pls_integer;
    begin
        l_req := get_request(p_request_id);
        if l_req.request_status in ('DRAFT', 'INFO_NEEDED') then
            return l_req.requester_user_name;
        elsif l_req.request_status = 'IN_PROGRESS' then
            select max(actual_owner), count(*) into l_owner, l_open
              from apex_tasks
             where detail_pk = to_char(p_request_id)
               and task_def_static_id in ('DOC_CHECKLIST_REVIEW', 'COUNTERPARTY_MATCH')
               and state_code in ('UNASSIGNED', 'ASSIGNED', 'INFO_REQUESTED');
            return case when l_owner is not null then l_owner
                        when l_open > 0 then 'Compliance'
                        else 'System' end;
        end if;
        return null;
    exception
        when no_data_found then
            return null;
    end pending_with;

    function start_review(p_case_id in number, p_request_type in varchar2, p_trigger_source in varchar2,
                          p_justification in varchar2) return number is
        l_id    number;
        l_party xxcmp_parties%rowtype;
        l_case  xxcmp_cases%rowtype;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select * into l_case from xxcmp_cases where case_id = p_case_id;
        l_party := xxcmp_party_pkg.get_party(l_case.party_id);
        l_id := create_request(p_party_type          => l_party.party_type,
                               p_party_name          => l_party.party_name,
                               p_registration_number => l_party.registration_number,
                               p_jurisdiction        => l_party.jurisdiction,
                               p_entity_type         => l_party.entity_type,
                               p_registration_type   => l_party.registration_type,
                               p_business_relationship => l_case.business_relationship,
                               p_incorporation_date  => l_party.incorporation_date,
                               p_justification       => p_justification,
                               p_request_type        => p_request_type,
                               p_trigger_source      => p_trigger_source,
                               p_parent_request_id   => l_case.request_id,
                               p_parent_case_id      => p_case_id,
                               p_party_id            => l_case.party_id);
        update xxcmp_requests set party_selection = 'EXISTING', match_status = 'SELECTED' where request_id = l_id;
        submit(l_id);
        xxfnd_vpd_pkg.end_trusted;
        return l_id;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end start_review;

    function history_rows(p_request_id in number) return xxcmp_history_tab pipelined is
        l_req    xxcmp_requests%rowtype;
        l_path   varchar2(100);
        l_owners varchar2(1000);
        l_attrs  apex_t_varchar2;
    begin
        if p_request_id is null then
            return;
        end if;
        l_req  := get_request(p_request_id);
        l_path := nvl(l_req.approval_path_name, path_for(p_request_id));
        l_attrs := attributes(l_req);
        for h in (select null as step_no, 'Request' as step_name, null as assigned_to, 'Submitted' as action,
                         l_req.requester_user_name as action_by, cast(l_req.submitted_date as timestamp) as action_date,
                         null as comments
                    from dual where l_req.submitted_date is not null
                  union all
                  -- release 73: approval workflow switched off for the process
                  select null, 'Approval', null, xxfnd_workflow_pkg.c_auto_approved, 'System',
                         cast(l_req.auto_approved_date as timestamp), null
                    from dual where l_req.auto_approved_date is not null
                  union all
                  select null, regexp_substr(t.subject, '^[^:]+'), t.actual_owner,
                         case h.event_type_code when 'COMPLETE'     then nvl(h.outcome, 'Completed')
                                                when 'REQUEST_INFO' then 'Information requested'
                                                when 'SUBMIT_INFO'  then 'Information submitted'
                                                when 'CLAIM'        then 'Claimed'
                                                when 'DELEGATE'     then 'Delegated'
                                                when 'CANCEL'       then 'Ended' end,
                         h.event_creator, cast(h.event_timestamp as timestamp),
                         (select substr(listagg(c.text, ' / ') within group (order by c.created_on), 1, 4000)
                            from apex_task_comments c
                           where c.task_id = h.task_id and upper(c.created_by) = upper(h.event_creator)
                             and c.created_on between h.event_timestamp - interval '2' minute and h.event_timestamp + interval '5' second)
                    from apex_task_history h
                    join apex_tasks t on t.task_id = h.task_id
                   where t.detail_pk = to_char(p_request_id)
                     and t.task_def_static_id in ('DOC_CHECKLIST_REVIEW', 'COUNTERPARTY_MATCH')
                     and h.event_type_code in ('COMPLETE', 'REQUEST_INFO', 'SUBMIT_INFO', 'CLAIM', 'DELEGATE')
                  union all
                  -- release 73: questions returned to the requester by an approver who is the requester (return_for_info)
                  select null, 'Approval', null, 'Information requested', r.created_by, cast(r.creation_date as timestamp),
                         r.description
                    from xxfnd_rfis r
                   where r.entity_name = 'XXCMP_REQUESTS' and r.pk1_value = to_char(p_request_id)
                  union all
                  select null, 'Request', null, 'Information submitted', r.recipient_user_name,
                         cast(coalesce(r.responded_date, r.resolved_date) as timestamp), null
                    from xxfnd_rfis r
                   where r.entity_name = 'XXCMP_REQUESTS' and r.pk1_value = to_char(p_request_id)
                     and coalesce(r.responded_date, r.resolved_date) is not null and r.rfi_status <> 'CANCELLED'
                  union all
                  select null, 'Request', null, 'Withdrawn', l_req.requester_user_name, cast(w.last_updated_on as timestamp), null
                    from apex_workflows w
                   where w.detail_pk = to_char(p_request_id) and w.state_code = 'TERMINATED'
                     and not (l_req.request_status = 'CANCELLED'
                              and abs(cast(w.last_updated_on as date) - cast(l_req.completed_date as date)) < 1 / 1440)
                     and not exists (select 1 from xxfnd_rfis r
                                      where r.entity_name = 'XXCMP_REQUESTS' and r.pk1_value = to_char(p_request_id)
                                        and abs(cast(w.last_updated_on as date) - cast(r.creation_date as date)) < 1 / 1440)
                  union all
                  select null, 'Request', null, 'Cancelled', l_req.last_updated_by, cast(l_req.completed_date as timestamp), l_req.match_note
                    from dual where l_req.request_status = 'CANCELLED' and l_req.completed_date is not null
                   order by 6) loop
            pipe row (xxcmp_history_row(h.step_no, h.step_name, h.assigned_to, h.action, h.action_by, h.action_date, h.comments));
        end loop;
        if l_req.request_status in ('DRAFT', 'IN_PROGRESS', 'INFO_NEEDED') then
            for p in (select * from table(xxfnd_approval_rule_pkg.steps(c_type, to_char(p_request_id), l_attrs))
                       where step_state in ('EXPECTED', 'CURRENT', 'WAITING')
                       order by position) loop
                l_owners := null;
                if p.step_state = 'CURRENT' then
                    select max(coalesce(t.actual_owner,
                                        (select listagg(pp.participant, ', ') within group (order by pp.participant)
                                           from apex_task_participants pp
                                          where pp.task_id = t.task_id and pp.participant_type = 'POTENTIAL_OWNER')))
                      into l_owners
                      from apex_tasks t
                     where t.detail_pk = to_char(p_request_id) and t.task_def_static_id = 'DOC_CHECKLIST_REVIEW'
                       and t.state_code in ('ASSIGNED', 'UNASSIGNED', 'INFO_REQUESTED');
                end if;
                pipe row (xxcmp_history_row(p.position, p.step_name,
                              nvl(l_owners, xxfnd_approval_rule_pkg.approver_label(p.approver_type, p.role_code, p.user_name)),
                              case when p.step_state = 'EXPECTED' then 'Expected'
                                   when p.step_state = 'CURRENT' and l_req.request_status = 'INFO_NEEDED' then 'Information needed'
                                   when p.step_state = 'CURRENT' then 'Pending'
                                   else 'Waiting' end,
                              null, null, null));
            end loop;
        end if;
        return;
    end history_rows;

    -- release 90 (page 206): one place for the decision buttons' check (it was repeated six times on the page)
    function can_decide(p_task_id in number) return varchar2 is
    begin
        -- the document checklist task of the request (the page also opens from the Counterparty Match task)
        for t in (select 1 from apex_tasks where task_id = p_task_id and task_def_static_id = 'DOC_CHECKLIST_REVIEW') loop
            return case when apex_human_task.is_allowed(p_task_id => p_task_id, p_operation => apex_human_task.c_task_op_approve)
                          or apex_human_task.is_allowed(p_task_id => p_task_id, p_operation => apex_human_task.c_task_op_claim)
                        then 'Y' else 'N' end;
        end loop;
        return 'N';
    end can_decide;

    function can_add_approver(p_request_id in number, p_task_id in number) return varchar2 is
        l_open pls_integer;
    begin
        -- release 74: the current approver adds an approver after them (Approval Setup, ad-hoc)
        if xxfnd_approval_rule_pkg.is_started(c_type, to_char(p_request_id)) = 'N' then
            return 'N';
        end if;
        select count(*) into l_open from apex_tasks
         where task_id = p_task_id and task_def_static_id = 'DOC_CHECKLIST_REVIEW' and state_code in ('ASSIGNED', 'UNASSIGNED');
        return case when l_open > 0 then can_decide(p_task_id) else 'N' end;
    end can_add_approver;

end xxcmp_request_pkg;
/
