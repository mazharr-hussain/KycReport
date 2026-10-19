--------------------------------------------------------------------------------
-- 99z HR tables: the old names go (release 102). COMMON only; the last script of install and upgrade.
--   Script 00d keeps synonyms with the old names (XXFND_EMPLOYEES, XXFND_ORGANIZATIONS) while an upgrade runs, so the
--   code of the installed release stays valid until its script recreates it with the XXHR_ names. Every script has
--   run now: the synonyms are dropped (XXFND_DDL_PKG.DROP_OBJECT records anything that still depended on them).
-- Idempotent: drops only a synonym that exists.
--------------------------------------------------------------------------------
begin
    xxfnd_ddl_pkg.drop_object('XXFND_EMPLOYEES', 'SYNONYM');
    xxfnd_ddl_pkg.drop_object('XXFND_ORGANIZATIONS', 'SYNONYM');
end;
/
