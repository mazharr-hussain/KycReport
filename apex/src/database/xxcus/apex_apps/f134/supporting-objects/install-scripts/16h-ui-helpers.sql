-- 16h UI helpers (UI/UX standard, patch 13): one place for status badges and people, so every list, header card and
-- history shows them the same way. Markup classes are styled in kyc-app.css (kyc-badge, kyc-person).
-- Idempotent: create or replace only.

create or replace package xxfnd_ui_pkg authid definer as
    -- tone: neutral | info | success | warning | danger
    function badge(p_text in varchar2, p_tone in varchar2 default 'neutral') return varchar2;

    -- colour of a status code (UIUX-STANDARD.md section 9); p_object: REQUEST, PARTY, CASE, MATCH, SCREENING,
    -- DOCUMENT, RISK
    function status_tone(p_object in varchar2, p_code in varchar2) return varchar2;

    -- badge with the lookup meaning of the code
    function status_badge(p_object in varchar2, p_code in varchar2) return varchar2;

    -- employee name for a user name (the user name when there is no employee record; 'System' when null)
    function person_name(p_user_name in varchar2) return varchar2;

    -- employee name with a hover card: name, employee no., department, user name
    function person_html(p_user_name in varchar2) return varchar2;
end xxfnd_ui_pkg;
/

create or replace package body xxfnd_ui_pkg as

    function badge(p_text in varchar2, p_tone in varchar2 default 'neutral') return varchar2 is
    begin
        if p_text is null then
            return null;
        end if;
        return '<span class="kyc-badge kyc-badge--' || lower(nvl(p_tone, 'neutral')) || '">'
            || apex_escape.html(p_text) || '</span>';
    end badge;

    function status_tone(p_object in varchar2, p_code in varchar2) return varchar2 is
    begin
        return case upper(p_object)
            when 'REQUEST' then
                case p_code when 'IN_PROGRESS' then 'info' when 'INFO_NEEDED' then 'warning'
                            when 'APPROVED' then 'success' when 'REJECTED' then 'danger' else 'neutral' end
            when 'PARTY' then
                case p_code when 'PENDING' then 'warning' when 'APPROVED' then 'success'
                            when 'REJECTED' then 'danger' else 'neutral' end
            when 'CASE' then
                case p_code when 'INVESTIGATION' then 'info' when 'PENDING_APPROVAL' then 'warning'
                            when 'APPROVED' then 'success' when 'REJECTED' then 'danger' else 'neutral' end
            when 'MATCH' then
                case p_code when 'SELECTED' then 'success' when 'NEW' then 'info'
                            when 'PENDING' then 'warning' else 'neutral' end
            when 'SCREENING' then
                case p_code when 'NO_MATCH' then 'success' when 'POTENTIAL_MATCH' then 'warning'
                            when 'CONFIRMED_MATCH' then 'danger' else 'neutral' end
            when 'DOCUMENT' then
                case p_code when 'VERIFIED' then 'success' when 'REJECTED' then 'danger'
                            when 'EXPIRED' then 'danger' else 'neutral' end
            when 'RISK' then
                case p_code when 'LOW' then 'success' when 'MEDIUM' then 'warning'
                            when 'HIGH' then 'danger' else 'neutral' end
            else 'neutral'
        end;
    end status_tone;

    function status_badge(p_object in varchar2, p_code in varchar2) return varchar2 is
        l_type varchar2(30);
    begin
        if p_code is null then
            return null;
        end if;
        l_type := case upper(p_object)
                      when 'REQUEST'   then 'KYC_REQUEST_STATUS'
                      when 'PARTY'     then 'PARTY_STATUS'
                      when 'CASE'      then 'CASE_STATUS'
                      when 'MATCH'     then 'REQUEST_MATCH_STATUS'
                      when 'SCREENING' then 'SCREENING_MATCH_STATUS'
                      when 'DOCUMENT'  then 'DOC_VERIFICATION_STATUS'
                      when 'RISK'      then 'RISK_TIER'
                  end;
        return badge(nvl(xxfnd_util_pkg.lookup_meaning(l_type, p_code), p_code), status_tone(p_object, p_code));
    end status_badge;

    function person_name(p_user_name in varchar2) return varchar2 is
        l_name xxfnd_employees.full_name%type;
    begin
        if p_user_name is null then
            return null;
        end if;
        if upper(p_user_name) = 'SYSTEM' then
            return 'System';
        end if;
        select max(full_name) into l_name from xxfnd_employees where upper(user_name) = upper(p_user_name);
        return nvl(l_name, p_user_name);
    end person_name;

    function person_html(p_user_name in varchar2) return varchar2 is
        l_emp xxfnd_employees%rowtype;
        function row_html(p_label in varchar2, p_value in varchar2) return varchar2 is
        begin
            return '<tr><th scope="row">' || apex_escape.html(p_label) || '</th><td>'
                || apex_escape.html(nvl(p_value, '-')) || '</td></tr>';
        end row_html;
    begin
        if p_user_name is null then
            return null;
        end if;
        if upper(p_user_name) = 'SYSTEM' then
            return '<span class="kyc-person kyc-person--system">System</span>';
        end if;
        begin
            select * into l_emp from xxfnd_employees where upper(user_name) = upper(p_user_name);
        exception
            when no_data_found then
                return '<span class="kyc-person">' || apex_escape.html(p_user_name) || '</span>';
        end;
        return '<span class="kyc-person" tabindex="0">' || apex_escape.html(l_emp.full_name)
            || '<span class="kyc-person-card" role="tooltip"><table>'
            || row_html('Name', l_emp.full_name)
            || row_html('Employee no.', l_emp.fusion_person_number)
            || row_html('Department', l_emp.department_name)
            || row_html('User name', l_emp.user_name)
            || '</table></span></span>';
    end person_html;

end xxfnd_ui_pkg;
/
