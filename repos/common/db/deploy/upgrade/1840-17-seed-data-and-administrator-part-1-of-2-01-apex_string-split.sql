--------------------------------------------------------------------------------
-- 10_seed.sql
-- Seed data for Module 0. Re-runnable: every row is MERGEd on its natural key.
-- Runs outside an APEX session, so maker-checker rows can be seeded APPROVED.
--
-- Runs both from SQLcl (install.sql) and as an APEX Supporting Objects script.
-- First administrator (SYSTEM_ADMIN):
--   * APEX install: the developer running the install.
--   * SQLcl install: install.sql prompts and calls XXFND_USER_PKG.BOOTSTRAP_ADMIN.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- 10.1 Lookups
--------------------------------------------------------------------------------
declare
    ----------------------------------------------------------------------------
    procedure lt(p_type in varchar2, p_meaning in varchar2, p_level in varchar2 default 'S',
                 p_app in varchar2 default null, p_desc in varchar2 default null) is
        l_n pls_integer;
    begin
        -- release 49: an application's own lookups are seeded only where that application is installed
        -- (the COMMON schema gets the shared ones)
        if p_app = 'KYC' then
            select count(*) into l_n from user_tables where table_name = 'XXCMP_PARTIES';
            if l_n = 0 then
                return;
            end if;
        end if;
        merge into xxfnd_lookup_types t
        using (select p_type lookup_type from dual) s on (t.lookup_type = s.lookup_type)
         -- system lookups (S) belong to the application; E/U lookups to the administrators
         when matched then update set t.meaning = p_meaning, t.customization_level = p_level,
                                      t.application_code = p_app, t.description = p_desc
                           where t.customization_level = 'S'
                             -- release 87 (C3): never another application's type
                             and (t.application_code is null or t.application_code = 'COMMON'
                                  or t.application_code = p_app)
         when not matched then insert (lookup_type, meaning, customization_level, application_code, description)
                               values (p_type, p_meaning, p_level, p_app, p_desc);
    end lt;

    procedure lv(p_type in varchar2, p_code in varchar2, p_meaning in varchar2, p_seq in number,
                 p_tag in varchar2 default null, p_ar in varchar2 default null,
                 p_parent_type in varchar2 default null, p_parent_code in varchar2 default null) is
        l_n pls_integer;
    begin
        -- release 87 (C3): COMMON seeds only its own lookups; another application's type (registered by that
        -- application, XXFND_LOOKUP_PKG.REGISTER_LOOKUP_*) and its values are left as they are
        select count(*) into l_n from xxfnd_lookup_types
         where lookup_type = p_type and (application_code is null or application_code = 'COMMON');
        if l_n = 0 then
            return;   -- the type was skipped by LT, or it is another application's lookup
        end if;
        merge into xxfnd_lookup_values t
        using (select p_type lookup_type, p_code lookup_code from dual) s
           on (t.lookup_type = s.lookup_type and t.lookup_code = s.lookup_code)
         when matched then update set t.meaning = p_meaning, t.display_sequence = p_seq, t.tag = p_tag,
                                      t.parent_lookup_type = p_parent_type, t.parent_lookup_code = p_parent_code
                           where t.lookup_type in (select lookup_type from xxfnd_lookup_types where customization_level = 'S')
         when not matched then insert (lookup_type, lookup_code, meaning, display_sequence, tag,
                                       parent_lookup_type, parent_lookup_code)
                               values (p_type, p_code, p_meaning, p_seq, p_tag, p_parent_type, p_parent_code);
        if p_ar is not null then
            merge into xxfnd_lookup_values_tl t
            using (select p_type lookup_type, p_code lookup_code, 'ar' language_code from dual) s
               on (t.lookup_type = s.lookup_type and t.lookup_code = s.lookup_code and t.language_code = s.language_code)
             when matched then update set t.meaning = p_ar
                               where t.lookup_type in (select lookup_type from xxfnd_lookup_types where customization_level = 'S')
             when not matched then insert (lookup_type, lookup_code, language_code, meaning)
                                   values (p_type, p_code, 'ar', p_ar);
        end if;
    end lv;

    -- Several values in one call: 'CODE=Meaning|CODE=Meaning'
    procedure lvs(p_type in varchar2, p_list in varchar2) is
        l_items apex_t_varchar2 := apex_string.split(p_list, '|');
    begin
        for i in 1 .. l_items.count loop
            lv(p_type, substr(l_items(i), 1, instr(l_items(i), '=') - 1),
                       substr(l_items(i), instr(l_items(i), '=') + 1), i * 10);
        end loop;
    end lvs;

begin
    xxfnd_util_pkg.set_install_mode(true);
    ----------------------------------------------------------------------------
    -- Lookups (APPLICATION_CODE null = shared by every application)
    ----------------------------------------------------------------------------
    lt('YES_NO', 'Yes / No');
    lv('YES_NO', 'Y', 'Yes', 10, p_ar => 'نعم');
    lv('YES_NO', 'N', 'No',  20, p_ar => 'لا');

    lt('LANGUAGE', 'Languages', 'E');
    lv('LANGUAGE', 'en', 'English', 10);
    lv('LANGUAGE', 'ar', 'Arabic', 20, p_ar => 'العربية');

    lt('CUSTOMIZATION_LEVEL', 'Lookup Customization Level');
    lvs('CUSTOMIZATION_LEVEL', 'S=System|E=Extensible|U=User');

    lt('JURISDICTION', 'Jurisdictions', 'E', null, 'TAG = UBO ownership threshold (%) for the jurisdiction.');
    lv('JURISDICTION', 'AE', 'United Arab Emirates', 10, '25', 'الإمارات العربية المتحدة');
    lv('JURISDICTION', 'SA', 'Saudi Arabia',         20, '25', 'المملكة العربية السعودية');
    lv('JURISDICTION', 'QA', 'Qatar',                30, '25', 'قطر');
    lv('JURISDICTION', 'BH', 'Bahrain',              40, '25', 'البحرين');
    lv('JURISDICTION', 'KW', 'Kuwait',               50, '25', 'الكويت');
    lv('JURISDICTION', 'OM', 'Oman',                 60, '25', 'عُمان');
    lv('JURISDICTION', 'GB', 'United Kingdom',       70, '25', 'المملكة المتحدة');
    lv('JURISDICTION', 'US', 'United States',        80, '25', 'الولايات المتحدة');
    lv('JURISDICTION', 'OTHER', 'Other',             999, '25', 'أخرى');

    lt('ENTITY_TYPE', 'Legal Entity Types', 'E', 'KYC');
    lvs('ENTITY_TYPE', 'LLC=Limited Liability Company|PJSC=Public Joint Stock Company|PRJSC=Private Joint Stock Company'
        || '|SOLE_EST=Sole Establishment|BRANCH=Branch of Foreign Company|FREE_ZONE=Free Zone Entity'
        || '|PARTNERSHIP=Partnership|TRUST=Trust or Foundation|NON_PROFIT=Non-Profit Organisation'
        || '|GOVERNMENT=Government Entity|OTHER=Other');

    lt('PARTY_TYPE', 'Party Types', 'S', 'KYC');
    lv('PARTY_TYPE', 'ORGANIZATION', 'Organization', 10, p_ar => 'منشأة');
    lv('PARTY_TYPE', 'PERSON', 'Person', 20, p_ar => 'فرد');

    lt('CONTACT_TYPE', 'Contact Types', 'E', 'KYC');
    lvs('CONTACT_TYPE', 'EMAIL=Email|PHONE=Phone|MOBILE=Mobile|ADDRESS=Address|WEBSITE=Website');

    lt('RELATIONSHIP_TYPE', 'Party Relationship Types', 'E', 'KYC');
    lvs('RELATIONSHIP_TYPE', 'SHAREHOLDER=Shareholder|DIRECTOR=Director|MANAGER=Manager'
        || '|AUTHORISED_SIGNATORY=Authorised Signatory|PARENT_COMPANY=Parent Company|BENEFICIAL_OWNER=Beneficial Owner'
        || '|TRUSTEE=Trustee|SETTLOR=Settlor|BENEFICIARY=Beneficiary|OTHER=Other');

    lt('DATA_PROVENANCE', 'Data Provenance', 'S', 'KYC');
    lvs('DATA_PROVENANCE', 'SELF_DECLARED=Self-declared|REGISTRY_VERIFIED=Registry verified');

    lt('UBO_STATUS', 'UBO Determination', 'S', 'KYC');
    lvs('UBO_STATUS', 'UBO=Ultimate beneficial owner|NOT_UBO=Not a UBO|NOT_YET_ASSESSED=Not yet assessed');

    lt('DUE_DILIGENCE_TYPE', 'Due Diligence Types', 'S', 'KYC');
    lvs('DUE_DILIGENCE_TYPE', 'SIMPLIFIED=Simplified KYC|STANDARD=Standard KYC|ENHANCED=Enhanced KYC');

    lt('RISK_TIER', 'Risk Tiers', 'S', 'KYC');
    lv('RISK_TIER', 'LOW', 'Low', 10, p_ar => 'منخفض');
    lv('RISK_TIER', 'MEDIUM', 'Medium', 20, p_ar => 'متوسط');
    lv('RISK_TIER', 'HIGH', 'High', 30, p_ar => 'مرتفع');

    lt('QA_ANSWER_TYPE', 'Question Answer Types', 'S', 'KYC');
    lvs('QA_ANSWER_TYPE', 'SINGLE_SELECT=Single choice|MULTI_SELECT=Multiple choice|YES_NO=Yes / No|TEXT=Text|NUMBER=Number|DATE=Date');

    lt('QUESTIONNAIRE_AUDIENCE', 'Questionnaire Audience', 'S', 'KYC');
    lvs('QUESTIONNAIRE_AUDIENCE', 'REQUESTER=Requester (scored)|OFFICER=Compliance Officer (unscored)');

    lt('APPROVAL_STATUS', 'Configuration Approval Status');
    lvs('APPROVAL_STATUS', 'DRAFT=Draft|PENDING_APPROVAL=Pending approval|APPROVED=Approved|REJECTED=Rejected');

    lt('EMPLOYEE_SOURCE', 'Employee Source');
    lvs('EMPLOYEE_SOURCE', 'FUSION=Oracle Fusion HCM|LOCAL=Local');

    lt('SOD_SCOPE', 'Segregation of Duties Scope');
    lvs('SOD_SCOPE', 'SAME_RECORD=Same record|GLOBAL=Never both roles');

    lt('RETENTION_ACTION', 'Retention Action');
    lvs('RETENTION_ACTION', 'ARCHIVE=Archive|PURGE=Purge|FLAG_FOR_REVIEW=Flag for review');

    lt('DOC_DATATYPE', 'Attachment Data Types');
    lvs('DOC_DATATYPE', 'FILE=File|SHORT_TEXT=Short text|LONG_TEXT=Long text|WEB_PAGE=Web page');

    lt('STORAGE_TYPE', 'Document Storage Types');
    lvs('STORAGE_TYPE', 'UCM=Oracle WebCenter Content (UCM)|SHAREPOINT=Microsoft SharePoint');

    lt('UPLOAD_STATUS', 'Upload Status');
    lvs('UPLOAD_STATUS', 'PENDING=Pending|STORED=Stored|FAILED=Failed|NOT_APPLICABLE=Not applicable');

    lt('DOC_CHECK_STATUS', 'Automated Document Check Status');
    lvs('DOC_CHECK_STATUS', 'NOT_CHECKED=Not checked|PASSED=Passed|FLAGGED=Flagged');




    lt('NOTIFICATION_STATUS', 'Notification Status');
    lvs('NOTIFICATION_STATUS', 'QUEUED=Queued|SENT=Sent|FAILED=Failed|RESPONDED=Responded|EXPIRED=Expired|CANCELLED=Cancelled');

    lt('RFI_CATEGORY', 'RFI Categories', 'E', 'KYC');
    lvs('RFI_CATEGORY', 'MISSING_DOCUMENT=Missing document|CLARIFICATION=Clarification|OWNERSHIP=Ownership and control'
        || '|SOURCE_OF_FUNDS=Source of funds or wealth|OTHER=Other');

    lt('RFI_RECIPIENT_TYPE', 'RFI Recipient Types', 'S', 'KYC');
    lvs('RFI_RECIPIENT_TYPE', 'REQUESTING_DEPARTMENT=Requesting department|EXTERNAL_PARTY=External party'
        -- release 74: the common RFI (XXFND_RFIS) - a user of the application or an external person
        || '|USER=User (answers in My Tasks)|EXTERNAL=External person (answers through the e-mailed link)');

    lt('RFI_STATUS', 'RFI Status', 'S', 'KYC');
    lvs('RFI_STATUS', 'WAITING_FOR_INFORMATION=Waiting for information|ON_HOLD_PENDING=On hold - pending'
        || '|ON_HOLD_INVESTIGATION=On hold - investigation|RESOLVED=Resolved|REJECTED_RETURNED=Rejected / returned'
        || '|CANCELLED=Cancelled|RESPONDED=Answered - waiting for review');

    lt('INTEGRATION_PURPOSE', 'Integration Purposes', 'E');
    lvs('INTEGRATION_PURPOSE', 'SCREENING=Sanctions / PEP / adverse media screening|DOC_AUTHENTICITY=Document authenticity check'
        || '|REGISTRY_LOOKUP=Company registry lookup|DOCUMENT_STORAGE=Document storage');

    lt('ENDPOINT_TYPE', 'Integration Endpoint Types', 'E');
    lvs('ENDPOINT_TYPE', 'UCM=Oracle WebCenter Content (UCM)|SHAREPOINT=Microsoft SharePoint (Graph)'
        || '|SCREENING_PROVIDER=Screening provider|REGISTRY_PROVIDER=Registry provider|DOC_AUTH_PROVIDER=Document authentication provider|OTHER=Other');

    lt('ENDPOINT_STATUS', 'Integration Endpoint Status');
    lvs('ENDPOINT_STATUS', 'REGISTERED=Registered|ACTIVE=Active|INACTIVE=Inactive');

    lt('CAPTURE_METHOD', 'Capture Method');
    lvs('CAPTURE_METHOD', 'MANUAL=Manual|API=Automatic (API)');

    lt('TRANSMISSION_STATUS', 'Transmission Status');
    lvs('TRANSMISSION_STATUS', 'PENDING=Pending|SUCCESS=Success|FAILED=Failed|RETRYING=Retrying');

    lt('VS_VALIDATION_TYPE', 'Value Set Validation Types');
    lvs('VS_VALIDATION_TYPE', 'NONE=None (free entry)|INDEPENDENT=Independent (lookup)|DEPENDENT=Dependent (lookup with parent)|TABLE=Table (SQL query)');

    lt('VS_FORMAT_TYPE', 'Value Set Format Types');
    lvs('VS_FORMAT_TYPE', 'CHAR=Character|NUMBER=Number|DATE=Date|TIMESTAMP=Date and time');

    lt('DF_DEFAULT_TYPE', 'Segment Default Types');
    lvs('DF_DEFAULT_TYPE', 'NONE=None|CONSTANT=Constant|SQL=SQL query');

    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
