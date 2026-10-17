--------------------------------------------------------------------------------
-- 18h KYC registers itself in COMMON (release 87). KYC only (XXCUS); install and every upgrade.
--   Everything KYC needs in the shared setup is registered through COMMON's registration routines (COMMON
--   release 86): roles and segregation of duties, features, privileges and pages, lookups, value sets and
--   flexfields, document entities, categories and attachment pages, integration purposes, the alert template,
--   data access rules, task deadlines and the configuration tables. KYC writes no COMMON table itself.
--   Each routine adds only what is missing and keeps what an administrator changed, so a re-run does nothing.
--   Before: KYC is registered in COMMON (script 03 stops otherwise); after: the KYC tables exist (04, 16*).
--   Not registered here, because COMMON owns them: the shared notification templates (TASK_*, RFI_*,
--   CONFIG_CHANGE_PENDING), the shared lookups and the document storage (database until COMMON's administrator
--   sets up a server for KYC).
--   First-install grants: only while the old release markers are missing (R10, R13, R14), as before - a privilege
--   taken away in COMMON's console is not given back by an upgrade.
-- Idempotent.
--------------------------------------------------------------------------------
declare
    c_app   constant varchar2(30)  := 'KYC';
    c_staff constant varchar2(200) := 'COMPLIANCE_OFFICER,COMPLIANCE_MANAGER,HEAD_OF_COMPLIANCE';
    c_all   constant varchar2(200) := 'REQUESTER,COMPLIANCE_OFFICER,COMPLIANCE_MANAGER,HEAD_OF_COMPLIANCE,SYSTEM_ADMIN';
    c_amp   constant varchar2(1)   := chr(38);   -- no literal ampersand: script runners substitute it

    -- a lookup type and its values: 'CODE=Meaning|CODE=Meaning=TAG'
    procedure lookups(p_type in varchar2, p_meaning in varchar2, p_level in varchar2, p_values in varchar2) is
        l_parts apex_t_varchar2;
        l_seq   pls_integer := 0;
    begin
        xxfnd_lookup_pkg.register_lookup_type(c_app, p_type, p_meaning, p_level);
        for v in (select column_value item from table(apex_string.split(p_values, '|'))) loop
            l_seq   := l_seq + 10;
            l_parts := apex_string.split(v.item, '=');
            xxfnd_lookup_pkg.register_lookup_value(c_app, p_type, l_parts(1), l_parts(2), l_seq,
                                                   p_tag => case when l_parts.count > 2 then l_parts(3) end);
        end loop;
    end lookups;

    procedure lookup_value(p_type in varchar2, p_code in varchar2, p_meaning in varchar2, p_seq in number,
                           p_ar in varchar2 default null, p_tag in varchar2 default null) is
    begin
        xxfnd_lookup_pkg.register_lookup_value(c_app, p_type, p_code, p_meaning, p_seq, p_tag => p_tag, p_meaning_ar => p_ar);
    end lookup_value;

    -- KYC pages of a feature
    procedure pages(p_feature in varchar2, p_pages in varchar2) is
        l_parts apex_t_varchar2;
        l_tab   pls_integer := 0;
    begin
        for p in (select column_value item from table(apex_string.split(p_pages, '|'))) loop
            l_parts := apex_string.split(p.item, '=');
            if l_parts.count > 1 then
                l_tab := l_tab + 10;
                xxfnd_privilege_pkg.register_feature_page(c_app, p_feature, to_number(l_parts(1)), l_parts(2), l_tab);
            else
                xxfnd_privilege_pkg.register_feature_page(c_app, p_feature, to_number(l_parts(1)));
            end if;
        end loop;
    end pages;

    -- a feature, its privileges (actions 'VIEW,CREATE,MANAGE') and its pages ('page' or 'page=Tab label', in tab order)
    procedure feature(p_code in varchar2, p_name in varchar2, p_group in varchar2, p_seq in number, p_admin in varchar2,
                      p_actions in varchar2, p_home in number default null, p_icon in varchar2 default null,
                      p_description in varchar2 default null, p_pages in varchar2 default null) is
    begin
        xxfnd_privilege_pkg.register_feature(c_app, p_code, p_name, p_group, p_seq, p_admin, p_home, p_icon, p_description);
        for a in (select column_value action from table(apex_string.split(p_actions, ','))) loop
            xxfnd_privilege_pkg.register_privilege(c_app, p_code, a.action);
        end loop;
        if p_pages is not null then
            pages(p_code, p_pages);
        end if;
    end feature;

    -- every privilege in the list to every role in the list (additive)
    procedure grant_to(p_roles in varchar2, p_privileges in varchar2) is
    begin
        for r in (select column_value role_code from table(apex_string.split(p_roles, ','))) loop
            for p in (select column_value privilege_code from table(apex_string.split(p_privileges, ','))) loop
                xxfnd_privilege_pkg.add_role_privilege(c_app, r.role_code, p.privilege_code);
            end loop;
        end loop;
    end grant_to;

    procedure rule(p_roles in varchar2, p_table in varchar2, p_type in varchar2, p_column in varchar2 default null) is
    begin
        for r in (select column_value role_code from table(apex_string.split(p_roles, ','))) loop
            xxfnd_vpd_pkg.register_data_rule(c_app, r.role_code, p_table, p_type, p_column);
        end loop;
    end rule;

    procedure attachment_page(p_function in varchar2, p_name in varchar2, p_page in number, p_block in varchar2,
                              p_region in varchar2, p_block_name in varchar2, p_entity in varchar2, p_item in varchar2,
                              p_delete in varchar2) is
    begin
        xxfnd_attach_pkg.register_attachment_page(c_app, p_function, p_name, p_page, p_block, p_region, p_entity, p_item,
                                                  p_block_name, p_delete_allowed_flag => p_delete);
    end attachment_page;
begin
    xxfnd_util_pkg.set_install_mode(true);

    ----------------------------------------------------------------------------
    -- Roles and segregation of duties
    ----------------------------------------------------------------------------
    xxfnd_privilege_pkg.register_role(c_app, 'REQUESTER', 'Requester', 'Raises KYC requests and answers requests for information.');
    xxfnd_privilege_pkg.register_role(c_app, 'COMPLIANCE_OFFICER', 'Compliance Officer',
        'Investigates cases, raises RFIs, proposes the risk classification.', 'Y');
    xxfnd_privilege_pkg.register_role(c_app, 'COMPLIANCE_MANAGER', 'Compliance Manager',
        'Approves cases and configuration changes (second pair of eyes).', 'Y');
    xxfnd_privilege_pkg.register_role(c_app, 'HEAD_OF_COMPLIANCE', 'Head of Compliance',
        'Final approval for high-risk cases and SAR decisions.', 'Y');
    xxfnd_privilege_pkg.register_role(c_app, 'SYSTEM_ADMIN', 'System Administrator',
        'Maintains the KYC setup. Does not see case data.');
    for s in (select column_value pair from table(apex_t_varchar2('COMPLIANCE_MANAGER,COMPLIANCE_OFFICER',
                                                                  'COMPLIANCE_OFFICER,REQUESTER',
                                                                  'HEAD_OF_COMPLIANCE,REQUESTER'))) loop
        xxfnd_privilege_pkg.register_sod_rule(c_app, regexp_substr(s.pair, '[^,]+', 1, 1), regexp_substr(s.pair, '[^,]+', 1, 2),
                                              'SAME_RECORD', 'The same person may not perform both roles on one case.');
    end loop;

    ----------------------------------------------------------------------------
    -- Features, privileges and pages
    ----------------------------------------------------------------------------
    -- release 88: KYC has no copy of a COMMON screen (attachments 90/91, feedback 10050 are COMMON's pages 47/48, 173)
    feature('HOME',            'Home',                 'BUSINESS', 10, 'N', 'VIEW', p_pages => '1|10010');
    feature('KYC_REQUESTS',    'KYC Requests',         'BUSINESS', 30, 'N', 'VIEW,CREATE,MANAGE',
            p_pages => '200|201|202|203|204|205|206');
    feature('PARTIES',         'Parties',              'BUSINESS', 40, 'N', 'VIEW,CREATE,MANAGE',
            p_pages => '20|21|22|23|24|25|26|27');
    -- release 88: the RFI pages 32 and 34 are gone (information requests are COMMON's, release 89)
    feature('CASES',           'Cases',                'BUSINESS', 50, 'N', 'VIEW,CREATE,MANAGE',
            p_pages => '210|211|213|214|215|216|217|218|219');
    feature('CASE_ASSIGNMENT', 'Case Assignment',      'BUSINESS', 55, 'N', 'MANAGE');
    feature('MONITORING',      'Monitoring Watchlist', 'BUSINESS', 60, 'N', 'VIEW,MANAGE',
            p_pages => '220=Watchlist|221=Alerts|222');
    feature('DASHBOARD',       'Executive Dashboard',  'BUSINESS', 70, 'N', 'VIEW', p_pages => '230');
    -- release 87: the mandatory document rules (138, 139) and the SAR gate (165) are KYC rules
    feature('KYC_RULES',       'KYC Rules',            'BASIC_SETUP', 130, 'Y', 'VIEW,CREATE,MANAGE', 160,
            'fa-question-circle-o', 'Questionnaires, scoring, conclusion templates, mandatory documents, the SAR gate and the risk model.',
            '160=Questionnaires|163=Conclusion Templates|167=Risk Model|138=Mandatory Documents|165=SAR Gate|161|162|164|139');
    feature('ALERT_RULES',     'Alert Rules',          'WORKFLOW_INTEGRATION', 220, 'Y', 'VIEW,CREATE,MANAGE', 225,
            'fa-bell-o', 'What the monitoring watches, who is alerted and when a review starts by itself.', '225|226');
    -- release 88: KYC's copies of COMMON's shared screens are removed (My Tasks, Workflow Monitor, Application Settings,
    -- Usage and Feedback, RFI pages 30/31): KYC registers no page of a COMMON feature; the menu links to COMMON's pages.
    -- Rows registered by an earlier release stay (no data deleted; COMMON has no routine to retire a page row) and show
    -- nowhere: KYC's menus list only pages the application has (XXFND_APPLICATION_PKG.LOCAL_PAGE).

    ----------------------------------------------------------------------------
    -- Lookups (KYC's own; the shared ones are COMMON's)
    ----------------------------------------------------------------------------
    lookups('ENTITY_TYPE', 'Legal Entity Types', 'E',
        'LLC=Limited Liability Company|PJSC=Public Joint Stock Company|PRJSC=Private Joint Stock Company'
        || '|SOLE_EST=Sole Establishment|BRANCH=Branch of Foreign Company|FREE_ZONE=Free Zone Entity'
        || '|PARTNERSHIP=Partnership|TRUST=Trust or Foundation|NON_PROFIT=Non-Profit Organisation'
        || '|GOVERNMENT=Government Entity|OTHER=Other');
    xxfnd_lookup_pkg.register_lookup_type(c_app, 'PARTY_TYPE', 'Party Types', 'S');
    lookup_value('PARTY_TYPE', 'ORGANIZATION', 'Organization', 10, 'منشأة');
    lookup_value('PARTY_TYPE', 'PERSON', 'Person', 20, 'فرد');
    lookups('CONTACT_TYPE', 'Contact Types', 'E', 'EMAIL=Email|PHONE=Phone|MOBILE=Mobile|ADDRESS=Address|WEBSITE=Website');
    lookups('RELATIONSHIP_TYPE', 'Party Relationship Types', 'E',
        'SHAREHOLDER=Shareholder|DIRECTOR=Director|MANAGER=Manager'
        || '|AUTHORISED_SIGNATORY=Authorised Signatory|PARENT_COMPANY=Parent Company|BENEFICIAL_OWNER=Beneficial Owner'
        || '|TRUSTEE=Trustee|SETTLOR=Settlor|BENEFICIARY=Beneficiary|OTHER=Other');
    lookups('DATA_PROVENANCE', 'Data Provenance', 'S', 'SELF_DECLARED=Self-declared|REGISTRY_VERIFIED=Registry verified');
    lookups('UBO_STATUS', 'UBO Determination', 'S', 'UBO=Ultimate beneficial owner|NOT_UBO=Not a UBO|NOT_YET_ASSESSED=Not yet assessed');
    lookups('DUE_DILIGENCE_TYPE', 'Due Diligence Types', 'S', 'SIMPLIFIED=Simplified KYC|STANDARD=Standard KYC|ENHANCED=Enhanced KYC');
    -- review interval per risk tier, in months (TAG), until an administrator sets another
    xxfnd_lookup_pkg.register_lookup_type(c_app, 'RISK_TIER', 'Risk Tiers', 'S');
    lookup_value('RISK_TIER', 'LOW', 'Low', 10, 'منخفض', '36');
    lookup_value('RISK_TIER', 'MEDIUM', 'Medium', 20, 'متوسط', '24');
    lookup_value('RISK_TIER', 'HIGH', 'High', 30, 'مرتفع', '12');
    lookups('QA_ANSWER_TYPE', 'Question Answer Types', 'S',
        'SINGLE_SELECT=Single choice|MULTI_SELECT=Multiple choice|YES_NO=Yes / No|TEXT=Text|NUMBER=Number|DATE=Date');
    lookups('QUESTIONNAIRE_AUDIENCE', 'Questionnaire Audience', 'S', 'REQUESTER=Requester (scored)|OFFICER=Compliance Officer (unscored)');
    lookups('RFI_CATEGORY', 'RFI Categories', 'E',
        'MISSING_DOCUMENT=Missing document|CLARIFICATION=Clarification|OWNERSHIP=Ownership and control'
        || '|SOURCE_OF_FUNDS=Source of funds or wealth|OTHER=Other');
    lookups('RFI_RECIPIENT_TYPE', 'RFI Recipient Types', 'S',
        'REQUESTING_DEPARTMENT=Requesting department|EXTERNAL_PARTY=External party'
        || '|USER=User (answers in My Tasks)|EXTERNAL=External person (answers through the e-mailed link)');
    lookups('RFI_STATUS', 'RFI Status', 'S',
        'WAITING_FOR_INFORMATION=Waiting for information|ON_HOLD_PENDING=On hold - pending'
        || '|ON_HOLD_INVESTIGATION=On hold - investigation|RESOLVED=Resolved|REJECTED_RETURNED=Rejected / returned'
        || '|CANCELLED=Cancelled|RESPONDED=Answered - waiting for review');
    lookups('REGISTRATION_TYPE', 'Registration Types', 'S',
        'COMMERCIAL_REGISTRATION=Commercial Registration|TRADE_LICENCE=Trade Licence|TAX_NUMBER=Tax / VAT Number|OTHER=Other');
    lookups('BUSINESS_RELATIONSHIP', 'Business Relationships', 'S',
        'CUSTOMER=Customer|VENDOR=Vendor / Supplier|PARTNER=Partner|AGENT=Agent / Intermediary|OTHER=Other');
    -- the sections of the case screen (labels; codes fixed in XXCMP_CASE_PKG.C_SECTIONS)
    lookups('CASE_SECTION', 'Case Screen Sections', 'S',
        'SUMMARY=Summary|PARTY=Party|TREE=Ownership Tree|SCREENING=Screening|DOCUMENTS=Documents|RISK=Risk Assessment'
        || '|NOTES=Notes and RFIs|REVIEW=Review and Submit');
    lookups('KYC_REQUEST_TYPE', 'KYC Request Types', 'S',
        'NEW_ONBOARDING=New onboarding|PERIODIC_REVIEW=Periodic review|EVENT_TRIGGERED_REVIEW=Event-triggered review');
    lookups('KYC_TRIGGER_SOURCE', 'KYC Request Trigger Sources', 'S', 'MANUAL=Manual|SCHEDULED=Scheduled|EVENT_DRIVEN=Event driven');
    lookups('KYC_REQUEST_STATUS', 'KYC Request Status', 'S',
        'DRAFT=Draft|IN_PROGRESS=In Progress|INFO_NEEDED=Pending Information|APPROVED=Approved|REJECTED=Rejected|CANCELLED=Cancelled');
    lookups('PARTY_STATUS', 'Party Status', 'S', 'PENDING=Pending|APPROVED=Approved|REJECTED=Rejected|CANCELLED=Cancelled');
    lookups('ID_DOCUMENT_TYPE', 'Identity Document Types', 'E',
        'PASSPORT=Passport|NATIONAL_ID=National ID card|RESIDENCE_PERMIT=Residence permit');
    lookups('REQUEST_MATCH_STATUS', 'Counterparty Match Status', 'S',
        'SELECTED=Existing party chosen|NEW=New party|PENDING=Possible match - Compliance to decide'
        || '|MERGED=Merged into an existing party|CONFIRMED_NEW=Confirmed as a new party');
    lookups('KYC_INTAKE_OUTCOME', 'KYC Intake Outcomes', 'S',
        'NOT_REQUIRED=KYC not required|AUTO_APPROVED=Auto-approved|ASSIGNED=Assigned to Compliance');
    lookups('CASE_STATUS', 'Case Status', 'S',
        'INVESTIGATION=Under investigation|PENDING_APPROVAL=Pending approval|PENDING_INFORMATION=Pending information'
        || '|APPROVED=Approved|REJECTED=Rejected|CANCELLED=Cancelled');
    lookups('SCREENING_TYPE', 'Screening Types', 'S',
        'REGISTRY=Registry check|SANCTIONS=Sanctions|PEP=Politically exposed person|ADVERSE_MEDIA=Adverse media');
    lookups('SCREENING_MATCH_STATUS', 'Screening Match Status', 'S',
        'NO_MATCH=No match|POTENTIAL_MATCH=Potential match|CONFIRMED_MATCH=Confirmed match|FALSE_POSITIVE=False positive');
    lookups('DOC_VERIFICATION_STATUS', 'Document Verification Status', 'S', 'VERIFIED=Verified|REJECTED=Rejected|EXPIRED=Expired');
    lookups('UBO_BASIS', 'Beneficial Ownership Basis', 'S',
        'OWNERSHIP=Ownership|CONTROL=Control|FALLBACK=Fallback (senior managing official)');
    lookups('REQUESTING_DEPARTMENT', 'Requesting Departments', 'E',
        'FINANCE=Finance|PROCUREMENT=Procurement|SALES=Sales|TREASURY=Treasury|LEGAL=Legal|OTHER=Other');
    -- parameters administrators maintain in Lookups (value in TAG)
    lookups('KYC_PARAMETER', 'KYC Parameters', 'E',
        'CASE_SLA_DAYS=Case investigation SLA (days)=10|PEP_REVIEW_MONTHS=Review interval for PEP parties (months)=12'
        || '|REVIEW_LEAD_DAYS=Show upcoming reviews this many days ahead=30');
    lookups('ID_VERIFICATION_METHOD', 'ID Verification Methods', 'S',
        'ORIGINAL_SEEN=Original seen in person|CERTIFIED_COPY=Certified copy|VIDEO_CALL=Video call'
        || '|GOVERNMENT_PORTAL=Government portal checked by hand');
    lookups('ID_VERIFICATION_RESULT', 'ID Verification Results', 'S', 'VERIFIED=Verified|NOT_VERIFIED=Not verified|INCONCLUSIVE=Inconclusive');
    lookups('REGISTRY_CHECK_RESULT', 'Registry Check Results', 'S',
        'MATCH=Matches the party record|MISMATCH=Differs from the party record|NOT_FOUND=Not found in the registry');
    lookups('REGISTRATION_STATUS', 'Registry Statuses', 'S',
        'ACTIVE=Active|SUSPENDED=Suspended|IN_LIQUIDATION=In liquidation|DISSOLVED=Dissolved|UNKNOWN=Unknown');
    lookups('RISK_COUNTRY_LIST', 'Risk Country Lists', 'S',
        'FATF_BLACK=FATF black list (call for action)|FATF_GREY=FATF grey list (increased monitoring)|INTERNAL=Company high-risk list');
    lookups('RISK_FACTOR_TYPE', 'Risk Factor Types', 'S', 'FLAG=Points when it applies|SCORE=Percentage of the questionnaire score');
    lookups('DATA_SOURCE', 'Data Sources', 'S', 'MANUAL=Entered by hand|API=From the provider');
    lookups('FIU_REPORT_TYPE', 'FIU Report Types', 'S', 'STR=Suspicious transaction report|SAR=Suspicious activity report');
    lookups('FIU_REPORT_STATUS', 'FIU Report Statuses', 'S',
        'DRAFT=Draft|APPROVED=Approved|FILED=Filed with the FIU|CANCELLED=Cancelled');
    lookups('FUNDS_TYPE', 'Source of Funds / Wealth', 'S', 'SOF=Source of funds (this relationship)|SOW=Source of wealth (overall)');
    lookups('FUNDS_EVIDENCE_TYPE', 'Source of Funds Evidence', 'S',
        'BANK_STATEMENT=Bank statement|PAYSLIP=Payslip|EMPLOYMENT_LETTER=Employment letter'
        || '|AUDITED_ACCOUNTS=Audited accounts|TAX_RETURN=Tax return|SALE_AGREEMENT=Sale agreement|WILL_PROBATE=Will / probate'
        || '|INVESTMENT_STATEMENT=Investment statement|LOAN_AGREEMENT=Loan agreement|SHAREHOLDER_FUNDING=Shareholder funding evidence'
        || '|OTHER=Other');
    -- the tag lists the evidence expected for each source (the form guides the officer with it)
    lookups('FUNDS_CATEGORY', 'Source of Funds Categories', 'S',
        'SALARY=Salary / employment income=PAYSLIP,BANK_STATEMENT,EMPLOYMENT_LETTER'
        || '|BUSINESS_INCOME=Business income / trading=AUDITED_ACCOUNTS,BANK_STATEMENT,TAX_RETURN'
        || '|CAPITAL=Shareholder capital=SHAREHOLDER_FUNDING,BANK_STATEMENT'
        || '|SALE_OF_ASSETS=Sale of assets=SALE_AGREEMENT,BANK_STATEMENT'
        || '|INVESTMENTS=Investments=INVESTMENT_STATEMENT,BANK_STATEMENT'
        || '|INHERITANCE=Inheritance / gift=WILL_PROBATE,BANK_STATEMENT'
        || '|LOAN=Loan / financing=LOAN_AGREEMENT,BANK_STATEMENT'
        || '|OTHER=Other');
    lookups('ALERT_TYPE', 'Monitoring Alert Types', 'S',
        'REVIEW_DUE=Review due|REVIEW_OVERDUE=Review overdue|SLA_BREACH=Investigation past SLA'
        || '|DOCUMENT_EXPIRY=Document expiring|ADVERSE_SCREENING=Adverse screening after approval');
    lookups('ALERT_STATUS', 'Monitoring Alert Status', 'S', 'OPEN=Open|ACKNOWLEDGED=Acknowledged|CLOSED=Closed');
    lookups('REVIEW_STATUS', 'Review Status', 'S', 'CURRENT=Current|DUE=Due|IN_REVIEW=In review|OVERDUE=Overdue');

    ----------------------------------------------------------------------------
    -- Value sets and descriptive flexfields (the context follows the row's own type column, so an administrator
    -- can add PERSON-only or ORGANIZATION-only fields)
    ----------------------------------------------------------------------------
    xxfnd_dff_pkg.register_value_set(c_app, 'XXFND_CHAR_150', 'Free text (150)', 'NONE', 'CHAR', 150);
    xxfnd_dff_pkg.register_value_set(c_app, 'XXFND_CHAR_30', 'Free text (30)', 'NONE', 'CHAR', 30);
    xxfnd_dff_pkg.register_value_set(c_app, 'XXFND_NUMBER', 'Number', 'NONE', 'NUMBER');
    xxfnd_dff_pkg.register_value_set(c_app, 'XXFND_DATE', 'Date', 'NONE', 'DATE');
    xxfnd_dff_pkg.register_value_set(c_app, 'XXFND_TIMESTAMP', 'Date and time', 'NONE', 'TIMESTAMP');
    xxfnd_dff_pkg.register_value_set(c_app, 'XXFND_YES_NO', 'Yes / No', 'INDEPENDENT', 'CHAR', 1, 'YES_NO');
    xxfnd_dff_pkg.register_value_set(c_app, 'XXFND_JURISDICTION', 'Jurisdiction', 'INDEPENDENT', 'CHAR', 30, 'JURISDICTION');
    xxfnd_dff_pkg.register_flexfield(c_app, 'XXCMP_PARTIES_DFF', 'XXCMP_PARTIES', 'PARTY_ID', 'Party Additional Information',
                                     p_context_reference_column => 'PARTY_TYPE');
    xxfnd_dff_pkg.register_context(c_app, 'XXCMP_PARTIES_DFF', 'ORGANIZATION', 'Organization');
    xxfnd_dff_pkg.register_context(c_app, 'XXCMP_PARTIES_DFF', 'PERSON', 'Person');
    xxfnd_dff_pkg.register_flexfield(c_app, 'XXCMP_PARTY_CONTACTS_DFF', 'XXCMP_PARTY_CONTACTS', 'PARTY_CONTACT_ID',
                                     'Party Contact Additional Information');
    xxfnd_dff_pkg.register_flexfield(c_app, 'XXCMP_PARTY_REL_DFF', 'XXCMP_PARTY_RELATIONSHIPS', 'PARTY_RELATIONSHIP_ID',
                                     'Relationship Additional Information');

    ----------------------------------------------------------------------------
    -- Documents: entities, categories and the KYC pages with attachments
    ----------------------------------------------------------------------------
    xxfnd_attach_pkg.register_entity(c_app, 'XXCMP_PARTIES', 'XXCMP_PARTIES', 'PARTY_ID', 'Party');
    xxfnd_attach_pkg.register_entity(c_app, 'XXCMP_RFIS', 'XXCMP_RFIS', 'RFI_ID', 'Request for Information');
    xxfnd_attach_pkg.register_entity(c_app, 'XXCMP_REQUESTS', 'XXCMP_REQUESTS', 'REQUEST_ID', 'KYC Request');
    xxfnd_attach_pkg.register_entity(c_app, 'XXCMP_CASES', 'XXCMP_CASES', 'CASE_ID', 'Case');
    xxfnd_attach_pkg.register_entity(c_app, 'XXCMP_PARTY_ID_VERIFICATIONS', 'XXCMP_PARTY_ID_VERIFICATIONS', 'ID_VERIFICATION_ID',
                                     'ID Verification');
    xxfnd_attach_pkg.register_entity(c_app, 'XXCMP_PARTY_REGISTRY_CHECKS', 'XXCMP_PARTY_REGISTRY_CHECKS', 'REGISTRY_CHECK_ID',
                                     'Registry Check');
    -- (the e-mails of the RFI and Notes screens are COMMON's document entity XXFND_COMMUNICATIONS)

    xxfnd_attach_pkg.register_category(c_app, 'TRADE_LICENSE', 'Trade / Commercial Licence', 'الرخصة التجارية',
                                       p_has_expiry_flag => 'Y');
    xxfnd_attach_pkg.register_category(c_app, 'CERT_INCORPORATION', 'Certificate of Incorporation', 'شهادة التأسيس');
    xxfnd_attach_pkg.register_category(c_app, 'MOA_AOA', 'Memorandum / Articles of Association', 'عقد التأسيس والنظام الأساسي');
    xxfnd_attach_pkg.register_category(c_app, 'SHAREHOLDER_REGISTER', 'Shareholder Register');
    xxfnd_attach_pkg.register_category(c_app, 'OWNERSHIP_CHART', 'Ownership Structure Chart');
    xxfnd_attach_pkg.register_category(c_app, 'BOARD_RESOLUTION', 'Board Resolution / Power of Attorney');
    xxfnd_attach_pkg.register_category(c_app, 'PASSPORT', 'Passport', 'جواز السفر', p_has_expiry_flag => 'Y');
    xxfnd_attach_pkg.register_category(c_app, 'NATIONAL_ID', 'National ID', 'الهوية الوطنية', p_has_expiry_flag => 'Y');
    xxfnd_attach_pkg.register_category(c_app, 'PROOF_OF_ADDRESS', 'Proof of Address', 'إثبات العنوان', p_max_age_days => 90);
    xxfnd_attach_pkg.register_category(c_app, 'BANK_REFERENCE', 'Bank Reference Letter', p_max_age_days => 90);
    xxfnd_attach_pkg.register_category(c_app, 'FINANCIAL_STATEMENTS', 'Financial Statements');
    xxfnd_attach_pkg.register_category(c_app, 'SOURCE_OF_FUNDS', 'Source of Funds / Wealth Evidence');
    xxfnd_attach_pkg.register_category(c_app, 'SCREENING_RESULT', 'Screening Result');
    xxfnd_attach_pkg.register_category(c_app, 'RFI_RESPONSE', 'RFI Response Document');
    -- (OTHER is COMMON's own category, used by every application)
    xxfnd_attach_pkg.register_category(c_app, 'NOTE', 'Note', p_default_datatype_code => 'LONG_TEXT');
    xxfnd_attach_pkg.register_category(c_app, 'WEB_LINK', 'Web Link', p_default_datatype_code => 'WEB_PAGE');

    attachment_page('KYC_PARTY', 'Party', 21, 'ATTACHMENTS', 'party_attachments', 'Attachments', 'XXCMP_PARTIES', 'P21_PARTY_ID', 'N');
    attachment_page('KYC_REQUEST_SUBMIT', 'Create Request - Submit', 203, 'ATTACHMENTS', 'request_attachments', 'Documents',
                    'XXCMP_REQUESTS', 'P203_REQUEST_ID', 'Y');
    attachment_page('KYC_REQUEST', 'KYC Request', 205, 'ATTACHMENTS', 'request_attachments', 'Documents', 'XXCMP_REQUESTS',
                    'P205_REQUEST_ID', 'N');
    attachment_page('KYC_CASE', 'Case', 211, 'PARTY_DOCUMENTS', 'party_documents', 'Party Documents', 'XXCMP_PARTIES',
                    'P211_PARTY_ID', 'N');
    -- release 89: KYC's RFI page (31) is gone - the RFIs run in COMMON's RFI process (task page 143). The documents of an
    -- earlier KYC RFI (entity XXCMP_RFIS, kept as history) are shown from the case's Notes and RFIs list (region notes)
    -- on COMMON's Attachments page: view only (an existing KYC_RFI registration of page 31 is left as it is)
    xxfnd_attach_pkg.register_attachment_page(c_app, 'KYC_CASE', 'Case', 211, 'RFI_DOCUMENTS', 'notes', 'XXCMP_RFIS', 'RFI_ID',
                                              'RFI Documents', p_insert_allowed_flag => 'N', p_update_allowed_flag => 'N',
                                              p_delete_allowed_flag => 'N', p_display_sequence => 20);
    attachment_page('KYC_REQUEST_PARTY', 'Create Request - Party Details', 204, 'ATTACHMENTS', 'party_attachments',
                    'Party Documents', 'XXCMP_PARTIES', 'P0_SUMMARY_PARTY_ID', 'Y');
    attachment_page('KYC_PARTY_DETAILS', 'Party - Details', 25, 'ATTACHMENTS', 'party_attachments', 'Party Documents',
                    'XXCMP_PARTIES', 'P0_SUMMARY_PARTY_ID', 'Y');

    ----------------------------------------------------------------------------
    -- Integration purposes, the alert notification, task deadlines
    ----------------------------------------------------------------------------
    xxfnd_integration_pkg.register_purpose(c_app, 'SCREENING', 'Sanctions / PEP / adverse media screening');
    xxfnd_integration_pkg.register_purpose(c_app, 'DOC_AUTHENTICITY', 'Document authenticity check');
    xxfnd_integration_pkg.register_purpose(c_app, 'REGISTRY_LOOKUP', 'Company registry lookup');
    xxfnd_integration_pkg.register_purpose(c_app, 'BANK_DATA', 'Bank data for source of funds');
    xxfnd_integration_pkg.register_purpose(c_app, 'GOAML_FILING', 'FIU goAML filing');

    xxfnd_notify_pkg.register_template(c_app, 'KYC_ALERT', 'KYC alert: #ALERT_NAME#', '#ALERT_MESSAGE#', 'Open the alerts');

    xxfnd_workflow_pkg.register_task_setting(c_app, 'COUNTERPARTY_MATCH', 2, 1, 'COMPLIANCE_MANAGER',
        p_description => 'Compliance decides whether a new counterparty is an existing party.');
    xxfnd_workflow_pkg.register_task_setting(c_app, 'DOC_CHECKLIST_REVIEW', 2, 1, 'COMPLIANCE_MANAGER',
        p_description => 'Compliance checks the documents of a request before investigation.');
    xxfnd_workflow_pkg.register_task_setting(c_app, 'CASE_INVESTIGATION', 10, 2, 'COMPLIANCE_MANAGER',
        p_description => 'The officer investigates the case.');
    xxfnd_workflow_pkg.register_task_setting(c_app, 'CASE_APPROVAL', 3, 1, 'HEAD_OF_COMPLIANCE',
        p_description => 'An approver decides the case (one task per approval level).');
    xxfnd_workflow_pkg.register_task_setting(c_app, 'CONFIG_CHANGE', 3, 1, 'HEAD_OF_COMPLIANCE',
        p_description => 'Second-person approval of a configuration change.');
    -- release 89: RFI_RESPONSE and RFI_REVIEW are COMMON's task definitions (workflow RFI), shared by every application:
    -- their deadlines are COMMON's settings (Workflow Setup), not registered by KYC (existing rows are kept)

    -- the KYC workflows (KYC_REQUEST, KYC_CASE) as processes of KYC with their switches (COMMON reads the APEX
    -- workflows of every registered application); on a first install KYC raises its RFIs through COMMON's RFI process
    -- (onboarding leaves the shared processes off)
    xxfnd_workflow_pkg.sync_processes;
    if not xxfnd_ddl_pkg.release_applied('R10') then
        xxfnd_workflow_pkg.set_process_enabled(c_app, 'RFI', 'Y');
    end if;

    ----------------------------------------------------------------------------
    -- Data access: the Compliance team sees every request, case, party and RFI; a requester his own requests and
    -- the RFIs addressed to him; verifications, FIU reports, funds, e-mails and the risk model only the team
    ----------------------------------------------------------------------------
    rule(c_staff, 'XXCMP_REQUESTS', 'ALL_ROWS');
    rule(c_staff, 'XXCMP_CASES', 'ALL_ROWS');
    rule('REQUESTER', 'XXCMP_REQUESTS', 'OWN_RECORDS', 'REQUESTER_USER_NAME');
    rule(c_staff || ',SYSTEM_ADMIN', 'XXCMP_PARTIES', 'ALL_ROWS');
    rule(c_staff || ',SYSTEM_ADMIN', 'XXCMP_RFIS', 'ALL_ROWS');
    rule(c_staff || ',SYSTEM_ADMIN', 'XXFND_RFIS', 'ALL_ROWS');
    rule('REQUESTER', 'XXCMP_RFIS', 'OWN_RECORDS', 'RECIPIENT_USER_NAME');
    rule('REQUESTER', 'XXFND_RFIS', 'OWN_RECORDS', 'RECIPIENT_USER_NAME');
    for t in (select column_value table_name from table(apex_t_varchar2(
                  'XXCMP_PARTY_ID_VERIFICATIONS', 'XXCMP_PARTY_REGISTRY_CHECKS', 'XXCMP_FIU_REPORTS', 'XXCMP_CASE_FUNDS',
                  'XXFND_COMMUNICATIONS', 'XXCMP_RISK_FACTORS', 'XXCMP_RISK_COUNTRIES', 'XXCMP_RISK_TIERS',
                  'XXCMP_CASE_RISK_SCORES'))) loop
        rule(c_staff || ',SYSTEM_ADMIN', t.table_name, 'ALL_ROWS');
    end loop;

    ----------------------------------------------------------------------------
    -- KYC configuration tables (configuration audit; maker-checker approval where flagged; each risk model table
    -- is one approval unit)
    ----------------------------------------------------------------------------
    xxfnd_approval_pkg.register_config_table(c_app, 'XXCMP_QUESTIONNAIRES');
    xxfnd_approval_pkg.register_config_table(c_app, 'XXCMP_QUESTIONS');
    xxfnd_approval_pkg.register_config_table(c_app, 'XXCMP_ANSWER_OPTIONS', 'Y', 'Y', 'ANSWER_OPTION_ID', 'XXCMP_QUESTIONS',
                                             'QUESTION_ID', 'XXCMP_CONFIG_CHANGES_V');
    xxfnd_approval_pkg.register_config_table(c_app, 'XXCMP_CONCLUSION_TEMPLATES');
    xxfnd_approval_pkg.register_config_table(c_app, 'XXCMP_APPROVAL_MATRIX');
    xxfnd_approval_pkg.register_config_table(c_app, 'XXCMP_ATTACHMENT_RULES', 'Y', 'Y', 'ATTACHMENT_RULE_ID', null, null,
                                             'XXCMP_CONFIG_CHANGES_V');
    xxfnd_approval_pkg.register_config_table(c_app, 'XXCMP_RISK_FACTORS', 'Y', 'Y', 'FACTOR_CODE', 'XXCMP_RISK_FACTOR_SET',
                                             'MODEL_CODE', 'XXCMP_CONFIG_CHANGES_V');
    xxfnd_approval_pkg.register_config_table(c_app, 'XXCMP_RISK_COUNTRIES', 'Y', 'Y', 'RISK_COUNTRY_ID', 'XXCMP_RISK_COUNTRY_SET',
                                             'MODEL_CODE', 'XXCMP_CONFIG_CHANGES_V');
    xxfnd_approval_pkg.register_config_table(c_app, 'XXCMP_RISK_TIERS', 'Y', 'Y', 'RISK_TIER', 'XXCMP_RISK_TIER_SET',
                                             'MODEL_CODE', 'XXCMP_CONFIG_CHANGES_V');

    ----------------------------------------------------------------------------
    -- First-install grants (an upgrade keeps what the console decided)
    ----------------------------------------------------------------------------
    if not xxfnd_ddl_pkg.release_applied('R10') then
        grant_to(c_all, 'HOME.VIEW');
        grant_to(c_staff, 'PARTIES.VIEW,PARTIES.CREATE,PARTIES.MANAGE,CASES.VIEW,CASES.CREATE,CASES.MANAGE,CASE_ASSIGNMENT.MANAGE');
        grant_to('COMPLIANCE_MANAGER,HEAD_OF_COMPLIANCE,SYSTEM_ADMIN',
                 'KYC_RULES.VIEW,KYC_RULES.CREATE,KYC_RULES.MANAGE,CHANGE_APPROVALS.VIEW,CHANGE_APPROVALS.MANAGE');
        -- Alert Rules, and COMMON's shared screens KYC's System Administrator uses (opened in COMMON since release 88)
        grant_to('SYSTEM_ADMIN', 'ALERT_RULES.VIEW,ALERT_RULES.CREATE,ALERT_RULES.MANAGE,'
                              || 'WORKFLOW_MONITOR.VIEW,WORKFLOW_MONITOR.MANAGE,APP_SETTINGS.VIEW,APP_SETTINGS.MANAGE,'
                              || 'USAGE_FEEDBACK.VIEW,USAGE_FEEDBACK.MANAGE');
    end if;
    -- release 76: Case Assignment is its own privilege; once, the KYC roles that held Cases - Manage get it (a database
    -- upgraded from before release 76; a new one has it from the grants above)
    if not xxfnd_ddl_pkg.release_applied('R76_CASE_ASSIGNMENT') then
        for r in (select rp.role_code from xxfnd_role_privileges rp join xxfnd_roles o on o.role_code = rp.role_code
                   where rp.privilege_code = 'CASES.MANAGE' and o.application_code = c_app) loop
            grant_to(r.role_code, 'CASE_ASSIGNMENT.MANAGE');
        end loop;
        xxfnd_ddl_pkg.mark_release('R76_CASE_ASSIGNMENT', 'Release 76: Case Assignment privilege granted once');
    end if;
    if not xxfnd_ddl_pkg.release_applied('R13') then
        grant_to('REQUESTER', 'KYC_REQUESTS.VIEW,KYC_REQUESTS.CREATE,KYC_REQUESTS.MANAGE');
        grant_to(c_staff, 'KYC_REQUESTS.VIEW,KYC_REQUESTS.CREATE');
    end if;
    if not xxfnd_ddl_pkg.release_applied('R14') then
        grant_to(c_staff, 'MONITORING.VIEW,MONITORING.MANAGE');
        grant_to('COMPLIANCE_MANAGER,HEAD_OF_COMPLIANCE', 'DASHBOARD.VIEW');
        grant_to('HEAD_OF_COMPLIANCE', 'ALERT_RULES.VIEW');
    end if;

    xxfnd_util_pkg.set_install_mode(false);
    commit;
    xxfnd_schema_pkg.apply_policies;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/

-- the configuration audit triggers of the KYC tables registered above
begin
    xxfnd_schema_pkg.create_config_audit_triggers;
end;
/

--------------------------------------------------------------------------------
-- First administrator when installed from APEX Supporting Objects: the developer running the install; without an
-- APEX session (SQLcl apex import) the workspace administrators. They grant further access in COMMON.
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
        xxfnd_user_pkg.bootstrap_admin(l_user, l_name, l_email);
    else
        for a in (select user_name, trim(first_name || ' ' || last_name) full_name, email
                    from apex_workspace_apex_users
                   where is_admin = 'Yes' and nvl(account_locked, 'No') = 'No') loop
            xxfnd_user_pkg.bootstrap_admin(a.user_name, a.full_name, a.email);
        end loop;
    end if;
    xxfnd_util_pkg.set_install_mode(false);
    commit;
end;
/
