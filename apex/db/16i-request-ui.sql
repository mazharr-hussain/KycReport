-- 16i Request UI (UI/UX standard, patch 14): data for the request screens - the request view (205), Review and Submit
-- (203) and the approval page (206). Release 74 (R11): no HTML here; the screens use standard reports.
-- Idempotent: create or replace only.

create or replace package xxcmp_request_ui_pkg authid definer as
    -- release 74 (R11): data only. The request's details for the standard Value Attribute Pairs report (pages 205 / 206):
    -- JSON array [{"group_name","seq","label","value","tone","url","user_name"}]; data security applies. The header card
    -- and the questionnaire answers are SQL in their regions (Global Page).
    function details_json(p_request_id in number) return clob;
    function case_header_html(p_case_id in number) return clob;

    -- Case summary grid (Summary, Review, and Risk when read only): case facts and the assessment; a missing
    -- required value is shown as a warning that links to its section.
    function case_summary_html(p_case_id in number, p_task_id in number default null) return clob;
end xxcmp_request_ui_pkg;
/

create or replace package body xxcmp_request_ui_pkg as

    function details_json(p_request_id in number) return clob is
        l_rows json_array_t := json_array_t();
        l_seq  pls_integer := 0;
        l_case xxcmp_cases%rowtype;

        procedure fld(p_group in varchar2, p_label in varchar2, p_value in varchar2, p_tone in varchar2 default null,
                      p_url in varchar2 default null, p_user in varchar2 default null) is
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
                l_row.put('user_name', p_user);
                l_rows.append(l_row);
            end if;
        end fld;
    begin
        for r in (select * from xxcmp_requests where request_id = p_request_id) loop     -- data security applies
            for c in (select * from xxcmp_cases where request_id = r.request_id) loop
                l_case := c;
            end loop;
            fld('Details', 'Request type', xxfnd_util_pkg.lookup_meaning('KYC_REQUEST_TYPE', r.request_type));
            fld('Details', 'Business relationship', xxfnd_util_pkg.lookup_meaning('BUSINESS_RELATIONSHIP', r.business_relationship));
            fld('Details', 'Requesting department', xxfnd_util_pkg.lookup_meaning('REQUESTING_DEPARTMENT', r.requesting_department));
            fld('Details', 'Requested by', xxfnd_ui_pkg.person_name(r.requester_user_name), null, null, r.requester_user_name);
            fld('Details', 'Submitted', to_char(r.submitted_date, 'DD-MON-YYYY HH24:MI'));
            fld('Details', 'Last action', to_char(r.last_action_date, 'DD-MON-YYYY HH24:MI'));
            fld('Details', 'Status', xxfnd_ui_pkg.status_label('REQUEST', r.request_status),
                xxfnd_ui_pkg.status_tone('REQUEST', r.request_status));
            if l_case.case_id is not null then
                fld('Details', 'Case', l_case.case_number, null,
                    case when xxfnd_privilege_pkg.has_privilege('CASES', 'VIEW')
                         then apex_page.get_url(p_page => 211, p_items => 'P211_CASE_ID', p_values => to_char(l_case.case_id),
                                                p_clear_cache => '211') end);
            end if;
            fld('Details', 'Business justification', r.justification);
            if r.match_status = 'MERGED' then
                fld('Details', 'Merge note', r.match_note);
            end if;
            if r.intake_score is not null then
                fld('Assessment', 'Intake score', to_char(r.intake_score),
                    case when r.intake_critical_flag = 'Y' then 'danger' else 'neutral' end);
            end if;
            fld('Assessment', 'Routed to', xxfnd_util_pkg.lookup_meaning('KYC_INTAKE_OUTCOME', r.intake_outcome));
            fld('Assessment', 'Reason', case when r.intake_critical_flag = 'Y' then 'Critical answer in the questionnaire' end);
            fld('Assessment', 'KYC required', xxcmp_request_pkg.kyc_required(r.request_id));
        end loop;
        return l_rows.to_clob;
    end details_json;

    function case_header_html(p_case_id in number) return clob is
        l_html  clob;
        l_sla   varchar2(20);
        l_owner varchar2(255);
        l_since timestamp with time zone;
    begin
        for c in (select c.*, p.party_name, xxfnd_util_pkg.lookup_meaning('JURISDICTION', p.jurisdiction) as country,
                         r.request_number, r.request_id as req_id
                    from xxcmp_cases c
                    join xxcmp_parties p on p.party_id = c.party_id
                    left join xxcmp_requests r on r.request_id = c.request_id
                   where c.case_id = p_case_id) loop     -- data security applies
            l_sla := case when c.closed_date is not null then null
                          when c.sla_due_date < trunc(sysdate) then 'danger'
                          when c.sla_due_date <= trunc(sysdate) + 2 then 'warning' else 'success' end;
            l_html := '<div class="kyc-hcard-top"><span class="kyc-hcard-title">'
                   || apex_escape.html(c.case_number || ' · ' || c.party_name) || '</span>'
                   || xxfnd_ui_pkg.status_badge('CASE', c.case_status)
                   || xxfnd_ui_pkg.status_badge('RISK', c.risk_tier)
                   || case when c.enhanced_kyc_flag = 'Y' then xxfnd_ui_pkg.badge('Enhanced KYC', 'warning') end
                   || case when c.pep_flag = 'Y' then xxfnd_ui_pkg.badge('PEP', 'danger') end
                   || case when l_sla is not null then
                          xxfnd_ui_pkg.badge(case l_sla when 'danger' then 'Overdue' when 'warning' then 'Due soon' else 'On time' end
                                             || ' · SLA ' || to_char(c.sla_due_date, 'DD-MON-YYYY'), l_sla) end
                   || '</div><div class="kyc-hcard-line">'
                   || apex_escape.html(ltrim(c.country || nvl2(c.business_relationship,
                                             ' · ' || xxfnd_util_pkg.lookup_meaning('BUSINESS_RELATIONSHIP', c.business_relationship), null), ' ·'))
                   || nvl2(c.request_number, ' · request ' || apex_escape.html(c.request_number), null)
                   || ' · assigned to ' || nvl(xxfnd_ui_pkg.person_html(c.assigned_to), '<span class="u-color-subtle">nobody</span>')
                   || '</div>';
            if c.case_status = 'PENDING_APPROVAL' then
                select max(actual_owner) keep (dense_rank last order by created_on), max(created_on)
                  into l_owner, l_since
                  from apex_tasks
                 where detail_pk = to_char(c.case_id) and task_def_static_id = 'CASE_APPROVAL'
                   and state_code in ('UNASSIGNED', 'ASSIGNED');
                l_html := l_html || '<div class="kyc-hcard-line">Pending approval (level ' || nvl(c.current_level, 1) || ')'
                       || case when l_owner is not null then ' with <b>' || xxfnd_ui_pkg.person_html(l_owner) || '</b>' end
                       || case when l_since is not null then ' since ' || to_char(l_since, 'DD-MON-YYYY HH24:MI') end
                       || ' · the case is read only</div>';
            elsif c.case_status = 'PENDING_INFORMATION' then
                l_html := l_html || '<div class="kyc-hcard-line">Pending information from the requester (level '
                       || nvl(c.current_level, 1) || ') · the case is read only</div>';
            end if;
        end loop;
        return l_html;
    end case_header_html;

    function case_summary_html(p_case_id in number, p_task_id in number default null) return clob is
        l_html clob;
        l_grp  clob;

        procedure fld(p_label in varchar2, p_value in varchar2, p_raw in boolean default false, p_full in boolean default false) is
        begin
            if p_value is not null then
                l_grp := l_grp || '<div class="kyc-f' || case when p_full then ' kyc-f--full' end || '"><span class="kyc-f-label">'
                      || apex_escape.html(p_label) || '</span><div class="kyc-f-value">'
                      || case when p_raw then p_value else apex_escape.html(p_value) end || '</div></div>';
            end if;
        end fld;

        procedure grp(p_title in varchar2) is
        begin
            if l_grp is not null then
                l_html := l_html || '<h3 class="kyc-group-title">' || apex_escape.html(p_title) || '</h3><div class="kyc-grid">' || l_grp || '</div>';
            end if;
            l_grp := null;
        end grp;

        function missing(p_text in varchar2, p_section in varchar2) return varchar2 is
        begin
            return '<span class="kyc-missing">' || apex_escape.html(p_text) || ' – <a href="'
                || apex_page.get_url(p_page => 211, p_items => 'P211_CASE_ID,P211_TASK_ID,P211_SECTION',
                                     p_values => p_case_id || ',' || p_task_id || ',' || p_section)
                || '">' || apex_escape.html(xxfnd_util_pkg.lookup_meaning('CASE_SECTION', p_section)) || '</a></span>';
        end missing;
    begin
        for c in (select c.*, r.request_number, xxfnd_util_pkg.lookup_meaning('KYC_REQUEST_TYPE', r.request_type) as request_type
                    from xxcmp_cases c
                    left join xxcmp_requests r on r.request_id = c.request_id
                   where c.case_id = p_case_id) loop
            fld('Request', c.request_number || nvl2(c.request_type, ' · ' || c.request_type, null));
            fld('Business relationship', xxfnd_util_pkg.lookup_meaning('BUSINESS_RELATIONSHIP', c.business_relationship));
            fld('Assigned to', nvl(xxfnd_ui_pkg.person_html(c.assigned_to), 'Nobody'), true);
            fld('Opened', to_char(c.creation_date, 'DD-MON-YYYY'));
            fld('SLA due', to_char(c.sla_due_date, 'DD-MON-YYYY'));
            fld('Closed', to_char(c.closed_date, 'DD-MON-YYYY'));
            grp('Case');
            fld('Risk classification', case when c.risk_tier is not null then xxfnd_ui_pkg.status_badge('RISK', c.risk_tier)
                                             else missing('Not classified', 'RISK') end, true);
            fld('Due Diligence Type', case when c.enhanced_kyc_flag = 'Y' then xxfnd_ui_pkg.badge(xxfnd_util_pkg.lookup_meaning('DUE_DILIGENCE_TYPE', c.due_diligence_type), 'warning')
                                           else apex_escape.html(xxfnd_util_pkg.lookup_meaning('DUE_DILIGENCE_TYPE', c.due_diligence_type)) end, true);
            fld('PEP', case when c.pep_flag = 'Y' then xxfnd_ui_pkg.badge('Yes', 'danger') else 'No' end, true);
            fld('Next review', to_char(c.next_review_date, 'DD-MON-YYYY'));
            fld('Report conclusion', c.report_conclusion, false, true);
            fld('Next steps', c.next_steps, false, true);
            fld('Conditions', c.conditions, false, true);
            grp('Assessment');
        end loop;
        return l_html;
    end case_summary_html;

end xxcmp_request_ui_pkg;
/
