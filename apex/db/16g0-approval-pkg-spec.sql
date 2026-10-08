--------------------------------------------------------------------------------
-- 16g0 Request approval paths - types and package specification (release 69)
--   Split from 16g so they exist before 16b, whose XXCMP_REQUEST_PKG calls XXCMP_APPROVAL_PKG (a fresh install
--   otherwise compiles 16b with errors). The specification uses no table; the body stays in 16g.
-- Idempotent: safe on install and on every upgrade.
--------------------------------------------------------------------------------
-- one row of the approval history table (Global Page region Approval History)
create or replace type xxcmp_history_row force as object (
    step_no      number,
    step_name    varchar2(200),
    assigned_to  varchar2(1000),
    action       varchar2(100),
    action_by    varchar2(255),
    action_date  timestamp,
    comments     varchar2(4000)
);
/
create or replace type xxcmp_history_tab force as table of xxcmp_history_row;
/

create or replace package xxcmp_approval_pkg authid definer as
    -- Path that applies to the request (most matching criteria, then lowest priority).
    function path_for(p_request_id in number) return varchar2;
    -- Starts the path on submit: first step.
    procedure start_path(p_request_id in number);
    -- Approvers (comma-separated user names) of the request's current step.
    function step_approvers(p_request_id in number) return varchar2;
    -- Name of the current step.
    function step_name(p_request_id in number) return varchar2;
    -- Moves to the next step: Y when there is one, N when the path is complete.
    function next_step(p_request_id in number) return varchar2;
    -- HTML: the steps of the path (expected before submit; done / current / waiting after).
    function path_html(p_request_id in number) return clob;
    -- HTML: who did what and when on the request (submit, approvals, information requests, comments).
    function history_html(p_request_id in number) return clob;
    -- The approval history table: what happened (submit, decisions, information requests, withdraw, cancel) with
    -- who, when and the comments; then the current step (Pending, with its approvers) and the steps still to come
    -- (Waiting); before submit, the expected steps (Expected) with their role or user.
    function history_rows(p_request_id in number) return xxcmp_history_tab pipelined;
    -- The same table for a case (release 27): investigation, then each approval level of the approval matrix (who, when,
    -- outcome, comments); the current level Pending and the levels to come Waiting (Expected while investigating).
    function case_history_rows(p_case_id in number) return xxcmp_history_tab pipelined;
end xxcmp_approval_pkg;
/
