--------------------------------------------------------------------------------
-- 10.2 Roles, templates, flexfields, attachments, workflow, KYC rules
--------------------------------------------------------------------------------
declare
    -- Variables must precede the local subprograms.

    procedure role(p_code in varchar2, p_name in varchar2, p_desc in varchar2, p_sensitive in varchar2 default 'N') is
    begin
        merge into xxfnd_roles t using (select p_code role_code from dual) s on (t.role_code = s.role_code)
         -- insert only: administrators maintain roles on the Roles and Privileges screen
         when not matched then insert (role_code, application_code, application_id, role_name, description, view_sensitive_flag)
                               values (p_code, 'KYC', (select application_id from xxfnd_applications where application_code = 'KYC'),
                                       p_name, p_desc, p_sensitive);
    end role;

    procedure vset(p_code in varchar2, p_name in varchar2, p_validation in varchar2, p_format in varchar2,
                   p_size in number default null, p_lookup in varchar2 default null) is
    begin
        merge into xxfnd_value_sets t using (select p_code value_set_code from dual) s
           on (t.value_set_code = s.value_set_code)
         -- insert only: administrators maintain value sets on the Flexfields screen
         when not matched then insert (value_set_code, value_set_name, validation_type, format_type, maximum_size, lookup_type)
                               values (p_code, p_name, p_validation, p_format, p_size, p_lookup);
    end vset;

    procedure dff(p_code in varchar2, p_name in varchar2, p_table in varchar2, p_pk in varchar2,
                  p_reference in varchar2 default null, p_selectable in varchar2 default 'N') is
    begin
        merge into xxfnd_df_flexfields t using (select p_code descriptive_flexfield_code from dual) s
           on (t.descriptive_flexfield_code = s.descriptive_flexfield_code)
         -- insert only: administrators maintain flexfields on the Flexfields screen
         when not matched then insert (descriptive_flexfield_code, application_code, table_name, pk_column_name,
                                       context_reference_column, context_user_selectable_flag)
                               values (p_code, case when p_table like 'XXCMP%' then 'KYC' end, p_table, p_pk,
                                       p_reference, p_selectable);
        merge into xxfnd_df_flexfields_tl t
        using (select p_code descriptive_flexfield_code, 'en' language_code from dual) s
           on (t.descriptive_flexfield_code = s.descriptive_flexfield_code and t.language_code = s.language_code)
         when not matched then insert (descriptive_flexfield_code, language_code, flexfield_name)
                               values (p_code, 'en', p_name);
        -- Every DFF has a protected GLOBAL context.
        merge into xxfnd_df_contexts t
        using (select p_code descriptive_flexfield_code, 'GLOBAL' context_code from dual) s
           on (t.descriptive_flexfield_code = s.descriptive_flexfield_code and t.context_code = s.context_code)
         when not matched then insert (descriptive_flexfield_code, context_code, context_name, global_flag, protected_flag)
                               values (p_code, 'GLOBAL', 'Global Data Elements', 'Y', 'Y');
    end dff;

    procedure dff_context(p_dff in varchar2, p_code in varchar2, p_name in varchar2) is
    begin
        merge into xxfnd_df_contexts t
        using (select p_dff descriptive_flexfield_code, p_code context_code from dual) s
           on (t.descriptive_flexfield_code = s.descriptive_flexfield_code and t.context_code = s.context_code)
         when not matched then insert (descriptive_flexfield_code, context_code, context_name)
                               values (p_dff, p_code, p_name);
    end dff_context;

    procedure entity(p_name in varchar2, p_user_name in varchar2, p_table in varchar2, p_pk in varchar2,
                     p_enabled in varchar2 default 'Y') is
    begin
        merge into xxfnd_document_entities t using (select p_name entity_name from dual) s
           on (t.entity_name = s.entity_name)
         when matched then update set t.table_name = p_table, t.pk1_column = p_pk
         when not matched then insert (entity_name, application_code, table_name, pk1_column, enabled_flag)
                               values (p_name, 'KYC', p_table, p_pk, p_enabled);
        merge into xxfnd_document_entities_tl t
        using (select p_name entity_name, 'en' language_code from dual) s
           on (t.entity_name = s.entity_name and t.language_code = s.language_code)
         when not matched then insert (entity_name, language_code, user_entity_name) values (p_name, 'en', p_user_name);
    end entity;

    procedure category(p_code in varchar2, p_name in varchar2, p_datatype in varchar2 default 'FILE',
                       p_expiry in varchar2 default 'N', p_max_age in number default null, p_ar in varchar2 default null) is
    begin
        merge into xxfnd_document_categories t using (select p_code category_code from dual) s
           on (t.category_code = s.category_code)
         -- insert only: administrators maintain categories on the Attachments screen
         when not matched then insert (category_code, application_code, category_name, default_datatype_code,
                                       has_expiry_flag, max_age_days)
                               values (p_code, 'KYC', p_name, p_datatype, p_expiry, p_max_age);
        if p_ar is not null then
            merge into xxfnd_document_categories_tl t
            using (select p_code category_code, 'ar' language_code from dual) s
               on (t.category_code = s.category_code and t.language_code = s.language_code)
             when not matched then insert (category_code, language_code, category_name) values (p_code, 'ar', p_ar);
        end if;
    end category;

    procedure template(p_code in varchar2, p_subject in varchar2, p_body in clob) is
    begin
        merge into xxfnd_notification_templates t using (select p_code template_code from dual) s
           on (t.template_code = s.template_code)
         -- insert only: after install the wording belongs to the administrators
         when not matched then insert (template_code, application_code, subject, body_html)
                               values (p_code, 'KYC', p_subject, p_body);
    end template;

begin
    xxfnd_util_pkg.set_install_mode(true);
    ----------------------------------------------------------------------------
    -- Roles, SoD, first administrator
    ----------------------------------------------------------------------------
    role('REQUESTER',          'Requester',           'Raises KYC requests and answers requests for information.');
    role('COMPLIANCE_OFFICER', 'Compliance Officer',  'Investigates cases, raises RFIs, proposes the risk classification.', 'Y');
    role('COMPLIANCE_MANAGER', 'Compliance Manager',  'Approves cases and configuration changes (second pair of eyes).', 'Y');
    role('HEAD_OF_COMPLIANCE', 'Head of Compliance',  'Final approval for high-risk cases and SAR decisions.', 'Y');
    role('SYSTEM_ADMIN',       'System Administrator','Maintains users, roles and setup. Does not see case data.');

    merge into xxfnd_sod_rules t
    using (select 'COMPLIANCE_MANAGER' r1, 'COMPLIANCE_OFFICER' r2, 'SAME_RECORD' sc from dual
           union all select 'COMPLIANCE_OFFICER', 'REQUESTER', 'SAME_RECORD' from dual
           union all select 'HEAD_OF_COMPLIANCE', 'REQUESTER', 'SAME_RECORD' from dual) s
       on (t.role_code_1 = s.r1 and t.role_code_2 = s.r2 and t.conflict_scope = s.sc)
     when not matched then insert (role_code_1, role_code_2, conflict_scope, description)
                           values (s.r1, s.r2, s.sc, 'The same person may not perform both roles on one case.');

    ----------------------------------------------------------------------------
    -- Notification templates
    ----------------------------------------------------------------------------
    template('TASK_ASSIGNED', 'Action needed: #TASK_SUBJECT#',
        '<p>A task is waiting for you in the KYC Compliance Platform.</p><p><b>#TASK_SUBJECT#</b>'
        || '<br><b>Due:</b> #DUE_DATE#</p><p><a href="#TASK_URL#">Open My Tasks</a></p>');
    template('TASK_REMINDER', 'Reminder: #TASK_SUBJECT#',
        '<p>This task is due on #DUE_DATE# and is still open.</p><p><b>#TASK_SUBJECT#</b></p><p><a href="#TASK_URL#">Open My Tasks</a></p>');
    template('TASK_ESCALATED', 'Overdue task escalated: #TASK_SUBJECT#',
        '<p>This task was due on #DUE_DATE# and is still open. It is escalated to you.</p>'
        || '<p><b>#TASK_SUBJECT#</b><br><b>Assigned to:</b> #ASSIGNEES#</p><p><a href="#TASK_URL#">Open the Workflow Monitor</a></p>');
    template('RFI_RAISED_INTERNAL', 'Information requested: #RFI_NUMBER#',
        '<p>The Compliance team needs more information for #RFI_NUMBER#.</p><p>#DESCRIPTION#</p>'
        || '<p>Please reply by #DUE_DATE# from the KYC Compliance Platform.</p>');
    template('RFI_RAISED_EXTERNAL', 'Information requested: #RFI_NUMBER#',
        '<p>Dear #CONTACT_NAME#,</p><p>To complete our due diligence we need the following information:</p>'
        || '<p>#DESCRIPTION#</p><p>Please respond by #DUE_DATE# using this secure link: <a href="#RESPONSE_URL#">#RESPONSE_URL#</a></p>');
    template('RFI_RESPONDED', 'Response received: #RFI_NUMBER#',
        '<p>A response has been received for #RFI_NUMBER#. Review it in the KYC Compliance Platform.</p>');
    template('CONFIG_CHANGE_PENDING', 'Configuration change awaiting approval',
        '<p>#CHANGE_TYPE# was changed by #SUBMITTED_BY# and needs a second person''s approval.</p>'
        || '<p>#CHANGE_SUMMARY#</p>');

    ----------------------------------------------------------------------------
    -- Value sets and descriptive flexfields
    ----------------------------------------------------------------------------
    vset('XXFND_CHAR_150',  'Free text (150)',        'NONE', 'CHAR', 150);
    vset('XXFND_CHAR_30',   'Free text (30)',         'NONE', 'CHAR', 30);
    vset('XXFND_NUMBER',    'Number',                 'NONE', 'NUMBER');
    vset('XXFND_DATE',      'Date',                   'NONE', 'DATE');
    vset('XXFND_TIMESTAMP', 'Date and time',          'NONE', 'TIMESTAMP');
    vset('XXFND_YES_NO',    'Yes / No',               'INDEPENDENT', 'CHAR', 1, 'YES_NO');
    vset('XXFND_JURISDICTION', 'Jurisdiction',        'INDEPENDENT', 'CHAR', 30, 'JURISDICTION');

    -- Context follows the row's own type column (EBS reference field), so an
    -- administrator can add PERSON-only or ORGANIZATION-only fields.
    dff('XXCMP_PARTIES_DFF',        'Party Additional Information',        'XXCMP_PARTIES',             'PARTY_ID', 'PARTY_TYPE');
    dff_context('XXCMP_PARTIES_DFF', 'ORGANIZATION', 'Organization');
    dff_context('XXCMP_PARTIES_DFF', 'PERSON', 'Person');
    dff('XXCMP_PARTY_CONTACTS_DFF', 'Party Contact Additional Information','XXCMP_PARTY_CONTACTS',      'PARTY_CONTACT_ID');
    dff('XXCMP_PARTY_REL_DFF',      'Relationship Additional Information', 'XXCMP_PARTY_RELATIONSHIPS', 'PARTY_RELATIONSHIP_ID');
    -- EBS: attached-document DFF context follows the document category.
    dff('XXFND_ATTACHED_DOCS_DFF',  'Attachment Additional Information',   'XXFND_ATTACHED_DOCUMENTS',  'ATTACHED_DOCUMENT_ID', 'CATEGORY_CODE');

    ----------------------------------------------------------------------------
    -- Attachments: entities, categories, page registrations, storage
    ----------------------------------------------------------------------------
    entity('XXCMP_PARTIES',  'Party',                       'XXCMP_PARTIES',  'PARTY_ID');
    entity('XXCMP_RFIS',     'Request for Information',     'XXCMP_RFIS',     'RFI_ID');
    -- Module 1 table; registered now so the KYC case workflow item type can refer to it.
    entity('XXCMP_REQUESTS', 'KYC Request',                 'XXCMP_REQUESTS', 'REQUEST_ID', 'N');

    category('TRADE_LICENSE',      'Trade / Commercial Licence',     p_expiry => 'Y', p_ar => 'الرخصة التجارية');
    category('CERT_INCORPORATION', 'Certificate of Incorporation',   p_ar => 'شهادة التأسيس');
    category('MOA_AOA',            'Memorandum / Articles of Association', p_ar => 'عقد التأسيس والنظام الأساسي');
    category('SHAREHOLDER_REGISTER','Shareholder Register');
    category('OWNERSHIP_CHART',    'Ownership Structure Chart');
    category('BOARD_RESOLUTION',   'Board Resolution / Power of Attorney');
    category('PASSPORT',           'Passport',                       p_expiry => 'Y', p_ar => 'جواز السفر');
    category('NATIONAL_ID',        'National ID',                    p_expiry => 'Y', p_ar => 'الهوية الوطنية');
    category('PROOF_OF_ADDRESS',   'Proof of Address',               p_max_age => 90, p_ar => 'إثبات العنوان');
    category('BANK_REFERENCE',     'Bank Reference Letter',          p_max_age => 90);
    category('FINANCIAL_STATEMENTS','Financial Statements');
    category('SOURCE_OF_FUNDS',    'Source of Funds / Wealth Evidence');
    category('SCREENING_RESULT',   'Screening Result');
    category('RFI_RESPONSE',       'RFI Response Document');
    category('OTHER',              'Other Document', p_ar => 'مستند آخر');
    category('NOTE',               'Note',            p_datatype => 'LONG_TEXT');
    category('WEB_LINK',           'Web Link',        p_datatype => 'WEB_PAGE');

    merge into xxfnd_attachment_functions t
    using (select 'KYC_PARTY' function_code, 'Party' function_name, 21 page_id from dual
           union all select 'KYC_RFI', 'Request for Information', 31 from dual) s
       on (t.function_code = s.function_code)
     when matched then update set t.apex_page_id = s.page_id
     when not matched then insert (function_code, application_code, function_name, apex_app_alias, apex_page_id)
                           values (s.function_code, 'KYC', s.function_name, 'KYC', s.page_id);
    merge into xxfnd_attachment_blocks t
    using (select 'KYC_PARTY' function_code, 'ATTACHMENTS' block_code, 'party_attachments' region from dual
           union all select 'KYC_RFI', 'ATTACHMENTS', 'rfi_attachments' from dual) s
       on (t.function_code = s.function_code and t.block_code = s.block_code)
     when not matched then insert (function_code, block_code, region_static_id, block_name, display_sequence)
                           values (s.function_code, s.block_code, s.region, 'Attachments', 10);
    merge into xxfnd_attachment_blk_entities t
    using (select 'KYC_PARTY' function_code, 'ATTACHMENTS' block_code, 'XXCMP_PARTIES' entity_name, 'P21_PARTY_ID' item, 'N' del from dual
           union all select 'KYC_RFI', 'ATTACHMENTS', 'XXCMP_RFIS', 'P31_RFI_ID', 'N' from dual) s
       on (t.function_code = s.function_code and t.block_code = s.block_code and t.entity_name = s.entity_name)
     when not matched then insert (function_code, block_code, entity_name, pk1_page_item, delete_allowed_flag, display_sequence)
                           values (s.function_code, s.block_code, s.entity_name, s.item, s.del, 10);

    merge into xxfnd_integration_endpoints t
    using (select 'UCM_MAIN' code, 'Oracle WebCenter Content' name, 'UCM' etype,
                  'https://your-ucm-host.example.com' url, 'XXFND_UCM_CRED' cred,
                  cast(null as varchar2(1000)) token_url, cast(null as varchar2(1000)) scope from dual
           union all
           select 'SHAREPOINT_MAIN', 'Microsoft SharePoint (Graph)', 'SHAREPOINT',
                  'https://graph.microsoft.com/v1.0', 'XXFND_GRAPH_CRED',
                  'https://login.microsoftonline.com/your-tenant-id/oauth2/v2.0/token',
                  'https://graph.microsoft.com/.default' from dual) s
       on (t.endpoint_code = s.code)
     when not matched then insert (endpoint_code, endpoint_name, endpoint_type, base_url, web_credential_static_id,
                                   oauth_token_url, oauth_scope, status_code)
                           values (s.code, s.name, s.etype, s.url, s.cred, s.token_url, s.scope, 'REGISTERED');

    -- Default store: disabled until an administrator sets the real host and activates the endpoint.
    merge into xxfnd_storage_config t
    using (select 1 x from dual) s
       on (t.entity_name is null and t.category_code is null)
     when not matched then insert (storage_type, endpoint_code, folder_path_template, ucm_security_group,
                                   ucm_doc_type, enabled_flag)
                           values ('UCM', 'UCM_MAIN', '/KYC/#ENTITY_NAME#/#PK1_VALUE#', 'Public', 'Document', 'N');

    merge into xxfnd_integration_purposes t
    using (select 'SCREENING' code, 'Sanctions / PEP / adverse media screening' name, cast(null as varchar2(30)) ep, 'MANUAL' cm from dual
           union all select 'DOC_AUTHENTICITY', 'Document authenticity check', null, 'MANUAL' from dual
           union all select 'REGISTRY_LOOKUP', 'Company registry lookup', null, 'MANUAL' from dual
           union all select 'DOCUMENT_STORAGE', 'Document storage', 'UCM_MAIN', 'API' from dual) s
       on (t.purpose_code = s.code)
     when not matched then insert (purpose_code, application_code, purpose_name, endpoint_code, capture_method, approval_status)
                           values (s.code, 'KYC', s.name, s.ep, s.cm, 'APPROVED');

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

    merge into xxfnd_retention_policies t
    using (select 'XXCMP_PARTIES' tn from dual) s
       on (t.table_name = s.tn and t.jurisdiction is null)
     when not matched then insert (table_name, retention_years, action_at_expiry) values (s.tn, 5, 'FLAG_FOR_REVIEW');
    -- release 76 (S-01): the other tables with personal data, as the parties (5 years, flagged for review - nothing is
    -- deleted); Compliance / Legal set the final years and action on the Retention screen
    merge into xxfnd_retention_policies t
    using (select column_value tn from table(apex_t_varchar2('XXFND_COMMUNICATIONS', 'XXCMP_PARTY_ID_VERIFICATIONS',
                                                            'XXCMP_PARTY_REGISTRY_CHECKS', 'XXCMP_CASE_FUNDS',
                                                            'XXCMP_FIU_REPORTS'))) s
       on (t.table_name = s.tn and t.jurisdiction is null)
     when not matched then insert (table_name, retention_years, action_at_expiry, application_code)
                           values (s.tn, 5, 'FLAG_FOR_REVIEW', 'KYC');

    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/

--------------------------------------------------------------------------------
-- First administrator when installed from APEX Supporting Objects: the
-- developer running the install. They grant further access in the application.
--------------------------------------------------------------------------------
declare
    l_user  varchar2(255);
    l_name  varchar2(240);
    l_email varchar2(320);
begin
    l_user := sys_context('APEX$SESSION', 'APP_USER');
    begin
        execute immediate q'[
            select max(trim(u.first_name || ' ' || u.last_name)), max(u.email)
              from apex_workspace_apex_users u
             where upper(u.user_name) = upper(:1)]'
            into l_name, l_email using l_user;
    exception
        when others then
            null;
    end;
    xxfnd_util_pkg.set_install_mode(true);
    if l_user is not null then
        xxfnd_security_pkg.bootstrap_admin(l_user, l_name, l_email);
    else
        -- Installed without an APEX session (e.g. SQLcl apex import): the workspace
        -- administrators performing the install become the first SYSTEM_ADMINs.
        for a in (select user_name, trim(first_name || ' ' || last_name) full_name, email
                    from apex_workspace_apex_users
                   where is_admin = 'Yes' and nvl(account_locked, 'No') = 'No') loop
            xxfnd_security_pkg.bootstrap_admin(a.user_name, a.full_name, a.email);
        end loop;
    end if;
    xxfnd_util_pkg.set_install_mode(false);
    commit;
end;
/
