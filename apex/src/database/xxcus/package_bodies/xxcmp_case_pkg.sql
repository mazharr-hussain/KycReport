create or replace package body xxcus.xxcmp_case_pkg as

    -- Numeric KYC parameter maintained by administrators (lookup KYC_PARAMETER, value in TAG).
    function param (
        p_code    in varchar2,
        p_default in number
    ) return number is
        l_value number;
    begin
        select
            max(to_number(tag default null on conversion error))
        into l_value
        from
            xxfnd_lookup_values
        where
                lookup_type = 'KYC_PARAMETER'
            and lookup_code = p_code
            and enabled_flag = 'Y';

        return nvl(l_value, p_default);
    end param;

    function get_case (
        p_case_id in number
    ) return xxcmp_cases%rowtype is
        l_case xxcmp_cases%rowtype;
    begin
        select
            *
        into l_case
        from
            xxcmp_cases
        where
            case_id = p_case_id;

        return l_case;
    end get_case;

    function create_case (
        p_request_id  in number,
        p_assigned_to in varchar2 default null
    ) return number is

        l_req xxcmp_requests%rowtype;
        l_id  number;
        l_wf  number;
        l_sla number := param('CASE_SLA_DAYS', 10);   -- private function: not callable inside SQL
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select
            *
        into l_req
        from
            xxcmp_requests
        where
            request_id = p_request_id;

        insert into xxcmp_cases (
            case_number,
            request_id,
            party_id,
            parent_case_id,
            assigned_to,
            sla_due_date
        ) values
            ( 'CASE-'
              || lpad(xxcmp_case_number_s.nextval, 6, '0'),
              p_request_id,
              l_req.party_id,
              l_req.parent_case_id,
              upper(p_assigned_to),
              trunc(sysdate) + l_sla )
        returning case_id into l_id;
        -- the officer's investigation questionnaire
        insert into xxcmp_request_answers (
            request_id,
            case_id,
            respondent_type,
            question_id
        )
            select
                p_request_id,
                l_id,
                'OFFICER',
                q.question_id
            from
                     xxcmp_questions q
                join xxcmp_questionnaires qn on qn.questionnaire_code = q.questionnaire_code
            where
                    qn.audience = 'OFFICER'
                and qn.enabled_flag = 'Y'
                and q.enabled_flag = 'Y'
                and not exists (
                    select
                        1
                    from
                        xxcmp_request_answers a
                    where
                            a.request_id = p_request_id
                        and a.respondent_type = 'OFFICER'
                        and a.question_id = q.question_id
                );

        update xxcmp_requests
        set
            request_status = 'IN_PROGRESS'
        where
            request_id = p_request_id;

        l_wf := apex_workflow.start_workflow(
            p_application_id => v('APP_ID'),
            p_static_id      => 'KYC_CASE',
                    -- the requester (or whoever opened a manual case) initiates; separation of duties excludes them
            p_initiator      => coalesce(l_req.requester_user_name,
                                    nullif(
                                           v('APP_USER'),
                                           'nobody'
                                       )),
            p_detail_pk      => to_char(l_id)
        );

        update xxcmp_cases
        set
            workflow_id = l_wf
        where
            case_id = l_id;

        xxfnd_vpd_pkg.end_trusted;
        return l_id;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end create_case;

    function create_manual_case (
        p_party_id      in number,
        p_justification in varchar2
    ) return number is
        l_party xxcmp_parties%rowtype;
        l_req   number;
    begin
        select
            *
        into l_party
        from
            xxcmp_parties
        where
            party_id = p_party_id;

        l_req := xxcmp_request_pkg.create_request(
            p_party_type          => l_party.party_type,
            p_party_name          => l_party.party_name,
            p_registration_number => l_party.registration_number,
            p_jurisdiction        => l_party.jurisdiction,
            p_entity_type         => l_party.entity_type,
            p_date_of_birth       => l_party.date_of_birth,
            p_nationality         => l_party.nationality,
            p_justification       => p_justification,
            p_request_type        => 'EVENT_TRIGGERED_REVIEW',
            p_trigger_source      => 'MANUAL',
            p_party_id            => p_party_id
        );

        update xxcmp_requests
        set
            request_status = 'IN_PROGRESS',
            intake_outcome = 'ASSIGNED',
            submitted_date = systimestamp
        where
            request_id = l_req;

        return create_case(l_req, xxfnd_util_pkg.current_user);
    end create_manual_case;

    procedure assign (
        p_case_id   in number,
        p_user_name in varchar2
    ) is
    begin
        update xxcmp_cases
        set
            assigned_to = upper(p_user_name)
        where
                case_id = p_case_id
            and case_status = 'INVESTIGATION';

        if sql%rowcount = 0 then
            raise_application_error(-20611, 'Only a case under investigation can be reassigned.');
        end if;
    end assign;

    function investigation_owners (
        p_case_id in number
    ) return varchar2 is
        l_case xxcmp_cases%rowtype;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        l_case := get_case(p_case_id);
        xxfnd_vpd_pkg.end_trusted;
        return nvl(l_case.assigned_to,
                   xxfnd_task_pkg.users_with_privilege('CASES', 'MANAGE'));
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end investigation_owners;

    function matrix (
        p_case in xxcmp_cases%rowtype
    ) return xxcmp_approval_matrix%rowtype is
        l_row xxcmp_approval_matrix%rowtype;
    begin
        select
            *
        into l_row
        from
            xxcmp_approval_matrix
        where
            risk_tier = p_case.risk_tier;

        return l_row;
    exception
        when no_data_found then
            raise_application_error(-20612, 'The approval matrix has no row for risk tier '
                                            || p_case.risk_tier
                                            || '.');
    end matrix;

    function required_levels (
        p_case_id in number
    ) return number is

        l_case xxcmp_cases%rowtype := get_case(p_case_id);
        l_m    xxcmp_approval_matrix%rowtype := matrix(l_case);
    begin
        return
            case
                when l_case.enhanced_kyc_flag = 'Y' then
                    greatest(l_m.required_levels, 2)
                else
                    l_m.required_levels
            end;
    end required_levels;

    function level_role (
        p_case_id in number,
        p_level   in number
    ) return varchar2 is
        l_m xxcmp_approval_matrix%rowtype := matrix(get_case(p_case_id));
    begin
        return
            case p_level
                when 1 then
                    l_m.level1_role_code
                else
                    nvl(l_m.level2_role_code, 'HEAD_OF_COMPLIANCE')
            end;
    end level_role;

    function sar_gate (
        p_case_id in number
    ) return varchar2 is
        l_case xxcmp_cases%rowtype := get_case(p_case_id);
    begin
        return
            case
                when l_case.enhanced_kyc_flag = 'Y' then
                    'Y'
                else
                    nvl(matrix(l_case).sar_gate_flag,
                        'N')
            end;
    end sar_gate;

    function is_editable (
        p_case_id in number
    ) return varchar2 is
        l_status xxcmp_cases.case_status%type;
    begin
        select
            max(case_status)
        into l_status
        from
            xxcmp_cases
        where
            case_id = p_case_id;

        return
            case
                when l_status = 'INVESTIGATION'
                     and xxfnd_privilege_pkg.has_privilege('CASES', 'MANAGE') then
                    'Y'
                else
                    'N'
            end;

    end is_editable;

    -- Users who investigated or already decided this case, with the roles they acted under.
    function prior_actors (
        p_case_id in number
    ) return apex_t_varchar2 is
        l_list apex_t_varchar2;
    begin
        select
            upper(u)
        bulk collect
        into l_list
        from
            (
                select
                    assigned_to u
                from
                    xxcmp_cases
                where
                        case_id = p_case_id
                    and assigned_to is not null
                union
                select
                    actual_owner
                from
                    apex_tasks
                where
                        task_def_static_id = 'CASE_INVESTIGATION'
                    and detail_pk = to_char(p_case_id)
                    and actual_owner is not null
                union
                select
                    decided_by
                from
                    xxcmp_case_decisions
                where
                    case_id = p_case_id
            );

        return l_list;
    end prior_actors;

    function level_approvers (
        p_case_id in number
    ) return varchar2 is

        l_case  xxcmp_cases%rowtype;
        l_role  varchar2(30);
        l_prior apex_t_varchar2;
        l_out   varchar2(32767);
        l_roles apex_t_varchar2;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        l_case := get_case(p_case_id);
        l_role := level_role(p_case_id, l_case.current_level);
        l_prior := prior_actors(p_case_id);
        for u in (
            select distinct
                ur.user_name
            from
                xxfnd_user_roles_v ur
            where
                    ur.role_code = l_role
                and ur.active_flag = 'Y'
            order by
                ur.user_name
        ) loop
            -- four eyes: nobody decides a case they investigated or already decided,
            -- nor while holding a role that may never be combined with this one
            select
                role_code
            bulk collect
            into l_roles
            from
                xxcmp_case_decisions
            where
                    case_id = p_case_id
                and decided_by = u.user_name
                and role_code is not null;

            if
                u.user_name not member of l_prior
                and not xxfnd_security_pkg.sod_conflict(l_role, l_roles, u.user_name)
            then
                l_out := l_out
                         ||
                    case
                        when l_out is not null then
                            ','
                    end
                         || u.user_name;

            end if;

        end loop;

        xxfnd_vpd_pkg.end_trusted;
        return l_out;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end level_approvers;

    function submit_error (
        p_case_id in number
    ) return varchar2 is
        l_case  xxcmp_cases%rowtype := get_case(p_case_id);
        l_count pls_integer;
    begin
        if l_case.case_status <> 'INVESTIGATION' then
            return 'The case is not under investigation.';
        end if;
        if l_case.risk_tier is null then
            return 'Set the risk classification.';
        end if;
        select
            count(*)
        into l_count
        from
            xxcmp_screenings
        where
            case_id = p_case_id;

        if l_count = 0 then
            return 'Record at least one screening.';
        end if;
        select
            count(*)
        into l_count
        from
            xxcmp_rfis
        where
                entity_name = 'XXCMP_CASES'
            and pk1_value = to_char(p_case_id)
            and continue_other_work_flag = 'N'
            and rfi_status in ( 'WAITING_FOR_INFORMATION', 'ON_HOLD_PENDING' );

        if l_count > 0 then
            return 'A request for information that pauses the case is still open.';
        end if;
        if l_case.enhanced_kyc_flag = 'Y' then
            select
                count(*)
            into l_count
            from
                     xxcmp_request_answers a
                join xxcmp_questions q on q.question_id = a.question_id
            where
                    a.case_id = p_case_id
                and a.respondent_type = 'OFFICER'
                and q.section_name = 'Enhanced Due Diligence'
                and a.answer_option_id is null
                and a.answer_text is null;

            if l_count > 0 then
                return 'Enhanced KYC: answer the source of funds and source of wealth questions.';
            end if;
        end if;

        return null;
    end submit_error;

    procedure submit_for_approval (
        p_case_id in number
    ) is
        l_error varchar2(4000) := submit_error(p_case_id);
    begin
        if l_error is not null then
            raise_application_error(-20613, l_error);
        end if;
        -- completing the investigation task moves the KYC_CASE workflow on
        xxfnd_task_pkg.complete_open('CASE_INVESTIGATION',
                                     to_char(p_case_id));
    end submit_for_approval;

    function approval_error (
        p_case_id in number
    ) return varchar2 is
        l_case    xxcmp_cases%rowtype := get_case(p_case_id);
        l_missing pls_integer;
    begin
        if l_case.case_status <> 'PENDING_APPROVAL' then
            return 'The case is not waiting for approval.';
        end if;
        if
            sar_gate(p_case_id) = 'Y'
            and l_case.sar_required_flag is null
        then
            return 'Record whether a Suspicious Activity Report is required.';
        end if;

        if xxfnd_util_pkg.current_user member of prior_actors(p_case_id) then
            return 'You investigated or already decided this case.';
        end if;
        -- every mandatory document of the party must be verified in this case
        select
            count(*)
        into l_missing
        from
            table ( xxcmp_kyc_pkg.mandatory_categories('XXCMP_PARTIES',(
                select
                    jurisdiction
                from
                    xxcmp_parties
                where
                    party_id = l_case.party_id
            ),(
                select
                    entity_type
                from
                    xxcmp_parties
                where
                    party_id = l_case.party_id
            )) ) m
        where
            not exists (
                select
                    1
                from
                         xxfnd_attached_documents ad
                    join xxcmp_doc_verifications v on v.attached_document_id = ad.attached_document_id
                where
                        ad.entity_name = 'XXCMP_PARTIES'
                    and ad.pk1_value = to_char(l_case.party_id)
                    and ad.category_code = m.column_value
                    and v.case_id = p_case_id
                    and v.verification_status = 'VERIFIED'
            );

        if l_missing > 0 then
            return l_missing || ' mandatory document(s) are not verified for this case.';
        end if;
        return null;
    end approval_error;

    procedure record_decision (
        p_case_id  in number,
        p_outcome  in varchar2,
        p_comments in varchar2,
        p_task_id  in number
    ) is
        l_case xxcmp_cases%rowtype;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        l_case := get_case(p_case_id);
        insert into xxcmp_case_decisions (
            case_id,
            level_no,
            role_code,
            decided_by,
            outcome,
            comments,
            task_id
        ) values
            ( p_case_id,
              l_case.current_level,
              level_role(p_case_id, l_case.current_level),
              xxfnd_util_pkg.current_user,
              p_outcome,
              p_comments,
              p_task_id );

        if p_outcome = 'APPROVED' then
            update xxcmp_cases
            set
                current_level = current_level + 1
            where
                case_id = p_case_id;

        end if;

        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end record_decision;

    function next_review_date (
        p_case_id in number
    ) return date is
        l_case   xxcmp_cases%rowtype := get_case(p_case_id);
        l_months number;
    begin
        select
            max(to_number(tag default null on conversion error))
        into l_months
        from
            xxfnd_lookup_values
        where
                lookup_type = 'RISK_TIER'
            and lookup_code = l_case.risk_tier;

        if l_case.pep_flag = 'Y' then
            l_months := least(
                nvl(l_months, 12),
                param('PEP_REVIEW_MONTHS', 12)
            );

        end if;

        return add_months(
            trunc(sysdate),
            nvl(l_months, 12)
        );
    end next_review_date;

    procedure start_approval (
        p_case_id in number
    ) is
    begin
        xxfnd_vpd_pkg.begin_trusted;
        update xxcmp_cases
        set
            case_status = 'PENDING_APPROVAL',
            current_level = 1,
            investigation_completed_date = systimestamp
        where
            case_id = p_case_id;

        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end start_approval;

    function has_next_level (
        p_case_id in number
    ) return varchar2 is
        l_result varchar2(1);
    begin
        xxfnd_vpd_pkg.begin_trusted;
        l_result :=
            case
                when get_case(p_case_id).current_level <= required_levels(p_case_id) then
                    'Y'
                else
                    'N'
            end;

        xxfnd_vpd_pkg.end_trusted;
        return l_result;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end has_next_level;

    procedure close_case (
        p_case_id  in number,
        p_decision in varchar2
    ) is

        l_case xxcmp_cases%rowtype := get_case(p_case_id);
        -- computed first: the function reads XXCMP_CASES, which would be mutating inside the UPDATE
        l_next date :=
            case
                when p_decision = 'APPROVED' then
                    nvl(l_case.next_review_date,
                        next_review_date(p_case_id))
            end;
    begin
        update xxcmp_cases
        set
            case_status = p_decision,
            decision = p_decision,
            decision_date = systimestamp,
            next_review_date = l_next,
            closed_date = systimestamp
        where
            case_id = p_case_id;

        update xxcmp_requests
        set
            request_status = 'COMPLETED',
            completed_date = systimestamp
        where
            request_id = l_case.request_id;

    end close_case;

    procedure approve_case (
        p_case_id in number
    ) is
    begin
        xxfnd_vpd_pkg.begin_trusted;
        close_case(p_case_id, 'APPROVED');
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end approve_case;

    procedure reject_case (
        p_case_id in number
    ) is
    begin
        xxfnd_vpd_pkg.begin_trusted;
        close_case(p_case_id, 'REJECTED');
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end reject_case;

    procedure apply_screening (
        p_case_id in number
    ) is
        l_pep pls_integer;
        l_hit pls_integer;
    begin
        select
            count(
                case
                    when pep_flag = 'Y' then
                        1
                end
            ),
            count(
                case
                    when match_status = 'CONFIRMED_MATCH' then
                        1
                end
            )
        into
            l_pep,
            l_hit
        from
            xxcmp_screenings
        where
            case_id = p_case_id;

        update xxcmp_cases
        set
            pep_flag =
                case
                    when l_pep > 0 then
                        'Y'
                    else
                        pep_flag
                end,
            enhanced_kyc_flag =
                case
                    when l_pep > 0
                         or l_hit > 0 then
                        'Y'
                    else
                        enhanced_kyc_flag
                end
        where
                case_id = p_case_id
            and case_status = 'INVESTIGATION';

    end apply_screening;

end xxcmp_case_pkg;
/


-- sqlcl_snapshot {"hash":"78345438a1263b552c2b78fc27d2c5d18999c18a","type":"PACKAGE_BODY","name":"XXCMP_CASE_PKG","schemaName":"XXCUS","sxml":""}