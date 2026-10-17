--------------------------------------------------------------------------------
-- 10.2 KYC rules seed: questionnaire headers, the approval matrix (SAR gate), conclusion templates
--   Release 87: the roles, notification templates, flexfields, document entities, categories, attachment pages,
--   integration purposes and the first administrator are registered in COMMON by 18h (COMMON's registration
--   routines). The document storage is COMMON's (database until COMMON's administrator sets up a server); the
--   retired endpoint is no longer seeded. Runs after 18h (the matrix refers to KYC's roles).
--------------------------------------------------------------------------------
begin
    xxfnd_util_pkg.set_install_mode(true);
    ----------------------------------------------------------------------------
    -- KYC rules engine headers (questions and answers are maintained on screen)
    ----------------------------------------------------------------------------
    merge into xxcmp_questionnaires t
    using (select 'INDIVIDUAL' c, 'Individual KYC Questionnaire' n, 'REQUESTER' a, 10 lo, 20 mid from dual
           union all select 'CORPORATE', 'Corporate KYB Questionnaire', 'REQUESTER', 15, 30 from dual
           union all select 'OFFICER_INVESTIGATION', 'Officer Investigation Questionnaire', 'OFFICER', null, null from dual) s
       on (t.questionnaire_code = s.c)
     when not matched then insert (questionnaire_code, questionnaire_name, audience, low_risk_max_score, medium_risk_max_score)
                           values (s.c, s.n, s.a, s.lo, s.mid);

    merge into xxcmp_approval_matrix t
    using (select 'LOW' rt, 1 lv, 'COMPLIANCE_MANAGER' r1, cast(null as varchar2(30)) r2, 'N' sar from dual
           union all select 'MEDIUM', 1, 'COMPLIANCE_MANAGER', null, 'N' from dual
           union all select 'HIGH', 2, 'COMPLIANCE_MANAGER', 'HEAD_OF_COMPLIANCE', 'Y' from dual) s
       on (t.risk_tier = s.rt)
     when not matched then insert (risk_tier, required_levels, level1_role_code, level2_role_code, sar_gate_flag)
                           values (s.rt, s.lv, s.r1, s.r2, s.sar);

    merge into xxcmp_conclusion_templates t
    using (select 'LOW' rt, 'Low risk conclusion' nm,
                  'Based on the due diligence performed, #PARTY_NAME# (request #REQUEST_NUMBER#) is assessed as #RISK_TIER# risk. '
                  || 'Standard due diligence is sufficient and the relationship may proceed subject to periodic review.' tx from dual
           union all select 'MEDIUM', 'Medium risk conclusion',
                  'Based on the due diligence performed, #PARTY_NAME# (request #REQUEST_NUMBER#) is assessed as #RISK_TIER# risk. '
                  || 'Risk factors noted: #RISK_FACTORS#. The relationship may proceed with the mitigating controls described above.' from dual
           union all select 'HIGH', 'High risk conclusion',
                  'Based on the enhanced due diligence performed, #PARTY_NAME# (request #REQUEST_NUMBER#) is assessed as #RISK_TIER# risk. '
                  || 'Risk factors noted: #RISK_FACTORS#. Senior approval is required before the relationship proceeds.' from dual) s
       on (t.risk_tier = s.rt)
     when not matched then insert (risk_tier, template_name, template_text) values (s.rt, s.nm, s.tx);

    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
