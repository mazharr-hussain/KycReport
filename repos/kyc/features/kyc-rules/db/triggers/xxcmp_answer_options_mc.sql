--------------------------------------------------------------------------------
-- 09_xxcmp_rules.sql
-- Business rules that sit on the tables:
--   * maker-checker triggers on the three controlled configuration tables
--   * party / RFI numbering
--   * ownership-cycle check on party relationships
--   * XXCMP_DOC_RULE_PKG (was XXCMP_KYC_PKG): mandatory-document resolution (release 74: party matching is in
--     XXCMP_PARTY_PKG, RFIs in COMMON XXFND_RFI_PKG)
-- Depends on 03 (approval, security), 07 (attachments), 08 (workflow).
-- Needs: grant execute on dbms_crypto to <parsing schema>  (RFI tokens).
--------------------------------------------------------------------------------

--==============================================================================
-- Maker-checker (XXFND_APPROVAL_PKG.APPLY_RULES)
--==============================================================================
create or replace trigger xxcmp_answer_options_mc
    before insert or update on xxcmp_answer_options
    for each row
begin
    xxfnd_approval_pkg.apply_rules(inserting, :old.approval_status, :new.approval_status,
                                   :old.last_updated_by, :new.approved_by, :new.approved_date);
end;
/
