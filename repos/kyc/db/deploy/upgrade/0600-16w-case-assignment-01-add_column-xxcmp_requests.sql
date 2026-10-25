--------------------------------------------------------------------------------
-- 16w Case assignment from the request (release 75). KYC only (XXCUS).
--   XXCMP_REQUESTS.CASE_ASSIGNEE: the officer chosen in the Approve popup of the approval that opens the case
--   (XXCMP_REQUEST_PKG.SET_CASE_ASSIGNEE); XXCMP_REQUEST_PKG.OPEN_CASE gives the case to that person (empty: the
--   approver, as before). Runs before the request package body (16r), which reads the column.
-- Idempotent: the column is added only when missing (XXFND_DDL_PKG.ADD_COLUMN).
--------------------------------------------------------------------------------
begin
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'CASE_ASSIGNEE', 'varchar2(255)');
    execute immediate q'~comment on column xxcmp_requests.case_assignee is 'Release 75: user name of the officer chosen to investigate the case when the request is approved (empty: the approver).'~';
end;
/
