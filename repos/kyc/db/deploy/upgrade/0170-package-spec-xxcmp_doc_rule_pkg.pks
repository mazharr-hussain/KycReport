
--==============================================================================
-- XXCMP_DOC_RULE_PKG (release 74: the document rules component; was XXCMP_KYC_PKG)
--==============================================================================
create or replace package xxcmp_doc_rule_pkg authid definer as

    -- Document categories required for a record, from approved rules; the most
    -- specific rule per category wins (jurisdiction + entity type, then either,
    -- then the general rule), PRIORITY breaks ties.
    function mandatory_categories(p_entity_name  in varchar2,
                                  p_jurisdiction in varchar2,
                                  p_entity_type  in varchar2) return apex_t_varchar2;

    -- Mandatory categories with no current, unexpired attachment on the record.
    function missing_categories(p_entity_name  in varchar2,
                                p_pk1_value    in varchar2,
                                p_jurisdiction in varchar2,
                                p_entity_type  in varchar2) return apex_t_varchar2;

    -- release 74: party matching (name similarity) is in the party package (XXCMP_PARTY_PKG); the unused
    -- exact_party_match is gone (XXCMP_PARTY_PKG.EXACT_PARTY_NUMBER is the duplicate check).

    -- release 74: requests for information are the common RFI workflow (XXFND_RFI_PKG, COMMON 15c).

end xxcmp_doc_rule_pkg;
/
