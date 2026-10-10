--------------------------------------------------------------------------------
-- 16l KYC approvals in the common Approval Setup (release 74). KYC only (XXCUS).
--   KYC registers its transaction types with the attributes their rules can test:
--     KYC_REQUEST  request approval (was Approval Paths, page 166)
--     KYC_CASE     case approval levels (was the Case Approval Matrix, page 165)
--     CASE_RFI     a request for information raised on a case (default: the requester provides the information)
--   Once, when a type has no rule yet, today's setup is copied into rules, so the same people approve on day one;
--   approvals already running continue at the same step. Afterwards the rules are maintained in COMMON > Approval
--   Setup (or delegated to KYC); a re-run changes nothing.
--   XXCMP_APPROVAL_PATHS / XXCMP_APPROVAL_MATRIX are kept unchanged (the matrix still holds the SAR gate).
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

    -- request approval: one rule per approval path (its criteria as conditions, its steps as approvers)
    select count(*) into l_n from xxfnd_approval_rules where approval_type_code = 'KYC_REQUEST';
    if l_n = 0 then
        for p in (select path_name, min(priority) priority from xxcmp_approval_paths
                   where enabled_flag = 'Y' group by path_name order by path_name) loop
            l_rule := new_rule('KYC_REQUEST', p.path_name, p.priority);
            for c in (select distinct requesting_department, party_type, jurisdiction, request_type, business_relationship
                        from xxcmp_approval_paths where path_name = p.path_name and enabled_flag = 'Y') loop
                cond(l_rule, 'REQUESTING_DEPARTMENT', c.requesting_department);
                cond(l_rule, 'PARTY_TYPE', c.party_type);
                cond(l_rule, 'JURISDICTION', c.jurisdiction);
                cond(l_rule, 'REQUEST_TYPE', c.request_type);
                cond(l_rule, 'BUSINESS_RELATIONSHIP', c.business_relationship);
            end loop;
            for s in (select step_sequence, step_name, approver_type, role_code, user_name,
                             row_number() over (order by step_sequence) n
                        from xxcmp_approval_paths where path_name = p.path_name and enabled_flag = 'Y') loop
                step(l_rule, s.n, s.step_name, s.approver_type, s.role_code, s.user_name);
            end loop;
        end loop;
    end if;

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
    select count(*) into l_n from xxfnd_approval_rules where approval_type_code = 'CASE_RFI';
    if l_n = 0 then
        l_rule := new_rule('CASE_RFI', 'Requester provides the information', 100);
        step(l_rule, 1, 'Information from the requester', 'REQUESTER', null);
    end if;
    commit;
    xxfnd_util_pkg.set_install_mode(false);
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/

-- approvals already running continue at the same step
declare
    l_name varchar2(100);
begin
    xxfnd_vpd_pkg.begin_trusted;
    for r in (select q.* from xxcmp_requests q
               where q.request_status = 'IN_PROGRESS' and q.current_step is not null
                 and not exists (select 1 from xxfnd_approval_txns t
                                  where t.approval_type_code = 'KYC_REQUEST' and t.txn_id = to_char(q.request_id))) loop
        begin
            l_name := xxfnd_approval_rule_pkg.start_approval('KYC_REQUEST', to_char(r.request_id),
                          apex_t_varchar2('REQUESTING_DEPARTMENT=' || r.requesting_department, 'PARTY_TYPE=' || r.party_type,
                                          'JURISDICTION=' || r.jurisdiction, 'REQUEST_TYPE=' || r.request_type,
                                          'BUSINESS_RELATIONSHIP=' || r.business_relationship),
                          r.requester_user_name);
            update xxfnd_approval_txns
               set current_seq = 10 * (select count(*) from xxcmp_approval_paths p
                                        where p.path_name = r.approval_path_name and p.enabled_flag = 'Y'
                                          and p.step_sequence <= r.current_step)
             where approval_type_code = 'KYC_REQUEST' and txn_id = to_char(r.request_id);
        exception
            when others then
                -- no rule applies: logged for IT; the request keeps its approval path name
                xxfnd_error_pkg.log_error('16l in-flight request ' || r.request_id);
        end;
    end loop;
    for c in (select k.* from xxcmp_cases k
               where k.case_status = 'PENDING_APPROVAL' and k.current_level is not null
                 and not exists (select 1 from xxfnd_approval_txns t
                                  where t.approval_type_code = 'KYC_CASE' and t.txn_id = to_char(k.case_id))) loop
        begin
            l_name := xxfnd_approval_rule_pkg.start_approval('KYC_CASE', to_char(c.case_id),
                          apex_t_varchar2('RISK_TIER=' || c.risk_tier, 'ENHANCED_KYC=' || nvl(c.enhanced_kyc_flag, 'N')),
                          null);
            update xxfnd_approval_txns set current_seq = 10 * c.current_level
             where approval_type_code = 'KYC_CASE' and txn_id = to_char(c.case_id);
        exception
            when others then
                xxfnd_error_pkg.log_error('16l in-flight case ' || c.case_id);
        end;
    end loop;
    xxfnd_vpd_pkg.end_trusted;
    commit;
exception
    when others then
        xxfnd_vpd_pkg.end_trusted;
        raise;
end;
/
