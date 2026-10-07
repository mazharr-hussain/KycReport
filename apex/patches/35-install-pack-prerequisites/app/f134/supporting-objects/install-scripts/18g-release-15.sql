--------------------------------------------------------------------------------
-- 18g Release 15 marker
-- Upload limits (application / attachment page / category), attachment permission checks on save,
-- administrator SQL checks for flexfields, cached lookup meanings, RFI recipient index.
-- The changes themselves live in scripts 05, 10, 11, 14 and 16, which run on install and upgrade.
--------------------------------------------------------------------------------
begin
    xxfnd_ddl_pkg.mark_release('R15', 'Release 15: upload limits, attachment and flexfield hardening, lookup cache');
    commit;
end;
/
