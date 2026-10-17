--------------------------------------------------------------------------------
-- 16l KYC approvals in the common Approval Setup (release 74). KYC only (XXCUS).
--   KYC registers its transaction types with the attributes their rules can test:
--     KYC_REQUEST  request approval (was Approval Paths, page 166)
--     KYC_CASE     case approval levels (was the Case Approval Matrix, page 165)
--     CASE_RFI     a request for information raised on a case (default: the requester provides the information)
--   Once, when a type has no rule yet, its default rules are added, so the same people approve on day one.
--   Afterwards the rules are maintained in COMMON > Approval Setup (or delegated to KYC); a re-run changes nothing.
--   XXCMP_APPROVAL_PATHS / XXCMP_APPROVAL_MATRIX are kept unchanged (the matrix still holds the SAR gate).
--   Release 87: the request and RFI defaults are registered with COMMON's REGISTER_DEFAULT_RULE. The case rules
--   (one per risk tier, two levels for high risk and enhanced KYC) are still copied from the matrix here, because
--   COMMON registers only one default rule per type: the one place KYC still writes COMMON rows, and only on a
--   database whose KYC_CASE type has no rule yet. The 74 hand-over of running approvals and the page clean-up are
--   gone (every supported database has them).
-- Install: after 18h (roles) and 18 (the matrix) and 16g (the paths) on a new database.
-- Idempotent.
--------------------------------------------------------------------------------
declare
    l_rule number;
    l_n    pls_integer;
    l_name varchar2(100);
    procedure cond(p_rule in number, p_attr in varchar2, p_value in varchar2) is
    begin
        if p_value is not null then
            merge into xxfnd_approval_rule_conds d
            using (select p_rule r, p_attr a, p_value v from dual) s
               on (d.rule_id = s.r and d.attribute_code = s.a and d.attribute_value = s.v)
             when not matched then insert (rule_id, attribute_code, attribute_value) values (s.r, s.a, s.v);
        end if;
    end cond;
    function new_rule(p_type in varchar2, p_name in varchar2, p_priority in number) return number is
        l_id number;
    begin
        insert into xxfnd_approval_rules (approval_type_code, rule_name, priority)
        values (p_type, p_name, p_priority) returning rule_id into l_id;
        return l_id;
    end new_rule;
    procedure step(p_rule in number, p_no in number, p_name in varchar2, p_type in varchar2, p_role in varchar2,
                   p_user in varchar2 default null) is
    begin
        insert into xxfnd_approval_rule_steps (rule_id, step_no, step_name, approver_type, role_code, user_name)
        values (p_rule, p_no, p_name, p_type, p_role, p_user);
    end step;
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

    -- case approval: one rule per risk tier; enhanced KYC needs at least two levels (as before)
    select count(*) into l_n from xxfnd_approval_rules where approval_type_code = 'KYC_CASE';
    if l_n = 0 then
        for m in (select * from xxcmp_approval_matrix order by risk_tier) loop
            l_name := initcap(replace(m.risk_tier, '_', ' '));
            l_rule := new_rule('KYC_CASE', 'Risk tier ' || l_name, 100);
            cond(l_rule, 'RISK_TIER', m.risk_tier);
            step(l_rule, 1, 'Approval level 1', 'ROLE', m.level1_role_code);
            if m.required_levels >= 2 then
                step(l_rule, 2, 'Approval level 2', 'ROLE', nvl(m.level2_role_code, 'HEAD_OF_COMPLIANCE'));
            else
                l_rule := new_rule('KYC_CASE', 'Risk tier ' || l_name || ' - enhanced KYC', 90);
                cond(l_rule, 'RISK_TIER', m.risk_tier);
                cond(l_rule, 'ENHANCED_KYC', 'Y');
                step(l_rule, 1, 'Approval level 1', 'ROLE', m.level1_role_code);
                step(l_rule, 2, 'Approval level 2', 'ROLE', nvl(m.level2_role_code, 'HEAD_OF_COMPLIANCE'));
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

