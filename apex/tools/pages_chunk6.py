#!/usr/bin/env python3
"""Chunk 6 pages: Monitoring (220-222), Alert Rules (225-226) and the Executive Dashboard (230).

220 Monitoring Watchlist  approved parties, next review, review status, open alerts; Reassess
221 Alerts                alerts raised by the monitoring rules; Handle
222 Reassessment          drawer: start an early (event-triggered) review, or acknowledge an alert
225 Alert Rules           admin list (Workflow & Integration)
226 Alert Rule            admin form
230 Executive Dashboard   key figures and charts
"""
import os, subprocess, sys
sys.path.insert(0, os.path.dirname(__file__))
from pagegen import col, item, list_page, form_page, fn_validation, breadcrumb_region
from pagekit import *  # noqa: F401,F403 (shared page building blocks)

# ===================================================================== 220 watchlist
WATCH_SQL = '''select q.*,
       apex_page.get_url(p_page => 211, p_items => 'P211_CASE_ID', p_values => to_char(q.case_id), p_clear_cache => '211') as open_url,
       case when q.review_request_id is not null then
            apex_page.get_url(p_page => 205, p_items => 'P205_REQUEST_ID', p_values => to_char(q.review_request_id), p_clear_cache => '205')
       end as review_url,
       case when q.review_request_id is null and xxfnd_privilege_pkg.has_privilege_yn('MONITORING', 'MANAGE') = 'Y' then
            apex_page.get_url(p_page => 222, p_items => 'P222_CASE_ID', p_values => to_char(q.case_id), p_clear_cache => '222')
       end as reassess_url,
       case when q.review_request_id is null and xxfnd_privilege_pkg.has_privilege_yn('MONITORING', 'MANAGE') = 'Y' then
            'Reassess'
       end as action
  from (
        select w.case_id,
               w.party_id,
               w.party_number,
               w.party_name,
               xxfnd_util_pkg.lookup_meaning('PARTY_TYPE', w.party_type) as party_type,
               w.case_number,
               xxfnd_util_pkg.lookup_meaning('RISK_TIER', w.risk_tier) as risk_tier,
               case when w.pep_flag = 'Y' then 'PEP' end as pep,
               case when w.enhanced_kyc_flag = 'Y' then 'Enhanced' end as kyc_level,
               w.approved_date,
               w.next_review_date,
               w.days_to_review,
               xxfnd_util_pkg.lookup_meaning('REVIEW_STATUS', w.review_status) as review_status,
               w.review_request_id,
               w.review_request_number,
               w.open_alerts
          from xxcmp_watchlist_v w
       ) q
 order by q.days_to_review'''
write('p00220-monitoring-watchlist.apx', list_page(
    220, 'Monitoring Watchlist', 'MONITORING-WATCHLIST', 'monitoring',
    'Every approved party with its latest approved case: when the next review is due, whether a review is running, '
    'and open alerts. Reviews start automatically ahead of the due date (KYC parameter REVIEW_LEAD_DAYS); '
    'Reassess starts an early review now.',
    WATCH_SQL,
    [col('CASE_ID', 'Case Id', 10, kind='hidden', dtype='NUMBER', pk=True),
     col('PARTY_ID', 'Party Id', 15, kind='hidden', dtype='NUMBER'),
     col('PARTY_NAME', 'Party', 20, link='OPEN_URL'),
     col('PARTY_NUMBER', 'Party Number', 25),
     col('PARTY_TYPE', 'Type', 30),
     col('CASE_NUMBER', 'Approved Case', 40),
     col('RISK_TIER', 'Risk', 50),
     col('PEP', 'PEP', 60),
     col('KYC_LEVEL', 'KYC Level', 70),
     col('APPROVED_DATE', 'Approved', 80, dtype='DATE'),
     col('NEXT_REVIEW_DATE', 'Next Review', 90, dtype='DATE'),
     col('DAYS_TO_REVIEW', 'Days to Review', 100, dtype='NUMBER'),
     col('REVIEW_STATUS', 'Review Status', 110),
     col('REVIEW_REQUEST_NUMBER', 'Review Request', 120, link='REVIEW_URL'),
     col('OPEN_ALERTS', 'Open Alerts', 130, dtype='NUMBER'),
     col('ACTION', 'Action', 140, link='REASSESS_URL'),
     col('REVIEW_REQUEST_ID', 'Review Request Id', 150, kind='hidden', dtype='NUMBER'),
     col('OPEN_URL', 'Open Url', 160, kind='hidden'),
     col('REVIEW_URL', 'Review Url', 170, kind='hidden'),
     col('REASSESS_URL', 'Reassess Url', 180, kind='hidden')]))

# ===================================================================== 221 alerts
ALERT_SQL = '''select q.*,
       case when q.case_id is not null then
            apex_page.get_url(p_page => 211, p_items => 'P211_CASE_ID', p_values => to_char(q.case_id), p_clear_cache => '211')
       end as open_url,
       case when q.status_code <> 'CLOSED' and xxfnd_privilege_pkg.has_privilege_yn('MONITORING', 'MANAGE') = 'Y' then
            apex_page.get_url(p_page => 222, p_items => 'P222_CASE_ID,P222_ALERT_ID',
                              p_values => to_char(q.case_id) || ',' || to_char(q.alert_id), p_clear_cache => '222')
       end as handle_url,
       case when q.status_code <> 'CLOSED' and xxfnd_privilege_pkg.has_privilege_yn('MONITORING', 'MANAGE') = 'Y' then
            'Handle'
       end as action
  from (
        select a.alert_id,
               a.case_id,
               a.creation_date as raised,
               xxfnd_util_pkg.lookup_meaning('ALERT_TYPE', r.alert_type) as alert_type,
               r.rule_name,
               p.party_name,
               a.alert_message,
               a.due_date,
               a.alert_status as status_code,
               xxfnd_util_pkg.lookup_meaning('ALERT_STATUS', a.alert_status) as alert_status,
               a.acknowledged_by,
               q.request_number as review_request
          from xxcmp_alerts a
          join xxcmp_alert_rules r on r.alert_rule_id = a.alert_rule_id
          left join xxcmp_parties p on p.party_id = a.party_id
          left join xxcmp_requests q on q.request_id = a.review_request_id
       ) q
 order by decode(q.status_code, 'OPEN', 1, 'ACKNOWLEDGED', 2, 3), q.raised desc'''
write('p00221-alerts.apx', list_page(
    221, 'Alerts', 'ALERTS', 'monitoring',
    'Alerts raised by the monitoring rules (Administration > Alert Rules). Handle an alert to acknowledge it or to '
    'start an early review; alerts close by themselves when a review starts or the subject moves on.',
    ALERT_SQL,
    [col('ALERT_ID', 'Alert Id', 10, kind='hidden', dtype='NUMBER', pk=True),
     col('CASE_ID', 'Case Id', 15, kind='hidden', dtype='NUMBER'),
     col('RAISED', 'Raised', 20, dtype='DATE', fmt='SINCE'),
     col('ALERT_TYPE', 'Type', 30),
     col('PARTY_NAME', 'Party', 40, link='OPEN_URL'),
     col('ALERT_MESSAGE', 'Alert', 50),
     col('DUE_DATE', 'Date', 60, dtype='DATE'),
     col('ALERT_STATUS', 'Status', 70),
     col('ACKNOWLEDGED_BY', 'Acknowledged By', 80),
     col('REVIEW_REQUEST', 'Review Request', 90),
     col('RULE_NAME', 'Rule', 100),
     col('ACTION', 'Action', 110, link='HANDLE_URL'),
     col('STATUS_CODE', 'Status Code', 120, kind='hidden'),
     col('OPEN_URL', 'Open Url', 130, kind='hidden'),
     col('HANDLE_URL', 'Handle Url', 140, kind='hidden')]))

# ===================================================================== 222 reassessment drawer
p = 222
CAN_START = ("type: expression\nlanguage: plsql\nplsqlExpression:\n    ```plsql\n"
             "    xxcmp_monitor_pkg.early_review_error(:P222_CASE_ID) is null\n    ```")
ALERT_OPEN = ("type: rowsReturned\nsqlQuery:\n    ```sql\n"
              "    select 1 from xxcmp_alerts where alert_id = :P222_ALERT_ID and alert_status = 'OPEN'\n    ```")
t = page_header(p, 'Reassessment', 'REASSESSMENT', 'monitoring',
                'Start an early (event-triggered) review of an approved party, with the reason; or acknowledge the alert '
                'when no review is needed. The review goes through the same intake, checklist and case as any request.',
                modal=True)
t += static_region('reassess', 'Reassessment', 10, slot='contentBody', template='blank-with-attributes')
t += static_region('buttons', 'Buttons', 90, slot='REGION_POSITION_03', template='buttons-container')
t += pitem(p, 'CASE_ID', 'hidden', None, 1, 'reassess', protect=True)
t += pitem(p, 'ALERT_ID', 'hidden', None, 2, 'reassess', protect=True)
t += pitem(p, 'PARTY', 'displayOnly', 'Party', 10, 'reassess',
           sql="""select p.party_name || ' (' || p.party_number || ') - ' || c.case_number
       || ', risk ' || xxfnd_util_pkg.lookup_meaning('RISK_TIER', c.risk_tier)
       || ', next review ' || to_char(c.next_review_date, 'DD-Mon-YYYY')
  from xxcmp_cases c join xxcmp_parties p on p.party_id = c.party_id
 where c.case_id = :P222_CASE_ID""")
t += pitem(p, 'ALERT', 'displayOnly', 'Alert', 20, 'reassess',
           sql="""select alert_message || ' (' || xxfnd_util_pkg.lookup_meaning('ALERT_STATUS', alert_status) || ')'
  from xxcmp_alerts where alert_id = :P222_ALERT_ID""",
           condition='type: itemIsNotNull\nitem: P222_ALERT_ID')
t += pitem(p, 'BLOCKED', 'displayOnly', 'Early Review', 30, 'reassess',
           sql='select xxcmp_monitor_pkg.early_review_error(:P222_CASE_ID) from dual',
           condition=CAN_START.replace('is null', 'is not null'))
t += pitem(p, 'REASON', 'textarea', 'Reason', 40, 'reassess', max_len=1000, height=3,
           sql='select alert_message from xxcmp_alerts where alert_id = :P222_ALERT_ID',
           help_text='Why the party is reassessed now; recorded on the review request.',
           condition=CAN_START)
t += button('cancel', 'CANCEL', 'Cancel', 10, 'buttons', 'CLOSE', action='definedByDynamicAction')
t += button('acknowledge', 'ACKNOWLEDGE', 'Acknowledge Alert', 20, 'buttons', 'EDIT', condition=ALERT_OPEN,
            auth='page-manage')
t += button('start', 'START', 'Start Early Review', 30, 'buttons', 'CREATE', hot=True, condition=CAN_START,
            auth='page-manage', confirm='Start an early review of this party now?')
t += '''    dynamicAction cancel-dialog (
        name: Cancel Dialog
        execution {
            sequence: 10
        }
        when {
            event: click
            selectionType: button
            button: @cancel
        }

        action cancel-dialog-action (
            action: cancelDialog
            execution {
                sequence: 10
                fireOnInit: false
            }
        )

    )

'''
t += fn_validation('reason-required', 'Reason required',
                   "if trim(:P222_REASON) is null then\n    return 'Give the reason for the early review.';\nend if;\n"
                   "return xxcmp_monitor_pkg.early_review_error(:P222_CASE_ID);",
                   'P222_REASON', 10, requests='START')
t += process('start-review', 'Start early review', '''declare
    l_request number;
begin
    l_request := xxcmp_monitor_pkg.trigger_early_review(
                     p_case_id  => :P222_CASE_ID,
                     p_reason   => :P222_REASON,
                     p_alert_id => :P222_ALERT_ID);
end;''', 10, button_='start', auth='page-manage', success='Early review started.')
t += process('acknowledge-alert', 'Acknowledge alert', 'xxcmp_monitor_pkg.acknowledge(:P222_ALERT_ID);', 20,
             button_='acknowledge', auth='page-manage', success='Alert acknowledged.')
t += close_dialog('START,ACKNOWLEDGE')
t += ')\n'
write('p00222-reassessment.apx', t)

# ===================================================================== 225-226 alert rules
RULES_SQL = '''select q.*,
       apex_page.get_url(p_page => 226, p_items => 'P226_ALERT_RULE_ID', p_values => to_char(q.alert_rule_id), p_clear_cache => '226') as edit_url
  from (
        select r.alert_rule_id,
               r.rule_code,
               r.rule_name,
               xxfnd_util_pkg.lookup_meaning('ALERT_TYPE', r.alert_type) as alert_type,
               r.days_before,
               nvl(xxfnd_util_pkg.lookup_meaning('RISK_TIER', r.risk_tier), 'All') as risk_tier,
               (select role_name from xxfnd_roles x where x.role_code = r.recipient_role_code) as recipients,
               case r.notify_flag when 'Y' then 'Yes' else 'No' end as notify,
               case r.start_review_flag when 'Y' then 'Yes' else 'No' end as start_review,
               case r.enabled_flag when 'Y' then 'Yes' else 'No' end as enabled,
               (select count(*) from xxcmp_alerts a where a.alert_rule_id = r.alert_rule_id and a.alert_status = 'OPEN') as open_alerts
          from xxcmp_alert_rules r
       ) q'''
write('p00225-alert-rules.apx', list_page(
    225, 'Alert Rules', 'ALERT-RULES', 'administration',
    'What the daily monitoring run watches: reviews coming due or overdue, investigations past their SLA, party '
    'documents expiring, adverse screenings after approval. Each rule says how many days ahead (or of grace), for which '
    'risk tier, which role is told, and whether an early review starts by itself.',
    RULES_SQL,
    [col('ALERT_RULE_ID', 'Alert Rule Id', 10, kind='hidden', dtype='NUMBER', pk=True),
     col('RULE_NAME', 'Rule', 20, link='EDIT_URL'),
     col('RULE_CODE', 'Code', 30),
     col('ALERT_TYPE', 'Watches', 40),
     col('DAYS_BEFORE', 'Days', 50, dtype='NUMBER'),
     col('RISK_TIER', 'Risk Tier', 60),
     col('RECIPIENTS', 'Alerted Role', 70),
     col('NOTIFY', 'E-mail', 80),
     col('START_REVIEW', 'Starts Review', 90),
     col('ENABLED', 'Enabled', 100),
     col('OPEN_ALERTS', 'Open Alerts', 110, dtype='NUMBER'),
     col('EDIT_URL', 'Edit Url', 120, kind='hidden')],
    create_label='Create Rule', form_page=226))

ROLES_LOV = ('sql', """select role_name as display_value, role_code as return_value
  from xxfnd_roles where enabled_flag = 'Y' order by role_name""", '- Nobody -')
write('p00226-alert-rule.apx', form_page(
    226, 'Alert Rule', 'ALERT-RULE', 'administration',
    'A monitoring rule. Days: how far ahead for review-due and expiring documents, days of grace for overdue reviews and SLA.',
    'XXCMP_ALERT_RULES', 'ALERT_RULE_ID',
    [item(226, 'ALERT_RULE_ID', 'hidden', None, 1, 'ALERT_RULE_ID', dtype='number', pk=True),
     item(226, 'RULE_CODE', 'textField', 'Code', 10, 'RULE_CODE', required=True, max_len=30,
          read_only_sql='select 1 from xxcmp_alert_rules where alert_rule_id = :P226_ALERT_RULE_ID'),
     item(226, 'RULE_NAME', 'textField', 'Name', 20, 'RULE_NAME', required=True, max_len=240),
     item(226, 'ALERT_TYPE', 'selectList', 'Watches', 30, 'ALERT_TYPE', required=True, lov=lookup_lov('ALERT_TYPE')),
     item(226, 'DAYS_BEFORE', 'numberField', 'Days', 40, 'DAYS_BEFORE', dtype='number', required=True, default='0',
          help_text='Review due and expiring documents: days ahead. Review overdue and SLA: days of grace.'),
     item(226, 'RISK_TIER', 'selectList', 'Risk Tier', 50, 'RISK_TIER', lov=lookup_lov('RISK_TIER', 'All risk tiers')),
     item(226, 'RECIPIENT_ROLE_CODE', 'selectList', 'Alerted Role', 60, 'RECIPIENT_ROLE_CODE', lov=ROLES_LOV),
     item(226, 'NOTIFY_FLAG', 'switch', 'Send E-mail', 70, 'NOTIFY_FLAG', default='Y'),
     item(226, 'START_REVIEW_FLAG', 'switch', 'Start Early Review', 80, 'START_REVIEW_FLAG', default='N',
          help_text='Expiring documents (once expired) and adverse screenings only.'),
     item(226, 'ENABLED_FLAG', 'switch', 'Enabled', 90, 'ENABLED_FLAG', default='Y'),
     item(226, 'DESCRIPTION', 'textarea', 'Description', 100, 'DESCRIPTION', max_len=1000, height=2)],
    validations=fn_validation('start-review-types', 'Start review only where it applies',
                              "if :P226_START_REVIEW_FLAG = 'Y' and :P226_ALERT_TYPE not in ('DOCUMENT_EXPIRY', 'ADVERSE_SCREENING') then\n"
                              "    return 'Only expiring documents and adverse screenings can start a review.';\nend if;\nreturn null;",
                              'P226_START_REVIEW_FLAG')
              + fn_validation('unique-code', 'Code is unique',
                              "for r in (select 1 from xxcmp_alert_rules where rule_code = upper(:P226_RULE_CODE)\n"
                              "           and alert_rule_id <> nvl(to_number(:P226_ALERT_RULE_ID), -1)) loop\n"
                              "    return 'A rule with this code already exists.';\nend loop;\nreturn null;",
                              'P226_RULE_CODE', 20),
    delete=False))

# ===================================================================== 230 dashboard
p = 230
t = page_header(p, 'Executive Dashboard', 'EXECUTIVE-DASHBOARD', 'monitoring',
                'Where KYC stands: open requests and cases, SLA and review backlog, decisions, and the risk profile of approved parties.')
t += breadcrumb_region('Executive Dashboard') + '\n'
t += classic('key_figures', 'Key Figures', '''select (select count(*) from xxcmp_requests where request_status in ('SUBMITTED','IN_PROGRESS')) as open_requests,
       (select count(*) from xxcmp_cases where case_status in ('INVESTIGATION','PENDING_APPROVAL')) as open_cases,
       (select count(*) from xxcmp_cases where case_status = 'INVESTIGATION' and sla_due_date < trunc(sysdate)) as past_sla,
       (select count(*) from xxcmp_watchlist_v where review_status in ('DUE','IN_REVIEW')) as reviews_due,
       (select count(*) from xxcmp_watchlist_v where review_status = 'OVERDUE') as reviews_overdue,
       (select count(*) from xxcmp_alerts where alert_status = 'OPEN') as open_alerts,
       (select count(*) from xxcmp_cases where case_status = 'APPROVED' and closed_date >= trunc(sysdate) - 30) as approved_30d,
       nvl((select round(avg(cast(closed_date as date) - cast(creation_date as date)), 1) from xxcmp_cases
             where closed_date >= trunc(sysdate) - 90), 0) as avg_days_to_decision
  from dual''',
             [('OPEN_REQUESTS', 'Open Requests'), ('OPEN_CASES', 'Open Cases'), ('PAST_SLA', 'Cases Past SLA'),
              ('REVIEWS_DUE', 'Reviews Due'), ('REVIEWS_OVERDUE', 'Reviews Overdue'), ('OPEN_ALERTS', 'Open Alerts'),
              ('APPROVED_30D', 'Approved (30 days)'), ('AVG_DAYS_TO_DECISION', 'Avg. Days to Decision (90 days)')], 10,
             badges=True)
t += chart('cases_by_status', 'Cases by Status', 20, '''select xxfnd_util_pkg.lookup_meaning('CASE_STATUS', case_status) as status, count(*) as cases
  from xxcmp_cases group by case_status order by count(*) desc''', 'STATUS', 'CASES', y_title='Cases', link=210)
t += chart('risk_profile', 'Approved Parties by Risk', 30, '''select nvl(xxfnd_util_pkg.lookup_meaning('RISK_TIER', risk_tier), 'Not rated') as risk, count(*) as parties
  from xxcmp_watchlist_v group by risk_tier order by count(*) desc''', 'RISK', 'PARTIES', chart_type='donut', new_row=False,
               link=220)
t += chart('requests_by_month', 'Requests per Month', 40, '''select to_char(trunc(creation_date, 'MM'), 'Mon YYYY') as month, count(*) as requests
  from xxcmp_requests
 where creation_date >= add_months(trunc(sysdate, 'MM'), -11)
 group by trunc(creation_date, 'MM') order by trunc(creation_date, 'MM')''', 'MONTH', 'REQUESTS', y_title='Requests', link=200)
t += chart('intake_outcomes', 'Intake Outcomes', 50, '''select nvl(xxfnd_util_pkg.lookup_meaning('KYC_INTAKE_OUTCOME', intake_outcome), 'Not evaluated') as outcome, count(*) as requests
  from xxcmp_requests where request_status <> 'DRAFT'
 group by intake_outcome order by count(*) desc''', 'OUTCOME', 'REQUESTS', chart_type='pie', new_row=False)
t += chart('reviews_ahead', 'Reviews in the Next 12 Months', 60, '''select to_char(trunc(next_review_date, 'MM'), 'Mon YYYY') as month, count(*) as reviews
  from xxcmp_watchlist_v
 where next_review_date < add_months(trunc(sysdate, 'MM'), 12)
 group by trunc(next_review_date, 'MM') order by trunc(next_review_date, 'MM')''', 'MONTH', 'REVIEWS', y_title='Reviews', link=220)
t += chart('alerts_by_type', 'Open Alerts by Type', 70, '''select xxfnd_util_pkg.lookup_meaning('ALERT_TYPE', r.alert_type) as alert_type, count(*) as alerts
  from xxcmp_alerts a join xxcmp_alert_rules r on r.alert_rule_id = a.alert_rule_id
 where a.alert_status = 'OPEN'
 group by r.alert_type order by count(*) desc''', 'ALERT_TYPE', 'ALERTS', orientation='horizontal', new_row=False,
               nodata='No open alerts.', link=221)
t += ')\n'
write('p00230-executive-dashboard.apx', t)

subprocess.run([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'ig_display_columns.py')], check=True)
print('chunk 6 pages written')
