-- 16h UI helpers (UI/UX standard, patch 13): one place for status colours and people, so every list, header card and
-- history shows them the same way. Release 74 (R11): data only - the screens draw the badges and person tags with their
-- own column templates (kyc-badge, kyc-person in kyc-app.css); no HTML here.
-- Idempotent: create or replace only.

create or replace package xxfnd_ui_pkg authid definer as
    -- colour of a status code (UIUX-STANDARD.md section 9); p_object: REQUEST, PARTY, CASE, MATCH, SCREENING,
    -- DOCUMENT, RISK, RFI
    function status_tone(p_object in varchar2, p_code in varchar2) return varchar2;

    -- the lookup meaning of a status code (data; release 74: the screens show it with their own badge template)
    function status_label(p_object in varchar2, p_code in varchar2) return varchar2;

    -- employee name for a user name (the user name when there is no employee record; 'System' when null)
    function person_name(p_user_name in varchar2) return varchar2;

    -- release 74 (R11): the employee hover card as data (PERSON_CARD application process; kyc-app.js kycPerson builds the
    -- card): JSON {"name","employee_number","department","user_name"}, or null when there is no employee record.
    function person_json(p_user_name in varchar2) return varchar2;

end xxfnd_ui_pkg;
/

create or replace package body xxfnd_ui_pkg as


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
                            when 'PENDING_INFORMATION' then 'warning' when 'APPROVED' then 'success' when 'REJECTED' then 'danger' else 'neutral' end
            when 'MATCH' then
                case p_code when 'SELECTED' then 'success' when 'NEW' then 'info'
                            when 'PENDING' then 'warning' else 'neutral' end
            when 'SCREENING' then
                case p_code when 'NO_MATCH' then 'success' when 'POTENTIAL_MATCH' then 'warning'
                            when 'CONFIRMED_MATCH' then 'danger' else 'neutral' end
            when 'DOCUMENT' then
                case p_code when 'VERIFIED' then 'success' when 'REJECTED' then 'danger'
                            when 'EXPIRED' then 'danger' else 'neutral' end
            when 'RFI' then
                case p_code when 'WAITING_FOR_INFORMATION' then 'warning' when 'ON_HOLD_PENDING' then 'warning'
                            when 'ON_HOLD_INVESTIGATION' then 'warning' when 'RESOLVED' then 'success'
                            when 'REJECTED_RETURNED' then 'danger' else 'neutral' end
            when 'RISK' then
                case p_code when 'LOW' then 'success' when 'MEDIUM' then 'warning'
                            when 'HIGH' then 'danger' else 'neutral' end
            else 'neutral'
        end;
    end status_tone;

    function status_label(p_object in varchar2, p_code in varchar2) return varchar2 is
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
                      when 'RFI'       then 'RFI_STATUS'
                  end;
        return nvl(xxfnd_lookup_pkg.lookup_meaning(l_type, p_code), p_code);
    end status_label;


    function person_name(p_user_name in varchar2) return varchar2 is
        l_name xxhr_employees.full_name%type;
    begin
        if p_user_name is null then
            return null;
        end if;
        -- release 76 (A-11): work done in the background (workflow activities, automations) runs as APEX user NOBODY
        if upper(p_user_name) in ('SYSTEM', 'NOBODY') then
            return 'System';
        end if;
        select max(full_name) into l_name from xxhr_employees where upper(user_name) = upper(p_user_name);
        return nvl(l_name, p_user_name);
    end person_name;

    function person_json(p_user_name in varchar2) return varchar2 is
        l_json varchar2(4000);
    begin
        select json_object('name' value full_name, 'employee_number' value fusion_person_number,
                           'department' value department_name, 'user_name' value user_name)
          into l_json
          from xxhr_employees where upper(user_name) = upper(p_user_name);
        return l_json;
    exception
        when no_data_found then
            return null;
    end person_json;





end xxfnd_ui_pkg;
/
