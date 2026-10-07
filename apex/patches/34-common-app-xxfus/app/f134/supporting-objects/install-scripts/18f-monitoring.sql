--------------------------------------------------------------------------------
-- 18f Monitoring and dashboard seed  (release R14)
-- Lookups, starter alert rules (insert only: afterwards they belong to the administrators), the alert e-mail
-- template, pages -> features, tabs, console entry for Alert Rules, grants.
--------------------------------------------------------------------------------
declare
    c_staff constant varchar2(200) := 'COMPLIANCE_OFFICER,COMPLIANCE_MANAGER,HEAD_OF_COMPLIANCE';

    procedure lt(p_type in varchar2, p_meaning in varchar2) is
    begin
        merge into xxfnd_lookup_types t using (select p_type lookup_type from dual) s on (t.lookup_type = s.lookup_type)
         when not matched then insert (lookup_type, meaning, customization_level, application_code)
                               values (p_type, p_meaning, 'S', 'KYC');
    end lt;

    procedure lvs(p_type in varchar2, p_list in varchar2) is
        l_parts apex_t_varchar2;
        l_seq   pls_integer := 0;
    begin
        for v in (select column_value item from table(apex_string.split(p_list, '|'))) loop
            l_seq   := l_seq + 10;
            l_parts := apex_string.split(v.item, '=');
            merge into xxfnd_lookup_values t
            using (select p_type lookup_type, l_parts(1) lookup_code from dual) s
               on (t.lookup_type = s.lookup_type and t.lookup_code = s.lookup_code)
             when not matched then insert (lookup_type, lookup_code, meaning, display_sequence)
                                   values (p_type, l_parts(1), l_parts(2), l_seq);
        end loop;
    end lvs;

    procedure alert_rule(p_code in varchar2, p_name in varchar2, p_type in varchar2, p_days in number,
                         p_role in varchar2, p_review in varchar2, p_description in varchar2) is
    begin
        merge into xxcmp_alert_rules t using (select p_code rule_code from dual) s on (t.rule_code = s.rule_code)
         when not matched then insert (rule_code, rule_name, alert_type, days_before, recipient_role_code,
                                       start_review_flag, description)
                               values (p_code, p_name, p_type, p_days, p_role, p_review, p_description);
    end alert_rule;

    procedure page(p_feature in varchar2, p_page in number, p_tab in varchar2 default null, p_seq in number default null) is
    begin
        merge into xxfnd_feature_pages d
        using (select 'KYC' app_alias, p_page page_id from dual) s
           on (d.app_alias = s.app_alias and d.page_id = s.page_id)
         when matched then update set d.feature_code = p_feature,
                                      d.tab_label    = nvl(d.tab_label, p_tab),
                                      d.tab_sequence = nvl(d.tab_sequence, p_seq)
         when not matched then insert (app_alias, page_id, feature_code, tab_label, tab_sequence)
                               values ('KYC', p_page, p_feature, p_tab, p_seq);
    end page;

    procedure grant_to(p_roles in varchar2, p_privileges in varchar2) is
    begin
        for g in (select r.column_value role_code, p.column_value privilege_code
                    from table(apex_string.split(p_roles, ',')) r,
                         table(apex_string.split(p_privileges, ',')) p) loop
            merge into xxfnd_role_privileges t using (select g.role_code role_code, g.privilege_code privilege_code from dual) s
               on (t.role_code = s.role_code and t.privilege_code = s.privilege_code)
             when not matched then insert (role_code, privilege_code) values (s.role_code, s.privilege_code);
        end loop;
    end grant_to;
begin
    xxfnd_util_pkg.set_install_mode(true);

    lt('ALERT_TYPE', 'Monitoring Alert Types');
    lvs('ALERT_TYPE', 'REVIEW_DUE=Review due|REVIEW_OVERDUE=Review overdue|SLA_BREACH=Investigation past SLA'
        || '|DOCUMENT_EXPIRY=Document expiring|ADVERSE_SCREENING=Adverse screening after approval');
    lt('ALERT_STATUS', 'Monitoring Alert Status');
    lvs('ALERT_STATUS', 'OPEN=Open|ACKNOWLEDGED=Acknowledged|CLOSED=Closed');
    lt('REVIEW_STATUS', 'Review Status');
    lvs('REVIEW_STATUS', 'CURRENT=Current|DUE=Due|IN_REVIEW=In review|OVERDUE=Overdue');

    alert_rule('REVIEW_DUE', 'Review due within 30 days', 'REVIEW_DUE', 30, 'COMPLIANCE_OFFICER', 'N',
               'Tells the officers which parties come up for periodic review (the review itself starts automatically).');
    alert_rule('REVIEW_OVERDUE', 'Review overdue', 'REVIEW_OVERDUE', 0, 'COMPLIANCE_MANAGER', 'N',
               'The review date has passed and no newer approval exists.');
    alert_rule('SLA_BREACH', 'Investigation past its SLA', 'SLA_BREACH', 0, 'COMPLIANCE_MANAGER', 'N',
               'A case under investigation has passed its SLA due date.');
    alert_rule('DOCUMENT_EXPIRY', 'Party document expiring within 30 days', 'DOCUMENT_EXPIRY', 30, 'COMPLIANCE_OFFICER', 'Y',
               'A document of an approved party expires soon; once expired, an early review starts.');
    alert_rule('ADVERSE_SCREENING', 'Adverse screening after approval', 'ADVERSE_SCREENING', 0, 'COMPLIANCE_MANAGER', 'Y',
               'A screening recorded after approval is not clean (match, PEP, sanctions or adverse media): an early review starts.');

    merge into xxfnd_notification_templates t using (select 'KYC_ALERT' template_code from dual) s
       on (t.template_code = s.template_code)
     when not matched then insert (template_code, application_code, subject, body_html)
                           values ('KYC_ALERT', 'KYC', 'KYC alert: #ALERT_NAME#',
                                   '<p>#ALERT_MESSAGE#</p><p><a href="#LINK#">Open the alerts</a></p>');

    -- Monitoring: watchlist and alerts as tabs, the reassessment drawer; Alert Rules; Executive Dashboard.
    page('MONITORING', 220, 'Watchlist', 10);
    page('MONITORING', 221, 'Alerts', 20);
    page('MONITORING', 222);
    page('ALERT_RULES', 225);
    page('ALERT_RULES', 226);
    page('DASHBOARD', 230);
    update xxfnd_features
       set home_page_id = nvl(home_page_id, 225),
           icon_css     = nvl(icon_css, 'fa-bell-o'),
           description  = nvl(description, 'What the monitoring watches, who is alerted and when a review starts by itself.')
     where feature_code = 'ALERT_RULES';

    grant_to(c_staff, 'MONITORING.VIEW,MONITORING.MANAGE');
    grant_to('COMPLIANCE_MANAGER,HEAD_OF_COMPLIANCE', 'DASHBOARD.VIEW');
    grant_to('HEAD_OF_COMPLIANCE', 'ALERT_RULES.VIEW');

    xxfnd_util_pkg.set_install_mode(false);
    commit;
    xxfnd_ddl_pkg.mark_release('R14', 'Release 14: monitoring watchlist, alert rules, periodic reviews, executive dashboard');
    commit;
end;
/
