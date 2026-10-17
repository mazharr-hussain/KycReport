
--==============================================================================
-- 0.0  KYC RULES ENGINE
--==============================================================================
begin
    if xxfnd_ddl_pkg.create_table('XXCMP_QUESTIONNAIRES', q'~create table xxcmp_questionnaires (
    questionnaire_code     varchar2(30)   not null,
    questionnaire_name     varchar2(240)  not null,
    audience               varchar2(20)   not null,
    low_risk_max_score     number,
    medium_risk_max_score  number,
    current_version_number number         default 1 not null,
    enabled_flag           varchar2(1)    default 'Y' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxcmp_questionnaires_pk primary key (questionnaire_code),
    constraint xxcmp_questionnaires_ck1 check (audience in ('REQUESTER','OFFICER')),
    constraint xxcmp_questionnaires_ck2 check (enabled_flag in ('Y','N')),
    constraint xxcmp_questionnaires_ck3 check (
        low_risk_max_score is null or medium_risk_max_score is null or medium_risk_max_score >= low_risk_max_score),
    constraint xxcmp_questionnaires_ck4 check (
        audience = 'REQUESTER' or (low_risk_max_score is null and medium_risk_max_score is null))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table  xxcmp_questionnaires is 'Requester intake questionnaires (scored, drive routing) and the Officer investigation questionnaire (unscored, informs a manual classification).'~');
        xxfnd_ddl_pkg.run(q'~comment on column xxcmp_questionnaires.current_version_number is 'Raised when an approved scoring change goes live. Responses snapshot the version they were scored against.'~');
    end if;
end;
/
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
