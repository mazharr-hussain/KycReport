--------------------------------------------------------------------------------
-- 18f Monitoring and dashboard seed  (release R14)
-- Starter alert rules (insert only: afterwards they belong to the administrators).
--   Release 87: the lookups, the alert notification, pages, features and grants are registered in COMMON by 18h.
--------------------------------------------------------------------------------
declare
    procedure alert_rule(p_code in varchar2, p_name in varchar2, p_type in varchar2, p_days in number,
                         p_role in varchar2, p_review in varchar2, p_description in varchar2) is
    begin
        merge into xxcmp_alert_rules t using (select p_code rule_code from dual) s on (t.rule_code = s.rule_code)
         when not matched then insert (rule_code, rule_name, alert_type, days_before, recipient_role_code,
                                       start_review_flag, description)
                               values (p_code, p_name, p_type, p_days, p_role, p_review, p_description);
    end alert_rule;
begin
    xxfnd_util_pkg.set_install_mode(true);
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

    xxfnd_util_pkg.set_install_mode(false);
    commit;
    xxfnd_ddl_pkg.mark_release('R14', 'Release 14: monitoring watchlist, alert rules, periodic reviews, executive dashboard');
    commit;
end;
/
