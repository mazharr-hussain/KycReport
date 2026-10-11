--------------------------------------------------------------------------------
-- 16u0 Risk model - package specification (release 74, R16). KYC only (XXCUS).
--   The specification runs before 16s (the case package uses it: the risk score on submit, the review interval); the
--   tables, the body and the seed are 16u. The specification uses no table.
-- Idempotent: create or replace only.
--------------------------------------------------------------------------------
create or replace package xxcmp_risk_pkg authid definer as
    -- The risk model (business-maintained, maker-checker): factors with points (XXCMP_RISK_FACTORS), country lists
    -- such as the FATF black and grey lists (XXCMP_RISK_COUNTRIES) and tier thresholds with review intervals
    -- (XXCMP_RISK_TIERS). Every row keeps its last approved values: the APPROVED model scores the cases; the PROPOSED
    -- model (the values being changed) is used only to preview the impact of a change.
    c_approved constant varchar2(10) := 'APPROVED';
    c_proposed constant varchar2(10) := 'PROPOSED';

    -- The score of a case and the factors behind it: JSON array [{"factor_code","factor_name","detail","points",
    -- "force_tier"}]. P_MODEL: APPROVED (default) or PROPOSED.
    function breakdown_json(p_case_id in number, p_model in varchar2 default 'APPROVED') return clob;
    function score(p_case_id in number, p_model in varchar2 default 'APPROVED') return number;
    -- The risk tier the model suggests for the case (the thresholds; a factor may force a tier, e.g. FATF black list).
    function suggested_tier(p_case_id in number, p_model in varchar2 default 'APPROVED') return varchar2;
    -- Calculates the case with the approved model and keeps the breakdown (XXCMP_CASE_RISK_SCORES) - on submit for
    -- approval and on Recalculate.
    procedure calculate(p_case_id in number);
    -- Review interval (months) of a tier in the approved model (the RISK_TIER lookup tag when not set).
    function review_months(p_risk_tier in varchar2) return number;
    -- Impact of the proposed changes (R24): the open cases whose suggested tier would change. JSON array
    -- [{"case_id","case_number","party_name","current_score","current_tier","proposed_score","proposed_tier"}].
    function impact_json return clob;
    -- Y while risk model changes wait to be submitted or approved.
    function has_pending_changes return varchar2;
    -- Submits the changed rows of the model for approval (one approval task per table that has changes).
    procedure submit_changes;
end xxcmp_risk_pkg;
/
