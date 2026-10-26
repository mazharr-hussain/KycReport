--------------------------------------------------------------------------------
-- 16z Request stages and requesting country (release 105). KYC only (XXCUS).
--   Step 1: XXCMP_REQUESTS.REQUESTING_COUNTRY - the country the request is raised for (lookup JURISDICTION, the
--   party's country list). Runs before the request package body (16r), which writes it.
-- Idempotent: the column is added only when missing.
--------------------------------------------------------------------------------
begin
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'REQUESTING_COUNTRY', 'varchar2(30)');
    execute immediate q'~comment on column xxcmp_requests.requesting_country is 'Release 105: the requesting country (lookup JURISDICTION); required to submit.'~';
end;
/
