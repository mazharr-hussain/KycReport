--------------------------------------------------------------------------------
-- 16g0 Approval history types (release 69; release 90: types only)
--   Split from 16g so they exist before 16b, whose package specifications return them (a fresh install
--   otherwise compiles 16b with errors).
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

-- Release 90: the request approval routines (XXCMP_APPROVAL_PKG) are part of XXCMP_REQUEST_PKG (16b specification, 16r
-- body); 16g drops the old package. Only the history types stay here (XXCMP_REQUEST_PKG.HISTORY_ROWS and
-- XXCMP_CASE_PKG.CASE_HISTORY_ROWS return them; they must exist before 16b).
