create or replace type xxcmp_history_tab force as table of xxcmp_history_row;
/

-- Release 90: the request approval routines (XXCMP_APPROVAL_PKG) are part of XXCMP_REQUEST_PKG (16b specification, 16r
-- body); 16g drops the old package. Only the history types stay here (XXCMP_REQUEST_PKG.HISTORY_ROWS and
-- XXCMP_CASE_PKG.CASE_HISTORY_ROWS return them; they must exist before 16b).
