-- KYC release 87 (run as XXCUS): KYC runs on the completed COMMON (release 86).
--   - KYC is registered in COMMON and owns what it registered (roles, features, lookups, entities, categories,
--     attachment pages, purposes, flexfields, the alert template); the shared screens' pages map to COMMON's features
--   - no synonym of this schema points to a COMMON object that no longer exists; no invalid object
--   - KYC has no copy of COMMON's automations (task deadlines, Fusion HCM sync); its monitoring automation stays
--   - a party merge moves the duplicate's documents through COMMON (XXFND_ATTACH_PKG.MOVE_DOCUMENTS)
-- Test rows are kept (two parties and one note document, named "K87 test").
set serveroutput on size unlimited feedback off
declare
    l_n     number;
    l_from  number;
    l_into  number;
    l_doc   number;
    l_app   number;

    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
    function cnt(p_sql varchar2) return number is
        l number;
    begin
        execute immediate p_sql into l;
        return l;
    end;
begin
    select max(application_id) into l_app from apex_applications where upper(alias) = 'KYC';
    ok('KYC is registered in COMMON',
       cnt(q'[select count(*) from xxfnd_applications where application_code = 'KYC' and apex_application_id is not null]') = 1);
    ok('the 5 KYC roles are KYC''s',
       cnt(q'[select count(*) from xxfnd_roles where application_code = 'KYC' and role_code in
              ('REQUESTER','COMPLIANCE_OFFICER','COMPLIANCE_MANAGER','HEAD_OF_COMPLIANCE','SYSTEM_ADMIN')]') = 5);
    ok('the 9 KYC features are KYC''s',
       cnt(q'[select count(*) from xxfnd_features f join xxfnd_applications a on a.application_id = f.application_id
               where a.application_code = 'KYC' and f.feature_code in ('HOME','KYC_REQUESTS','PARTIES','CASES','CASE_ASSIGNMENT',
                     'MONITORING','DASHBOARD','KYC_RULES','ALERT_RULES')]') = 9);
    ok('KYC features have their privileges (20)',
       cnt(q'[select count(*) from xxfnd_privileges where feature_code in ('HOME','KYC_REQUESTS','PARTIES','CASES',
              'CASE_ASSIGNMENT','MONITORING','DASHBOARD','KYC_RULES','ALERT_RULES')]') = 20);
    -- a new database maps the SAR gate to KYC Rules; an existing one keeps its mapping (registration keeps it)
    ok('the case page belongs to Cases, the SAR gate is mapped',
       cnt(q'[select count(*) from xxfnd_feature_pages where upper(app_alias) = 'KYC'
               and ((page_id = 211 and feature_code = 'CASES')
                    or (page_id = 165 and feature_code in ('KYC_RULES', 'WORKFLOW_SETUP')))]') = 2);
    ok('My Tasks (40) and the Workflow Monitor (41) are COMMON features used by KYC pages',
       cnt(q'[select count(*) from xxfnd_feature_pages where upper(app_alias) = 'KYC'
               and ((page_id = 40 and feature_code = 'MY_TASKS') or (page_id = 41 and feature_code = 'WORKFLOW_MONITOR'))]') = 2);
    ok('KYC lookups are KYC''s (RISK_TIER, CASE_STATUS, PARTY_TYPE, KYC_PARAMETER, ALERT_TYPE)',
       cnt(q'[select count(*) from xxfnd_lookup_types where application_code = 'KYC'
               and lookup_type in ('RISK_TIER','CASE_STATUS','PARTY_TYPE','KYC_PARAMETER','ALERT_TYPE')]') = 5);
    ok('the risk tiers LOW, MEDIUM and HIGH are there',
       cnt(q'[select count(*) from xxfnd_lookup_values where lookup_type = 'RISK_TIER'
               and lookup_code in ('LOW','MEDIUM','HIGH')]') = 3);
    ok('the 6 KYC document entities are registered',
       cnt(q'[select count(*) from xxfnd_document_entities where entity_name in ('XXCMP_PARTIES','XXCMP_RFIS','XXCMP_REQUESTS',
              'XXCMP_CASES','XXCMP_PARTY_ID_VERIFICATIONS','XXCMP_PARTY_REGISTRY_CHECKS')]') = 6);
    ok('the 16 KYC document categories are KYC''s',
       cnt(q'[select count(*) from xxfnd_document_categories where application_code = 'KYC']') >= 16);
    ok('the 7 KYC attachment pages are registered',
       cnt(q'[select count(*) from xxfnd_attachment_functions where function_code like 'KYC\_%' escape '\']') >= 7);
    ok('the KYC integration purposes are KYC''s (5)',
       cnt(q'[select count(*) from xxfnd_integration_purposes where application_code = 'KYC'
               and purpose_code in ('SCREENING','DOC_AUTHENTICITY','REGISTRY_LOOKUP','BANK_DATA','GOAML_FILING')]') = 5);
    ok('the 3 KYC flexfields are registered',
       cnt(q'[select count(*) from xxfnd_df_flexfields where descriptive_flexfield_code in
              ('XXCMP_PARTIES_DFF','XXCMP_PARTY_CONTACTS_DFF','XXCMP_PARTY_REL_DFF')]') = 3);
    ok('the alert notification template is KYC''s',
       cnt(q'[select count(*) from xxfnd_notification_templates where template_code = 'KYC_ALERT' and application_code = 'KYC']') = 1);
    ok('the KYC configuration tables are registered (9)',
       cnt(q'[select count(*) from xxfnd_config_tables where table_name in ('XXCMP_QUESTIONNAIRES','XXCMP_QUESTIONS',
              'XXCMP_ANSWER_OPTIONS','XXCMP_CONCLUSION_TEMPLATES','XXCMP_APPROVAL_MATRIX','XXCMP_ATTACHMENT_RULES',
              'XXCMP_RISK_FACTORS','XXCMP_RISK_COUNTRIES','XXCMP_RISK_TIERS')]') = 9);
    ok('the request, case and RFI approval types have rules',
       cnt(q'[select count(distinct approval_type_code) from xxfnd_approval_rules
               where approval_type_code in ('KYC_REQUEST','KYC_CASE','CASE_RFI')]') = 3);
    ok('no endpoint row is seeded (COMMON 86 retired the table)',
       cnt(q'[select count(*) from all_objects where object_name = 'XXFND_INTEGRATION_ENDPOINTS']') = 0);

    ok('no synonym points to a removed COMMON object',
       cnt(q'[select count(*) from user_synonyms s where s.table_owner = 'XXFUSION'
               and not exists (select 1 from all_objects o where o.owner = s.table_owner and o.object_name = s.table_name)]') = 0);
    ok('no synonym for the removed packages (XXFND_TASK_PKG, XXFND_AUTH_PKG, XXFND_SECURITY_PKG)',
       cnt(q'[select count(*) from user_synonyms where synonym_name in ('XXFND_TASK_PKG','XXFND_AUTH_PKG','XXFND_SECURITY_PKG',
              'XXFND_WORKFLOW_SWITCH_PKG','XXFND_ADMIN_SCOPE_PKG','XXFND_COMMUNICATION_PKG','XXFND_CONFIG_APPROVAL_PKG')]') = 0);
    ok('no invalid object in the KYC schema',
       cnt(q'[select count(*) from user_objects where status <> 'VALID' and object_name not like 'BIN$%']') = 0);

    ok('KYC has no task-deadlines or Fusion HCM automation (COMMON runs them)',
       cnt('select count(*) from apex_appl_automations where application_id = ' || l_app
           || q'[ and static_id in ('task-deadlines','fusion-hcm-sync')]') = 0);
    ok('the KYC monitoring automation is there',
       cnt('select count(*) from apex_appl_automations where application_id = ' || l_app
           || q'[ and static_id = 'kyc-monitoring']') = 1);

    -- party merge: the duplicate's document moves to the kept party (as OFFICER1, who may manage parties; needs
    -- security_test.sql first)
    apex_session.create_session(l_app, 1, 'OFFICER1');
    insert into xxcmp_parties (party_type, party_name, enabled_flag)
    values ('ORGANIZATION', 'K87 test kept ' || to_char(systimestamp, 'yyyymmddhh24missff3'), 'Y') returning party_id into l_into;
    insert into xxcmp_parties (party_type, party_name, enabled_flag)
    values ('ORGANIZATION', 'K87 test duplicate ' || to_char(systimestamp, 'yyyymmddhh24missff3'), 'Y') returning party_id into l_from;
    l_doc := xxfnd_attach_pkg.add_text('XXCMP_PARTIES', to_char(l_from), 'NOTE', 'LONG_TEXT', 'K87 test note', 'moved by the merge');
    xxcmp_party_pkg.merge_parties(l_from, l_into, 'K87 test merge');
    select count(*) into l_n from xxfnd_attached_documents
     where entity_name = 'XXCMP_PARTIES' and pk1_value = to_char(l_into) and attached_document_id = l_doc;
    ok('a merge moves the duplicate''s document to the kept party (COMMON MOVE_DOCUMENTS)', l_n = 1);
    commit;
    apex_session.delete_session;
exception
    when others then
        dbms_output.put_line('FAIL unexpected: ' || sqlerrm || ' ' || dbms_utility.format_error_backtrace);
        rollback;
end;
/
