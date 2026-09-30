-- Patch 05 - common party card and dialog: database changes (run as the parsing schema).
-- 16e: XXCMP_PARTY_PKG with CARD_HTML; 18b: page 24 belongs to the Parties feature (security). Idempotent.

-- ==== 16e-party-pkg.sql
--------------------------------------------------------------------------------
-- 16e Party logic (party feature: pages 21, 23)
--   XXCMP_PARTY_PKG: create a party from another screen (owner / officer) and merge a
--   duplicate party into another one (Compliance). Runs after 16b/16c: the merge re-points
--   requests, cases, screenings, alerts, notes and beneficial-owner decisions.
-- Idempotent: safe on install and on every upgrade.
--------------------------------------------------------------------------------
create or replace package xxcmp_party_pkg authid definer as

    -- A new party created from another screen (for example a new owner / officer on page 23). Requires
    -- Parties - Create. Refused when a party with the same registration / identity number and country exists.
    function create_party(p_party_type          in varchar2,
                          p_party_name          in varchar2,
                          p_jurisdiction        in varchar2 default null,
                          p_registration_number in varchar2 default null,
                          p_date_of_birth       in date     default null) return number;

    -- Compliance merges the duplicate P_FROM_PARTY_ID into P_INTO_PARTY_ID (Parties - Manage): requests, cases,
    -- screenings, alerts, notes, beneficial-owner decisions, contacts, relationships and documents move to the
    -- kept party; its empty details are completed from the duplicate; the duplicate is disabled and points to it.
    procedure merge_parties(p_from_party_id in number, p_into_party_id in number, p_note in varchar2 default null);

    -- Y when the party exists and is enabled (a merged or disabled party is not edited or merged again).
    function is_enabled(p_party_id in number) return varchar2;

    -- The common Party card (HTML) shown on every screen that shows a party: number, name, type, registration /
    -- identity, country, main contact details, primary contact person and status. Follows data security: a user who
    -- may not see the party gets a short note instead.
    function card_html(p_party_id in number) return clob;

end xxcmp_party_pkg;
/

create or replace package body xxcmp_party_pkg as

    function create_party(p_party_type          in varchar2,
                          p_party_name          in varchar2,
                          p_jurisdiction        in varchar2 default null,
                          p_registration_number in varchar2 default null,
                          p_date_of_birth       in date     default null) return number is
        l_id    number;
        l_exact varchar2(30);
    begin
        if not xxfnd_privilege_pkg.has_privilege('PARTIES', 'CREATE') then
            raise_application_error(-20701, 'You are not allowed to create parties.');
        elsif p_party_type not in ('ORGANIZATION', 'PERSON') or p_party_type is null then
            raise_application_error(-20702, 'Choose whether the new party is an organisation or an individual.');
        elsif trim(p_party_name) is null then
            raise_application_error(-20703, 'Enter the name of the new party.');
        elsif p_date_of_birth > trunc(sysdate) then
            raise_application_error(-20704, 'The date of birth cannot be in the future.');
        end if;
        if p_party_type = 'ORGANIZATION' and trim(p_registration_number) is not null and p_jurisdiction is not null then
            -- same registration number (ignoring spaces and punctuation) and country = the same organisation
            select min(party_number) into l_exact
              from xxcmp_parties
             where party_type = 'ORGANIZATION' and enabled_flag = 'Y' and jurisdiction = p_jurisdiction
               and upper(regexp_replace(registration_number, '[^[:alnum:]]', ''))
                 = upper(regexp_replace(p_registration_number, '[^[:alnum:]]', ''));
            if l_exact is not null then
                raise_application_error(-20705, 'Party ' || l_exact || ' already has this registration number and country: choose it instead.');
            end if;
        end if;
        insert into xxcmp_parties (party_type, party_name, jurisdiction, registration_number, date_of_birth, data_provenance)
        values (p_party_type, trim(p_party_name), p_jurisdiction,
                case when p_party_type = 'ORGANIZATION' then trim(p_registration_number) end,
                case when p_party_type = 'PERSON' then p_date_of_birth end, 'SELF_DECLARED')
        returning party_id into l_id;
        return l_id;
    end create_party;

    procedure merge_parties(p_from_party_id in number, p_into_party_id in number, p_note in varchar2 default null) is
        l_from xxcmp_parties%rowtype;
        l_into xxcmp_parties%rowtype;
    begin
        if not xxfnd_privilege_pkg.has_privilege('PARTIES', 'MANAGE') then
            raise_application_error(-20711, 'Only Compliance can merge parties.');
        elsif p_from_party_id is null or p_into_party_id is null or p_from_party_id = p_into_party_id then
            raise_application_error(-20712, 'Choose another party to merge into.');
        end if;
        select * into l_from from xxcmp_parties where party_id = p_from_party_id for update;
        select * into l_into from xxcmp_parties where party_id = p_into_party_id for update;
        if l_from.party_type <> l_into.party_type then
            raise_application_error(-20713, 'An organisation cannot be merged into an individual, or the reverse.');
        elsif l_from.enabled_flag = 'N' or l_into.enabled_flag = 'N' then
            raise_application_error(-20714, 'Both parties must be enabled.');
        end if;

        -- everything recorded against the duplicate now belongs to the kept party
        update xxcmp_requests   set party_id = p_into_party_id where party_id = p_from_party_id;
        update xxcmp_cases      set party_id = p_into_party_id where party_id = p_from_party_id;
        update xxcmp_screenings set party_id = p_into_party_id where party_id = p_from_party_id;
        update xxcmp_alerts     set party_id = p_into_party_id where party_id = p_from_party_id;
        update xxcmp_case_notes set related_party_id = p_into_party_id where related_party_id = p_from_party_id;
        -- one beneficial-owner decision per case and owner
        delete from xxcmp_ubo_determinations u
         where u.owner_party_id = p_from_party_id
           and exists (select 1 from xxcmp_ubo_determinations k where k.case_id = u.case_id and k.owner_party_id = p_into_party_id);
        update xxcmp_ubo_determinations set owner_party_id = p_into_party_id where owner_party_id = p_from_party_id;
        -- contacts move as non-primary (the kept party keeps its primary contacts)
        update xxcmp_party_contacts set party_id = p_into_party_id, primary_flag = 'N' where party_id = p_from_party_id;
        -- relationships: a relationship between the two parties would point to itself
        delete from xxcmp_party_relationships
         where (subject_party_id = p_from_party_id and object_party_id = p_into_party_id)
            or (subject_party_id = p_into_party_id and object_party_id = p_from_party_id);
        update xxcmp_party_relationships set subject_party_id = p_into_party_id where subject_party_id = p_from_party_id;
        update xxcmp_party_relationships set object_party_id  = p_into_party_id where object_party_id  = p_from_party_id;
        -- documents
        update xxfnd_attached_documents set pk1_value = to_char(p_into_party_id)
         where entity_name = 'XXCMP_PARTIES' and pk1_value = to_char(p_from_party_id);

        -- the kept party's empty details are completed from the duplicate
        update xxcmp_parties
           set registration_number = nvl(registration_number, l_from.registration_number),
               entity_type         = nvl(entity_type, l_from.entity_type),
               incorporation_date  = nvl(incorporation_date, l_from.incorporation_date),
               date_of_birth       = nvl(date_of_birth, l_from.date_of_birth),
               nationality         = nvl(nationality, l_from.nationality),
               id_type             = nvl(id_type, l_from.id_type),
               id_number           = nvl(id_number, l_from.id_number),
               jurisdiction        = nvl(jurisdiction, l_from.jurisdiction),
               email               = nvl(email, l_from.email),
               phone               = nvl(phone, l_from.phone),
               website             = nvl(website, l_from.website),
               fax                 = nvl(fax, l_from.fax)
         where party_id = p_into_party_id;
        update xxcmp_parties
           set enabled_flag = 'N', merged_into_party_id = p_into_party_id, merge_note = substr(p_note, 1, 1000)
         where party_id = p_from_party_id;
    end merge_parties;

    function is_enabled(p_party_id in number) return varchar2 is
        l_flag xxcmp_parties.enabled_flag%type;
    begin
        select max(enabled_flag) into l_flag from xxcmp_parties where party_id = p_party_id;
        return case when l_flag = 'Y' then 'Y' else 'N' end;
    end is_enabled;

    function card_html(p_party_id in number) return clob is
        l_p      xxcmp_parties%rowtype;
        l_into   xxcmp_parties.party_number%type;
        l_html   clob;
        l_found  boolean := false;

        procedure row(p_label in varchar2, p_value in varchar2, p_raw in boolean default false) is
        begin
            if p_value is not null then
                l_html := l_html || '<dt class="t-AVPList-label">' || apex_escape.html(p_label) || '</dt>'
                               || '<dd class="t-AVPList-value">' || case when p_raw then p_value else apex_escape.html(p_value) end
                               || '</dd>';
            end if;
        end row;
    begin
        if p_party_id is null then
            return '<p class="u-color-subtle">No party linked yet.</p>';
        end if;
        for r in (select * from xxcmp_parties where party_id = p_party_id) loop     -- data security applies
            l_p := r;
            l_found := true;
        end loop;
        if not l_found then
            return '<p class="u-color-subtle">The party details are available to Compliance.</p>';
        end if;
        select max(party_number) into l_into from xxcmp_parties where party_id = l_p.merged_into_party_id;

        l_html := '<dl class="t-AVPList t-AVPList--leftAligned">';
        row('Party', case when xxfnd_privilege_pkg.has_privilege('PARTIES', 'VIEW')
                          then '<a href="' || apex_page.get_url(p_page => 21, p_items => 'P21_PARTY_ID',
                                                                 p_values => to_char(l_p.party_id), p_clear_cache => '21')
                               || '">' || apex_escape.html(l_p.party_number) || '</a>'
                          else apex_escape.html(l_p.party_number) end
                     || ' - ' || apex_escape.html(l_p.party_name), true);
        row('Type', xxfnd_util_pkg.lookup_meaning('PARTY_TYPE', l_p.party_type));
        if l_p.party_type = 'ORGANIZATION' then
            row('Registration No', l_p.registration_number);
            row('Entity Type', xxfnd_util_pkg.lookup_meaning('ENTITY_TYPE', l_p.entity_type));
            row('Incorporated', to_char(l_p.incorporation_date, 'DD-MON-YYYY'));
        else
            row('Identity Document', xxfnd_util_pkg.lookup_meaning('ID_DOCUMENT_TYPE', l_p.id_type)
                                     || nvl2(l_p.id_number, ' ' || l_p.id_number, null));
            row('Date of Birth', to_char(l_p.date_of_birth, 'DD-MON-YYYY'));
            row('Nationality', xxfnd_util_pkg.lookup_meaning('JURISDICTION', l_p.nationality));
        end if;
        row('Country', xxfnd_util_pkg.lookup_meaning('JURISDICTION', l_p.jurisdiction));
        row('Email', l_p.email);
        row('Phone', l_p.phone);
        row('Website', l_p.website);
        for c in (select nvl(contact_name, contact_value) as name, job_title,
                         coalesce(email, case when contact_type = 'EMAIL' then contact_value end) as email,
                         coalesce(phone, case when contact_type in ('PHONE', 'MOBILE') then contact_value end) as phone
                    from xxcmp_party_contacts
                   where party_id = p_party_id and enabled_flag = 'Y'
                   order by primary_flag desc, party_contact_id
                   fetch first 1 row only) loop
            row('Contact Person', c.name || nvl2(c.job_title, ' (' || c.job_title || ')', null)
                                  || nvl2(c.email, ', ' || c.email, null) || nvl2(c.phone, ', ' || c.phone, null));
        end loop;
        row('Status', case when l_p.merged_into_party_id is not null then 'Merged into ' || l_into
                           when l_p.enabled_flag = 'Y' then 'Active' else 'Disabled' end
                      || nvl2(l_p.last_verified_date, ' - verified ' || to_char(l_p.last_verified_date, 'DD-MON-YYYY'), null));
        return l_html || '</dl>';
    end card_html;

end xxcmp_party_pkg;
/

-- ==== 18b-security-framework-seed.sql
--------------------------------------------------------------------------------
-- C02 Security framework - seed (release R10). Runs after the roles are seeded.
--------------------------------------------------------------------------------
declare
    -- Variables must precede the local subprograms.
    c_staff  constant varchar2(200) := 'COMPLIANCE_OFFICER,COMPLIANCE_MANAGER,HEAD_OF_COMPLIANCE';
    c_rules  constant varchar2(200) := 'COMPLIANCE_MANAGER,HEAD_OF_COMPLIANCE,SYSTEM_ADMIN';
    c_all    constant varchar2(200) := 'REQUESTER,COMPLIANCE_OFFICER,COMPLIANCE_MANAGER,HEAD_OF_COMPLIANCE,SYSTEM_ADMIN';
    c_amp    constant varchar2(1)   := chr(38);   -- no literal ampersand: script runners substitute it

    procedure feature(p_code in varchar2, p_name in varchar2, p_group in varchar2, p_seq in number,
                      p_admin in varchar2, p_actions in varchar2) is
    begin
        merge into xxfnd_features t using (select p_code c from dual) s on (t.feature_code = s.c)
         when not matched then insert (feature_code, feature_name, feature_group, display_sequence, admin_flag)
                               values (p_code, p_name, p_group, p_seq, p_admin);
        for a in (select column_value action from table(apex_string.split(p_actions, ','))) loop
            merge into xxfnd_privileges t using (select p_code || '.' || a.action pc from dual) s
               on (t.privilege_code = s.pc)
             when not matched then insert (privilege_code, feature_code, action_code, privilege_name)
                                   values (s.pc, p_code, a.action,
                                           p_name || ' - ' || initcap(a.action));
        end loop;
    end feature;

    procedure pages(p_feature in varchar2, p_pages in varchar2) is
    begin
        for p in (select to_number(column_value) page_id from table(apex_string.split(p_pages, ','))) loop
            merge into xxfnd_feature_pages t using (select 'KYC' app_alias, p.page_id page_id from dual) s
               on (t.app_alias = s.app_alias and t.page_id = s.page_id)
             when not matched then insert (app_alias, page_id, feature_code) values ('KYC', p.page_id, p_feature);
        end loop;
    end pages;

    procedure grant_priv(p_roles in varchar2, p_privileges in varchar2) is
    begin
        for r in (select column_value role_code from table(apex_string.split(p_roles, ','))) loop
            for p in (select column_value privilege_code from table(apex_string.split(p_privileges, ','))) loop
                merge into xxfnd_role_privileges t
                using (select r.role_code rc, p.privilege_code pc from dual) s
                   on (t.role_code = s.rc and t.privilege_code = s.pc)
                 when not matched then insert (role_code, privilege_code) values (s.rc, s.pc);
            end loop;
        end loop;
    end grant_priv;

    procedure rule(p_role in varchar2, p_table in varchar2, p_type in varchar2, p_column in varchar2 default null) is
    begin
        merge into xxfnd_data_security_rules t
        using (select p_role r, p_table tb, p_type ty from dual) s
           on (t.role_code = s.r and t.table_name = s.tb and t.rule_type = s.ty)
         when not matched then insert (role_code, table_name, rule_type, column_name)
                               values (p_role, p_table, p_type, p_column);
    end rule;
begin
    xxfnd_util_pkg.set_install_mode(true);
    -- Business features
    feature('HOME',             'Home',                   'BUSINESS', 10, 'N', 'VIEW');
    feature('MY_TASKS',         'My Tasks',               'BUSINESS', 20, 'N', 'VIEW');
    feature('KYC_REQUESTS',     'KYC Requests',           'BUSINESS', 30, 'N', 'VIEW,CREATE,MANAGE');
    feature('PARTIES',          'Parties',                'BUSINESS', 40, 'N', 'VIEW,CREATE,MANAGE');
    feature('CASES',            'Cases',                  'BUSINESS', 50, 'N', 'VIEW,CREATE,MANAGE');
    feature('MONITORING',       'Monitoring Watchlist',   'BUSINESS', 60, 'N', 'VIEW,MANAGE');
    feature('DASHBOARD',        'Executive Dashboard',    'BUSINESS', 70, 'N', 'VIEW');
    -- Admin: Basic Setup
    feature('LOOKUPS',          'Lookups',                'BASIC_SETUP', 110, 'Y', 'VIEW,CREATE,MANAGE');
    feature('FLEXFIELDS',       'Flexfields (DFF)',       'BASIC_SETUP', 120, 'Y', 'VIEW,CREATE,MANAGE');
    feature('KYC_RULES',        'KYC Rules',              'BASIC_SETUP', 130, 'Y', 'VIEW,CREATE,MANAGE');
    feature('ATTACHMENTS',      'Attachments',            'BASIC_SETUP', 140, 'Y', 'VIEW,CREATE,MANAGE');
    feature('NOTIFICATIONS',    'Notifications',          'BASIC_SETUP', 150, 'Y', 'VIEW,CREATE,MANAGE');
    feature('RETENTION',        'Retention',              'BASIC_SETUP', 160, 'Y', 'VIEW,CREATE,MANAGE');
    -- Admin: Workflow and Integration
    feature('WORKFLOW_SETUP',   'Workflow Setup',         'WORKFLOW_INTEGRATION', 210, 'Y', 'VIEW,CREATE,MANAGE');
    feature('ALERT_RULES',      'Alert Rules',            'WORKFLOW_INTEGRATION', 220, 'Y', 'VIEW,CREATE,MANAGE');
    feature('WORKFLOW_MONITOR', 'Workflow Monitor',       'WORKFLOW_INTEGRATION', 230, 'Y', 'VIEW,MANAGE');
    feature('INTEGRATIONS',     'Integrations',           'WORKFLOW_INTEGRATION', 240, 'Y', 'VIEW,CREATE,MANAGE');
    -- Admin: Security
    feature('USERS_ACCESS',     'Users ' || c_amp || ' Access',     'SECURITY', 310, 'Y', 'VIEW,CREATE,MANAGE');
    feature('ROLES_PRIVILEGES', 'Roles ' || c_amp || ' Privileges', 'SECURITY', 320, 'Y', 'VIEW,CREATE,MANAGE');
    feature('DATA_SECURITY',    'Data Security',          'SECURITY', 330, 'Y', 'VIEW,CREATE,MANAGE');
    feature('AUDIT_LOG',        'Audit Log',              'SECURITY', 340, 'Y', 'VIEW');
    -- Admin: Application
    feature('APP_SETTINGS',     'Application Settings',   'APPLICATION', 410, 'Y', 'VIEW,MANAGE');
    feature('USAGE_FEEDBACK',   'Usage ' || c_amp || ' Feedback',   'APPLICATION', 420, 'Y', 'VIEW,MANAGE');
    -- Transitional: replaced by approval tasks in My Tasks (Chunk 4).
    feature('CHANGE_APPROVALS', 'Configuration Change Approvals', 'BASIC_SETUP', 190, 'Y', 'VIEW,MANAGE');

    -- Current pages -> features
    pages('HOME',             '1,10010,10050,90,91');
    pages('MY_TASKS',         '30,31,40,42');
    pages('PARTIES',          '20,21,22,23,24');
    pages('CASES',            '32');
    pages('LOOKUPS',          '101,102');
    pages('FLEXFIELDS',       '150,151,152,153');
    pages('KYC_RULES',        '160,161,162,163,164');
    pages('ATTACHMENTS',      '130,131,132,133,134,135,136,137,138,139');
    pages('NOTIFICATIONS',    '109,110');
    pages('RETENTION',        '112,113');
    pages('WORKFLOW_SETUP',   '114,115,165');
    pages('WORKFLOW_MONITOR', '41');
    pages('INTEGRATIONS',     '120,121,122,123,124,125');
    pages('USERS_ACCESS',     '103,104');
    pages('ROLES_PRIVILEGES', '105,106,107,108');
    pages('AUDIT_LOG',        '111');
    pages('APP_SETTINGS',     '10020,10021');
    pages('USAGE_FEEDBACK',   '10030,10031,10032,10033,10051,10052');

    -- Grants that reproduce the previous role-based access
    grant_priv(c_all,   'HOME.VIEW,MY_TASKS.VIEW');
    grant_priv(c_staff, 'PARTIES.VIEW,PARTIES.CREATE,PARTIES.MANAGE,CASES.VIEW,CASES.CREATE,CASES.MANAGE');
    grant_priv(c_rules, 'KYC_RULES.VIEW,KYC_RULES.CREATE,KYC_RULES.MANAGE,'
                     || 'ATTACHMENTS.VIEW,ATTACHMENTS.CREATE,ATTACHMENTS.MANAGE,'
                     || 'WORKFLOW_SETUP.VIEW,WORKFLOW_SETUP.CREATE,WORKFLOW_SETUP.MANAGE,'
                     || 'CHANGE_APPROVALS.VIEW,CHANGE_APPROVALS.MANAGE');
    grant_priv('HEAD_OF_COMPLIANCE,SYSTEM_ADMIN', 'AUDIT_LOG.VIEW');
    grant_priv('SYSTEM_ADMIN',
               'LOOKUPS.VIEW,LOOKUPS.CREATE,LOOKUPS.MANAGE,FLEXFIELDS.VIEW,FLEXFIELDS.CREATE,FLEXFIELDS.MANAGE,'
            || 'NOTIFICATIONS.VIEW,NOTIFICATIONS.CREATE,NOTIFICATIONS.MANAGE,RETENTION.VIEW,RETENTION.CREATE,RETENTION.MANAGE,'
            || 'ALERT_RULES.VIEW,ALERT_RULES.CREATE,ALERT_RULES.MANAGE,WORKFLOW_MONITOR.VIEW,WORKFLOW_MONITOR.MANAGE,'
            || 'INTEGRATIONS.VIEW,INTEGRATIONS.CREATE,INTEGRATIONS.MANAGE,'
            || 'USERS_ACCESS.VIEW,USERS_ACCESS.CREATE,USERS_ACCESS.MANAGE,'
            || 'ROLES_PRIVILEGES.VIEW,ROLES_PRIVILEGES.CREATE,ROLES_PRIVILEGES.MANAGE,'
            || 'DATA_SECURITY.VIEW,DATA_SECURITY.CREATE,DATA_SECURITY.MANAGE,'
            || 'APP_SETTINGS.VIEW,APP_SETTINGS.MANAGE,USAGE_FEEDBACK.VIEW,USAGE_FEEDBACK.MANAGE');

    -- Row access: compliance staff and administrators see everything; a requester
    -- sees only the requests for information addressed to them.
    for r in (select column_value role_code from table(apex_string.split(c_staff || ',SYSTEM_ADMIN', ','))) loop
        rule(r.role_code, 'XXCMP_PARTIES', 'ALL_ROWS');
        rule(r.role_code, 'XXCMP_RFIS',    'ALL_ROWS');
    end loop;
    rule('REQUESTER', 'XXCMP_RFIS', 'OWN_RECORDS', 'RECIPIENT_USER_NAME');

    xxfnd_util_pkg.set_install_mode(false);
    commit;
    xxfnd_vpd_pkg.apply_policies;
end;
/

begin
    xxfnd_ddl_pkg.mark_release('R10', 'Release 10: security framework (features, privileges, data security)');
    commit;
end;
/


-- ==== checks
select object_name, object_type, status from user_objects where object_name = 'XXCMP_PARTY_PKG' order by 2;
select feature_code, page_id from xxfnd_feature_pages where page_id = 24;
