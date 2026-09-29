-- Create Request wizard, steps 1-2 (pages 201, 202): XXCMP_REQUEST_PKG and starter question sections.
-- Run as the application's parsing schema. Idempotent: create or replace; sections only where none is set.
set define off

create or replace package xxcmp_request_pkg authid definer as

    -- Requester questionnaire for a party type (PERSON -> INDIVIDUAL, ORGANIZATION -> CORPORATE).
    function questionnaire_for(p_party_type in varchar2) return varchar2;

    -- New DRAFT request with one empty answer row per question of its questionnaire.
    function create_request(p_party_type            in varchar2,
                            p_party_name            in varchar2,
                            p_registration_number   in varchar2 default null,
                            p_jurisdiction          in varchar2 default null,
                            p_entity_type           in varchar2 default null,
                            p_date_of_birth         in date     default null,
                            p_nationality           in varchar2 default null,
                            p_requesting_department in varchar2 default null,
                            p_justification         in varchar2 default null,
                            p_request_type          in varchar2 default 'NEW_ONBOARDING',
                            p_trigger_source        in varchar2 default 'MANUAL',
                            p_parent_request_id     in number   default null,
                            p_parent_case_id        in number   default null,
                            p_party_id              in number   default null) return number;

    -- Counterparty rules by type (null = acceptable). Organisation: registration number, entity type and
    -- country of incorporation. Individual: date of birth (not in the future), nationality, country of residence.
    function counterparty_error(p_party_type          in varchar2,
                                p_party_name          in varchar2,
                                p_registration_number in varchar2,
                                p_entity_type         in varchar2,
                                p_jurisdiction        in varchar2,
                                p_date_of_birth       in date,
                                p_nationality         in varchar2) return varchar2;

    -- Wizard step 1: creates the DRAFT request (p_request_id null) or updates it. Fields that do not apply to
    -- the type are cleared; a change of type replaces the questionnaire and its (unanswered) answer rows.
    procedure save_counterparty(p_request_id            in out number,
                                p_party_type            in varchar2,
                                p_party_name            in varchar2,
                                p_registration_number   in varchar2,
                                p_entity_type           in varchar2,
                                p_jurisdiction          in varchar2,
                                p_date_of_birth         in date,
                                p_nationality           in varchar2,
                                p_requesting_department in varchar2,
                                p_justification         in varchar2);

    -- Wizard step 2: the questionnaire as a form. Questions grouped by section (translated), each with its
    -- answer control (Yes/No and single choice: radio buttons; text, number, date: an input) and the saved answer.
    -- kyc-app.js (kycQuestionnaire.bind) copies the answers into a JSON item before submit:
    --   [{"q": question_id, "o": answer_option_id, "t": "text answer"}, ...]
    function questionnaire_html(p_request_id in number, p_respondent in varchar2 default 'REQUESTER') return clob;
    -- Required questions without an answer in P_ANSWERS (null = all answered).
    function answers_error(p_request_id in number, p_answers in clob) return varchar2;
    -- Saves the answers of a DRAFT request; only its own questions and their approved options are accepted.
    procedure save_answers(p_request_id in number, p_answers in clob);

    -- Why the request cannot be submitted yet (null = it can).
    function submit_error(p_request_id in number) return varchar2;
    -- Submits the request and starts the KYC_REQUEST workflow.
    procedure submit(p_request_id in number);

    -- Workflow steps (KYC_REQUEST). Run as system steps, not limited by data security.
    procedure evaluate(p_request_id in number);
    function outcome(p_request_id in number) return varchar2;
    procedure close_without_case(p_request_id in number);
    procedure create_case(p_request_id in number);
    procedure reject(p_request_id in number);

    -- Requester's three-stage view: Draft, Submitted, Processing, In Progress, Completed, Rejected.
    function stage(p_request_id in number) return varchar2;

    -- New review request for the party of a case (monitoring): submitted at once, always to Compliance.
    function start_review(p_case_id in number, p_request_type in varchar2, p_trigger_source in varchar2,
                          p_justification in varchar2) return number;

end xxcmp_request_pkg;
/

create or replace package body xxcmp_request_pkg as

    -- Numeric KYC parameter maintained by administrators (lookup KYC_PARAMETER, value in TAG).
    function param(p_code in varchar2, p_default in number) return number is
        l_value number;
    begin
        select max(to_number(tag default null on conversion error)) into l_value from xxfnd_lookup_values
         where lookup_type = 'KYC_PARAMETER' and lookup_code = p_code and enabled_flag = 'Y';
        return nvl(l_value, p_default);
    end param;

    function questionnaire_for(p_party_type in varchar2) return varchar2 is
    begin
        return case p_party_type when 'PERSON' then 'INDIVIDUAL' else 'CORPORATE' end;
    end questionnaire_for;

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

    function create_request(p_party_type            in varchar2,
                            p_party_name            in varchar2,
                            p_registration_number   in varchar2 default null,
                            p_jurisdiction          in varchar2 default null,
                            p_entity_type           in varchar2 default null,
                            p_date_of_birth         in date     default null,
                            p_nationality           in varchar2 default null,
                            p_requesting_department in varchar2 default null,
                            p_justification         in varchar2 default null,
                            p_request_type          in varchar2 default 'NEW_ONBOARDING',
                            p_trigger_source        in varchar2 default 'MANUAL',
                            p_parent_request_id     in number   default null,
                            p_parent_case_id        in number   default null,
                            p_party_id              in number   default null) return number is
        l_id  number;
        l_qnr varchar2(30) := case when p_request_type = 'NEW_ONBOARDING' then questionnaire_for(p_party_type) end;
    begin
        insert into xxcmp_requests (request_number, request_type, trigger_source, parent_request_id, parent_case_id,
                                    party_id, party_type, party_name, registration_number, jurisdiction, entity_type,
                                    date_of_birth, nationality, requesting_department, requester_user_name,
                                    questionnaire_code, justification)
        values ('REQ-' || lpad(xxcmp_request_number_s.nextval, 6, '0'), p_request_type, p_trigger_source,
                p_parent_request_id, p_parent_case_id, p_party_id, p_party_type, p_party_name, p_registration_number,
                p_jurisdiction, p_entity_type, p_date_of_birth, p_nationality, p_requesting_department,
                xxfnd_util_pkg.current_user, l_qnr, p_justification)
        returning request_id into l_id;
        if l_qnr is not null then
            add_answer_rows(l_id, null, l_qnr, 'REQUESTER');
        end if;
        return l_id;
    end create_request;

    function counterparty_error(p_party_type          in varchar2,
                                p_party_name          in varchar2,
                                p_registration_number in varchar2,
                                p_entity_type         in varchar2,
                                p_jurisdiction        in varchar2,
                                p_date_of_birth       in date,
                                p_nationality         in varchar2) return varchar2 is
    begin
        if trim(p_party_name) is null then
            return 'Enter the name.';
        elsif trim(p_jurisdiction) is null then
            return 'Choose the country.';
        elsif p_party_type = 'ORGANIZATION' then
            if trim(p_registration_number) is null then
                return 'Enter the registration number of the organisation.';
            elsif trim(p_entity_type) is null then
                return 'Choose the entity type of the organisation.';
            end if;
        elsif p_party_type = 'PERSON' then
            if p_date_of_birth is null then
                return 'Enter the date of birth.';
            elsif p_date_of_birth > trunc(sysdate) then
                return 'The date of birth cannot be in the future.';
            elsif trim(p_nationality) is null then
                return 'Choose the nationality.';
            end if;
        else
            return 'Choose the counterparty type.';
        end if;
        return null;
    end counterparty_error;

    procedure save_counterparty(p_request_id            in out number,
                                p_party_type            in varchar2,
                                p_party_name            in varchar2,
                                p_registration_number   in varchar2,
                                p_entity_type           in varchar2,
                                p_jurisdiction          in varchar2,
                                p_date_of_birth         in date,
                                p_nationality           in varchar2,
                                p_requesting_department in varchar2,
                                p_justification         in varchar2) is
        l_org   boolean := p_party_type = 'ORGANIZATION';
        l_error varchar2(4000) := counterparty_error(p_party_type, p_party_name, p_registration_number, p_entity_type,
                                                     p_jurisdiction, p_date_of_birth, p_nationality);
        l_old   xxcmp_requests%rowtype;
        l_qnr   varchar2(30) := questionnaire_for(p_party_type);
    begin
        if l_error is not null then
            raise_application_error(-20611, l_error);
        end if;
        if p_request_id is null then
            p_request_id := create_request(
                p_party_type            => p_party_type,
                p_party_name            => trim(p_party_name),
                p_registration_number   => case when l_org then trim(p_registration_number) end,
                p_jurisdiction          => p_jurisdiction,
                p_entity_type           => case when l_org then p_entity_type end,
                p_date_of_birth         => case when not l_org then p_date_of_birth end,
                p_nationality           => case when not l_org then p_nationality end,
                p_requesting_department => p_requesting_department,
                p_justification         => p_justification);
            return;
        end if;
        select * into l_old from xxcmp_requests where request_id = p_request_id for update;
        if l_old.request_status <> 'DRAFT' then
            raise_application_error(-20612, 'Request ' || l_old.request_number || ' has been submitted and can no longer be changed.');
        end if;
        update xxcmp_requests
           set party_type            = p_party_type,
               party_name            = trim(p_party_name),
               registration_number   = case when l_org then trim(p_registration_number) end,
               entity_type           = case when l_org then p_entity_type end,
               jurisdiction          = p_jurisdiction,
               date_of_birth         = case when not l_org then p_date_of_birth end,
               nationality           = case when not l_org then p_nationality end,
               requesting_department = p_requesting_department,
               justification         = p_justification,
               questionnaire_code    = l_qnr
         where request_id = p_request_id;
        -- another type answers another questionnaire
        if nvl(l_old.questionnaire_code, '#') <> l_qnr then
            delete from xxcmp_request_answers where request_id = p_request_id and respondent_type = 'REQUESTER';
            add_answer_rows(p_request_id, null, l_qnr, 'REQUESTER');
        end if;
    end save_counterparty;

    function questionnaire_html(p_request_id in number, p_respondent in varchar2 default 'REQUESTER') return clob is
        l_html    clob;
        l_section varchar2(240) := chr(0);
        l_lang    varchar2(10) := xxfnd_util_pkg.current_lang;
        l_id      varchar2(100);

        procedure add(p_text in varchar2) is
        begin
            dbms_lob.writeappend(l_html, length(p_text), p_text);
        end add;
    begin
        dbms_lob.createtemporary(l_html, true);
        add('<div class="kyc-questionnaire">');
        for q in (select a.question_id, a.answer_option_id, a.answer_text, qu.answer_type, qu.required_flag,
                         nvl(tl.question_text, qu.question_text) as question_text,
                         nvl(nvl(tl.section_name, qu.section_name), 'General') as section_name
                    from xxcmp_request_answers a
                    join xxcmp_questions qu on qu.question_id = a.question_id
                    left join xxcmp_questions_tl tl on tl.question_id = qu.question_id and tl.language_code = l_lang
                   where a.request_id = p_request_id
                     and a.respondent_type = p_respondent
                   -- a section's questions stay together, in the order of its first question
                   order by min(qu.display_sequence) over (partition by nvl(nvl(tl.section_name, qu.section_name), 'General')),
                            qu.display_sequence, qu.question_id) loop
            if q.section_name <> l_section then
                if l_section <> chr(0) then
                    add('</div>');
                end if;
                l_section := q.section_name;
                add('<div class="kyc-section"><h3 class="kyc-section-title">' || apex_escape.html(q.section_name) || '</h3>');
            end if;
            l_id := 'kycq_' || q.question_id;
            add('<fieldset class="kyc-q" data-kyc-q="' || q.question_id || '" data-kyc-type="' || q.answer_type || '">'
                || '<legend class="kyc-q-text">' || apex_escape.html(q.question_text)
                || case when q.required_flag = 'Y' then ' <span class="kyc-q-required" title="Required">*</span>' end
                || '</legend>');
            if q.answer_type in ('YES_NO', 'SINGLE_SELECT', 'MULTI_SELECT') then
                add('<div class="kyc-q-options" role="radiogroup">');
                for o in (select answer_option_id, answer_label
                            from xxcmp_answer_options
                           where question_id = q.question_id and approval_status = 'APPROVED' and enabled_flag = 'Y'
                           order by display_sequence, answer_option_id) loop
                    add('<label class="kyc-q-option"><input type="radio" name="' || l_id || '" value="' || o.answer_option_id || '"'
                        || case when o.answer_option_id = q.answer_option_id then ' checked' end
                        || '> <span>' || apex_escape.html(o.answer_label) || '</span></label>');
                end loop;
                add('</div>');
            elsif q.answer_type = 'TEXT' then
                add('<textarea class="textarea apex-item-textarea kyc-q-input" rows="3" maxlength="4000" aria-label="'
                    || apex_escape.html_attribute(q.question_text) || '">' || apex_escape.html(q.answer_text) || '</textarea>');
            else
                add('<input class="text_field apex-item-text kyc-q-input" type="'
                    || case q.answer_type when 'DATE' then 'date' else 'text" inputmode="decimal' end
                    || '" value="' || apex_escape.html_attribute(q.answer_text) || '" aria-label="'
                    || apex_escape.html_attribute(q.question_text) || '">');
            end if;
            add('</fieldset>');
        end loop;
        if l_section <> chr(0) then
            add('</div>');
        else
            add('<p class="kyc-q-empty">No questions are configured for this counterparty type.</p>');
        end if;
        add('</div>');
        return l_html;
    end questionnaire_html;

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
        if l_status <> 'DRAFT' then
            raise_application_error(-20613, 'The request has been submitted; its answers can no longer be changed.');
        end if;
        for j in (select q, o, t from json_table(nvl(p_answers, '[]'), '$[*]'
                          columns (q number path '$.q', o number path '$.o', t varchar2(4000) path '$.t'))) loop
            begin
                select qu.answer_type into l_type
                  from xxcmp_request_answers a join xxcmp_questions qu on qu.question_id = a.question_id
                 where a.request_id = p_request_id and a.respondent_type = 'REQUESTER' and a.question_id = j.q;
            exception
                when no_data_found then
                    raise_application_error(-20614, 'Question ' || j.q || ' does not belong to this request.');
            end;
            l_option := null;
            l_text   := null;
            if l_type in ('YES_NO', 'SINGLE_SELECT', 'MULTI_SELECT') then
                if j.o is not null then
                    select max(answer_option_id) into l_option
                      from xxcmp_answer_options
                     where answer_option_id = j.o and question_id = j.q and approval_status = 'APPROVED' and enabled_flag = 'Y';
                    if l_option is null then
                        raise_application_error(-20615, 'Answer ' || j.o || ' is not an option of question ' || j.q || '.');
                    end if;
                end if;
            elsif l_type = 'NUMBER' and trim(j.t) is not null
                  and validate_conversion(trim(j.t) as number) = 0 then
                raise_application_error(-20616, 'Enter a number for: ' || j.t);
            else
                l_text := trim(j.t);
            end if;
            update xxcmp_request_answers
               set answer_option_id = l_option,
                   answer_text      = case when l_type in ('YES_NO', 'SINGLE_SELECT', 'MULTI_SELECT') then answer_text else l_text end
             where request_id = p_request_id and respondent_type = 'REQUESTER' and question_id = j.q;
        end loop;
    end save_answers;

    function submit_error(p_request_id in number) return varchar2 is
        l_req     xxcmp_requests%rowtype;
        l_missing pls_integer;
    begin
        select * into l_req from xxcmp_requests where request_id = p_request_id;
        if l_req.request_status <> 'DRAFT' then
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
        return null;
    end submit_error;

    procedure submit(p_request_id in number) is
        l_error varchar2(4000) := submit_error(p_request_id);
        l_wf    number;
    begin
        if l_error is not null then
            raise_application_error(-20601, l_error);
        end if;
        update xxcmp_requests set request_status = 'SUBMITTED', submitted_date = systimestamp
         where request_id = p_request_id;
        l_wf := apex_workflow.start_workflow(
                    p_application_id => v('APP_ID'),
                    p_static_id      => 'KYC_REQUEST',
                    p_detail_pk      => to_char(p_request_id));
        update xxcmp_requests set workflow_id = l_wf where request_id = p_request_id;
    end submit;

    -- Links the request to its party: the certain match, or a new party from the request.
    procedure link_party(p_req in out xxcmp_requests%rowtype) is
    begin
        if p_req.party_id is null then
            p_req.party_id := xxcmp_kyc_pkg.exact_party_match(p_req.party_type, p_req.party_name, p_req.registration_number,
                                                              p_req.jurisdiction, p_req.date_of_birth);
        end if;
        if p_req.party_id is null then
            insert into xxcmp_parties (party_type, party_name, registration_number, jurisdiction, entity_type,
                                       date_of_birth, nationality, data_provenance)
            values (p_req.party_type, p_req.party_name, p_req.registration_number, p_req.jurisdiction, p_req.entity_type,
                    p_req.date_of_birth, p_req.nationality, 'SELF_DECLARED')
            returning party_id into p_req.party_id;
        end if;
        update xxcmp_requests set party_id = p_req.party_id where request_id = p_req.request_id;
    end link_party;

    procedure evaluate(p_request_id in number) is
        l_req      xxcmp_requests%rowtype;
        l_score    number;
        l_critical pls_integer;
        l_waiver   pls_integer;
        l_low      number;
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
            select nvl(sum(a.risk_points), 0),
                   count(case when o.critical_flag = 'Y' then 1 end),
                   count(case when q.gate_question_flag = 'Y' and o.waiver_qualifying_flag = 'Y' then 1 end)
              into l_score, l_critical, l_waiver
              from xxcmp_request_answers a
              join xxcmp_questions q on q.question_id = a.question_id
              left join xxcmp_answer_options o on o.answer_option_id = a.answer_option_id
             where a.request_id = p_request_id and a.respondent_type = 'REQUESTER';
            select low_risk_max_score into l_low from xxcmp_questionnaires where questionnaire_code = l_req.questionnaire_code;
            l_outcome := case when l_critical > 0 then 'ASSIGNED'
                              when l_waiver > 0 then 'NOT_REQUIRED'
                              when l_low is not null and l_score <= l_low then 'AUTO_APPROVED'
                              else 'ASSIGNED' end;
            update xxcmp_requests set intake_score = l_score, intake_critical_flag = case when l_critical > 0 then 'Y' else 'N' end
             where request_id = p_request_id;
        end if;
        update xxcmp_requests
           set intake_outcome = l_outcome,
               request_status = case when l_outcome = 'ASSIGNED' then 'IN_PROGRESS' else request_status end
         where request_id = p_request_id;
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end evaluate;

    function outcome(p_request_id in number) return varchar2 is
        l_outcome varchar2(30);
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select intake_outcome into l_outcome from xxcmp_requests where request_id = p_request_id;
        xxfnd_vpd_pkg.end_trusted;
        return l_outcome;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end outcome;

    procedure close_without_case(p_request_id in number) is
    begin
        xxfnd_vpd_pkg.begin_trusted;
        update xxcmp_requests set request_status = 'COMPLETED', completed_date = systimestamp
         where request_id = p_request_id;
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end close_without_case;

    procedure create_case(p_request_id in number) is
        l_case number;
    begin
        l_case := xxcmp_case_pkg.create_case(p_request_id);
    end create_case;

    procedure reject(p_request_id in number) is
    begin
        xxfnd_vpd_pkg.begin_trusted;
        update xxcmp_requests set request_status = 'REJECTED', completed_date = systimestamp
         where request_id = p_request_id;
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end reject;

    function stage(p_request_id in number) return varchar2 is
        l_status  varchar2(30);
        l_outcome varchar2(30);
    begin
        select request_status, intake_outcome into l_status, l_outcome from xxcmp_requests where request_id = p_request_id;
        return case
                   when l_status = 'DRAFT'                                  then 'Draft'
                   when l_status = 'SUBMITTED' and l_outcome is null        then 'Processing'
                   when l_status in ('SUBMITTED','IN_PROGRESS')            then 'In Progress'
                   when l_status = 'COMPLETED' and l_outcome = 'NOT_REQUIRED' then 'Completed - KYC not required'
                   when l_status = 'COMPLETED' and l_outcome = 'AUTO_APPROVED' then 'Completed - approved'
                   when l_status = 'COMPLETED'                              then 'Completed'
                   when l_status = 'REJECTED'                               then 'Rejected'
                   else initcap(l_status)
               end;
    end stage;

    function start_review(p_case_id in number, p_request_type in varchar2, p_trigger_source in varchar2,
                          p_justification in varchar2) return number is
        l_id    number;
        l_party xxcmp_parties%rowtype;
        l_case  xxcmp_cases%rowtype;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select * into l_case from xxcmp_cases where case_id = p_case_id;
        select * into l_party from xxcmp_parties where party_id = l_case.party_id;
        l_id := create_request(p_party_type          => l_party.party_type,
                               p_party_name          => l_party.party_name,
                               p_registration_number => l_party.registration_number,
                               p_jurisdiction        => l_party.jurisdiction,
                               p_entity_type         => l_party.entity_type,
                               p_date_of_birth       => l_party.date_of_birth,
                               p_nationality         => l_party.nationality,
                               p_justification       => p_justification,
                               p_request_type        => p_request_type,
                               p_trigger_source      => p_trigger_source,
                               p_parent_request_id   => l_case.request_id,
                               p_parent_case_id      => p_case_id,
                               p_party_id            => l_case.party_id);
        submit(l_id);
        xxfnd_vpd_pkg.end_trusted;
        return l_id;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end start_review;

end xxcmp_request_pkg;
/

begin
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
    commit;
end;
/

select object_name, object_type, status from user_objects where object_name = 'XXCMP_REQUEST_PKG';
select questionnaire_code, display_sequence, section_name from xxcmp_questions
 where questionnaire_code in ('CORPORATE', 'INDIVIDUAL') order by 1, 2;
