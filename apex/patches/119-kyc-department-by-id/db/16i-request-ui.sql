-- 16i Request UI (UI/UX standard, patch 14): data for the request screens - the request view (205), Review and Submit
-- (203) and the approval page (206). Release 74 (R11): no HTML here; the screens use standard reports.
-- Idempotent: create or replace only.

create or replace package xxcmp_request_ui_pkg authid definer as
    -- release 74 (R11): data only. The request's details for the standard Value Attribute Pairs report (pages 205 / 206):
    -- JSON array [{"group_name","seq","label","value","tone","url","user_name"}]; data security applies. The header card
    -- and the questionnaire answers are SQL in their regions (Global Page).
    function details_json(p_request_id in number) return clob;
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
            fld('Details', 'Request type', xxfnd_lookup_pkg.lookup_meaning('KYC_REQUEST_TYPE', r.request_type));
            fld('Details', 'Business relationship', xxfnd_lookup_pkg.lookup_meaning('BUSINESS_RELATIONSHIP', r.business_relationship));
            -- release 96: COMMON's department (an older request without one keeps its code's meaning)
            fld('Details', 'Requesting department',
                coalesce(xxcmp_request_pkg.department_name(r.requesting_department_id),
                         xxfnd_lookup_pkg.lookup_meaning('REQUESTING_DEPARTMENT', r.requesting_department)));
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
            fld('Assessment', 'Routed to', xxfnd_lookup_pkg.lookup_meaning('KYC_INTAKE_OUTCOME', r.intake_outcome));
            fld('Assessment', 'Reason', case when r.intake_critical_flag = 'Y' then 'Critical answer in the questionnaire' end);
            fld('Assessment', 'KYC required', xxcmp_request_pkg.kyc_required(r.request_id));
        end loop;
        return l_rows.to_clob;
    end details_json;

end xxcmp_request_ui_pkg;
/
