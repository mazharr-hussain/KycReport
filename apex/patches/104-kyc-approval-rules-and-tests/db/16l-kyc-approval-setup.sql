--------------------------------------------------------------------------------
-- 16l KYC approvals in the common Approval Setup (release 74). KYC only (XXCUS).
--   KYC registers its transaction types with the attributes their rules can test:
--     KYC_REQUEST  request approval (was Approval Paths, page 166)
--     KYC_CASE     case approval levels (was the Case Approval Matrix, page 165)
--     CASE_RFI     a request for information raised on a case (default: the requester provides the information)
--   Once, when a type has no rule yet, its default rules are added, so the same people approve on day one.
--   Afterwards the rules are maintained in COMMON > Approval Setup (or delegated to KYC); a re-run changes nothing.
--   XXCMP_APPROVAL_PATHS / XXCMP_APPROVAL_MATRIX are kept unchanged (the matrix still holds the SAR gate).
--   Release 87: the request and RFI defaults are registered with COMMON's REGISTER_DEFAULT_RULE. Release 93: the
--   case rules (one per risk tier, two levels for high risk and enhanced KYC) are registered with COMMON's
--   REGISTER_RULE (COMMON 88 and later refuse direct writes), only on a database whose KYC_CASE type has no rule
--   yet. The 74 hand-over of running approvals and the page clean-up are gone (every supported database has them).
-- Install: after 18h (roles) and 18 (the matrix) and 16g (the paths) on a new database.
-- Idempotent.
--------------------------------------------------------------------------------
declare
    l_n    pls_integer;
    l_name varchar2(100);
begin
    xxfnd_util_pkg.set_install_mode(true);
    xxfnd_approval_rule_pkg.register_type('KYC_REQUEST', 'KYC', 'KYC request approval',
        'Who approves a KYC request (document checklist review).',
        apex_t_varchar2('REQUESTING_DEPARTMENT=Requesting department=REQUESTING_DEPARTMENT', 'PARTY_TYPE=Party type=PARTY_TYPE',
                        'JURISDICTION=Country=JURISDICTION', 'REQUEST_TYPE=Request type=KYC_REQUEST_TYPE',
                        'BUSINESS_RELATIONSHIP=Business relationship=BUSINESS_RELATIONSHIP'));
    xxfnd_approval_rule_pkg.register_type('KYC_CASE', 'KYC', 'KYC case approval',
        'Who approves a KYC case after the investigation, level by level.',
        apex_t_varchar2('RISK_TIER=Risk tier=RISK_TIER', 'ENHANCED_KYC=Enhanced KYC=YES_NO',
                        'PARTY_TYPE=Party type=PARTY_TYPE', 'BUSINESS_RELATIONSHIP=Business relationship=BUSINESS_RELATIONSHIP'));
    xxfnd_approval_rule_pkg.register_type('CASE_RFI', 'KYC', 'Case request for information',
        'Who provides the information asked on a case (default: the requester of the case).',
        apex_t_varchar2('RFI_CATEGORY=RFI category=RFI_CATEGORY', 'RISK_TIER=Risk tier=RISK_TIER'));

    -- request approval: the default path (any request) - one Compliance review
    xxfnd_approval_rule_pkg.register_default_rule('KYC', 'KYC_REQUEST', 'Default',
        apex_t_varchar2('Compliance review=ROLE=COMPLIANCE_OFFICER'), p_priority => 999);

    -- case approval: one rule per risk tier; enhanced KYC needs at least two levels (as before). Release 93: added
    -- with COMMON's REGISTER_RULE (COMMON refuses direct writes since its release 88); still only when KYC_CASE has no
    -- rule yet, so the administrators' rules are kept.
    select count(*) into l_n from xxfnd_approval_rules where approval_type_code = 'KYC_CASE';
    if l_n = 0 then
        for m in (select * from xxcmp_approval_matrix order by risk_tier) loop
            l_name := 'Risk tier ' || initcap(replace(m.risk_tier, '_', ' '));
            if m.required_levels >= 2 then
                xxfnd_approval_rule_pkg.register_rule('KYC', 'KYC_CASE', l_name,
                    apex_t_varchar2('Approval level 1=ROLE=' || m.level1_role_code,
                                    'Approval level 2=ROLE=' || nvl(m.level2_role_code, 'HEAD_OF_COMPLIANCE')),
                    apex_t_varchar2('RISK_TIER=' || m.risk_tier), 100);
            else
                xxfnd_approval_rule_pkg.register_rule('KYC', 'KYC_CASE', l_name,
                    apex_t_varchar2('Approval level 1=ROLE=' || m.level1_role_code),
                    apex_t_varchar2('RISK_TIER=' || m.risk_tier), 100);
                xxfnd_approval_rule_pkg.register_rule('KYC', 'KYC_CASE', l_name || ' - enhanced KYC',
                    apex_t_varchar2('Approval level 1=ROLE=' || m.level1_role_code,
                                    'Approval level 2=ROLE=' || nvl(m.level2_role_code, 'HEAD_OF_COMPLIANCE')),
                    apex_t_varchar2('RISK_TIER=' || m.risk_tier, 'ENHANCED_KYC=Y'), 90);
            end if;
        end loop;
    end if;

    -- case RFI: the requester provides the information
    xxfnd_approval_rule_pkg.register_default_rule('KYC', 'CASE_RFI', 'Requester provides the information',
        apex_t_varchar2('Information from the requester=REQUESTER'));
    commit;
    xxfnd_util_pkg.set_install_mode(false);
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/

