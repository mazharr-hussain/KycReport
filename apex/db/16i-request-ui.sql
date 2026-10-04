-- 16i Request UI (UI/UX standard, patch 14): the request header card and the questionnaire answers as question / answer
-- pairs, shared by the request view (205), Review and Submit (203) and the approval page (206) through Global Page regions.
-- Idempotent: create or replace only.

create or replace package xxcmp_request_ui_pkg authid definer as
    -- Header card: number and party, status / KYC / score badges, classification line, who it waits for.
    function header_html(p_request_id in number) return clob;

    -- Request details as a label-above-value grid: Request and Assessment groups, justification full width.
    function details_html(p_request_id in number) return clob;

    -- Requester answers in questionnaire order; answers that add risk or are critical carry a badge.
    function answers_html(p_request_id in number) return clob;
end xxcmp_request_ui_pkg;
/

create or replace package body xxcmp_request_ui_pkg as

    function header_html(p_request_id in number) return clob is
        l_html    clob;
        l_pending varchar2(255);
        l_kyc     varchar2(10);
        l_case    varchar2(30);
    begin
        for r in (select * from xxcmp_requests where request_id = p_request_id) loop     -- data security applies
            l_pending := xxcmp_request_pkg.pending_with(r.request_id);
            l_kyc     := xxcmp_request_pkg.kyc_required(r.request_id);
            select max(case_number) into l_case from xxcmp_cases where request_id = r.request_id;

            l_html := '<div class="kyc-hcard-top"><span class="kyc-hcard-title">'
                   || apex_escape.html(r.request_number || ' · ' || r.party_name) || '</span>'
                   || xxfnd_ui_pkg.status_badge('REQUEST', r.request_status)
                   || case when l_kyc = 'Yes' then xxfnd_ui_pkg.badge('KYC required', 'warning') end
                   || case when r.intake_score is not null then
                          xxfnd_ui_pkg.badge('Score ' || r.intake_score
                                             || case when r.intake_critical_flag = 'Y' then ' · critical answer' end,
                                             case when r.intake_critical_flag = 'Y' then 'danger' else 'neutral' end)
                      end
                   || case when l_case is not null then xxfnd_ui_pkg.badge(l_case, 'info') end
                   || '</div>';
            l_html := l_html || '<div class="kyc-hcard-line">'
                   || apex_escape.html(rtrim(xxfnd_util_pkg.lookup_meaning('KYC_REQUEST_TYPE', r.request_type)
                                             || nvl2(r.business_relationship, ' · ' || xxfnd_util_pkg.lookup_meaning('BUSINESS_RELATIONSHIP', r.business_relationship), null)
                                             || nvl2(r.requesting_department, ' · ' || xxfnd_util_pkg.lookup_meaning('REQUESTING_DEPARTMENT', r.requesting_department), null), ' ·'))
                   || ' · requested by ' || xxfnd_ui_pkg.person_html(r.requester_user_name)
                   || '</div>';
            if l_pending is not null and r.request_status in ('DRAFT', 'IN_PROGRESS', 'INFO_NEEDED') then
                l_html := l_html || '<div class="kyc-hcard-line">Waiting for <b>' || xxfnd_ui_pkg.person_html(l_pending) || '</b>'
                       || nvl2(r.last_action_date, ' since ' || to_char(r.last_action_date, 'DD-MON-YYYY HH24:MI'), null) || '</div>';
            end if;
        end loop;
        return l_html;
    end header_html;

    function details_html(p_request_id in number) return clob is
        l_html clob;
        l_grp  clob;
        l_case xxcmp_cases%rowtype;

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
    begin
        for r in (select * from xxcmp_requests where request_id = p_request_id) loop     -- data security applies
            for c in (select * from xxcmp_cases where request_id = r.request_id) loop
                l_case := c;
            end loop;
            fld('Request type', xxfnd_util_pkg.lookup_meaning('KYC_REQUEST_TYPE', r.request_type));
            fld('Business relationship', xxfnd_util_pkg.lookup_meaning('BUSINESS_RELATIONSHIP', r.business_relationship));
            fld('Requesting department', xxfnd_util_pkg.lookup_meaning('REQUESTING_DEPARTMENT', r.requesting_department));
            fld('Requested by', xxfnd_ui_pkg.person_html(r.requester_user_name), true);
            fld('Submitted', to_char(r.submitted_date, 'DD-MON-YYYY HH24:MI'));
            fld('Last action', to_char(r.last_action_date, 'DD-MON-YYYY HH24:MI'));
            if l_case.case_id is not null then
                fld('Case', case when xxfnd_privilege_pkg.has_privilege('CASES', 'VIEW')
                                 then '<a href="' || apex_page.get_url(p_page => 211, p_items => 'P211_CASE_ID',
                                                                       p_values => to_char(l_case.case_id), p_clear_cache => '211')
                                      || '">' || apex_escape.html(l_case.case_number) || '</a>'
                                 else apex_escape.html(l_case.case_number) end, true);
            end if;
            fld('Business justification', r.justification, false, true);
            if r.match_status = 'MERGED' then
                fld('Merge note', r.match_note, false, true);
            end if;
            grp('Details');
            fld('Intake score', case when r.intake_score is not null then
                                     xxfnd_ui_pkg.badge(to_char(r.intake_score), case when r.intake_critical_flag = 'Y' then 'danger' else 'neutral' end)
                                end, true);
            fld('Routed to', xxfnd_util_pkg.lookup_meaning('KYC_INTAKE_OUTCOME', r.intake_outcome));
            fld('Reason', case when r.intake_critical_flag = 'Y' then 'Critical answer in the questionnaire' end);
            fld('KYC required', xxcmp_request_pkg.kyc_required(r.request_id));
            grp('Assessment');
        end loop;
        return l_html;
    end details_html;

    function answers_html(p_request_id in number) return clob is
        l_html  clob;
        l_score number := 0;
        l_crit  pls_integer := 0;
        l_risk  pls_integer := 0;
        l_n     pls_integer := 0;
    begin
        for a in (select q.question_text,
                         coalesce(o.answer_label, a.answer_text) as answer,
                         nvl(o.risk_points, 0) as risk_points,
                         nvl(o.critical_flag, 'N') as critical_flag
                    from xxcmp_request_answers a
                    join xxcmp_questions q on q.question_id = a.question_id
                    left join xxcmp_answer_options o on o.answer_option_id = a.answer_option_id
                   where a.request_id = p_request_id and a.respondent_type = 'REQUESTER'
                   order by q.display_sequence) loop
            l_n     := l_n + 1;
            l_score := l_score + a.risk_points;
            l_crit  := l_crit + case when a.critical_flag = 'Y' then 1 else 0 end;
            l_risk  := l_risk + case when a.risk_points > 0 and a.critical_flag = 'N' then 1 else 0 end;
            l_html  := l_html || '<div class="kyc-qa-item"><div class="kyc-qa-q">' || apex_escape.html(a.question_text) || '</div>'
                    || '<div class="kyc-qa-a">' || apex_escape.html(nvl(a.answer, '-'))
                    || case when a.critical_flag = 'Y' then ' ' || xxfnd_ui_pkg.badge('Critical', 'danger')
                            when a.risk_points > 0 then ' ' || xxfnd_ui_pkg.badge('Risk', 'warning') end
                    || '</div></div>';
        end loop;
        if l_n = 0 then
            return '<p class="u-color-subtle">No answers yet.</p>';
        end if;
        return '<div class="kyc-qa-score"><div><b>' || l_score || '</b><span>Risk points</span></div>'
            || '<div><b class="kyc-text-danger">' || l_crit || '</b><span>Critical answers</span></div>'
            || '<div><b class="kyc-text-warning">' || l_risk || '</b><span>Risk answers</span></div></div>'
            || '<div class="kyc-qa">' || l_html || '</div>';
    end answers_html;

end xxcmp_request_ui_pkg;
/
