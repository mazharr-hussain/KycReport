--------------------------------------------------------------------------------
-- 02_xxcmp_tables.sql
-- KYC/KYB-specific objects (XXCMP_), Module 0 scope:
--   0.0  KYC rules engine (questionnaires), conclusion templates, approval matrix
--   0.1  Mandatory-document rules
--   0.2  Request for Information; workflow activity controls
--   0.3  Party / entity master (carries the DFF column block)
-- Depends on 01_xxfnd_tables.sql.
--------------------------------------------------------------------------------

--==============================================================================
-- 0.3  PARTY / ENTITY MASTER
--==============================================================================
begin
    xxfnd_ddl_pkg.ensure_sequence('XXCMP_PARTY_NUMBER_S', q'~create sequence xxcmp_party_number_s start with 1 nocache~');
end;
/
