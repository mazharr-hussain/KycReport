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
