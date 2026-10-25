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
