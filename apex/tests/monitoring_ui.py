"""Chunk 6 in the browser: OFFICER1 reassesses a party from the Monitoring Watchlist (220 -> drawer 222) and
acknowledges an alert from Alerts (221 -> 222); MGR1 opens the Executive Dashboard (230) with its charts.
Needs an approved party without an open review (kyc_flow_test.sql makes one); each run starts one review.
ADMIN creates a test alert rule on the Alert Rules form (removed again at the end).
Usage: monitoring_ui.py [app-id]   (SQLCL env var: the SQLcl command, default 'sql'; connection name kyc_local)"""
import os, re, subprocess, sys
from playwright.sync_api import sync_playwright

APP = sys.argv[1] if len(sys.argv) > 1 else '101'
HOST = 'http://localhost:8080'
SQLCL = os.environ.get('SQLCL', 'sql')
results = []


def ok(label, cond):
    results.append(cond)
    print(('PASS ' if cond else 'FAIL ') + label)


def db(sql):
    out = subprocess.run([SQLCL, '-S', '-name', 'kyc_local'], input=f'set heading off feedback off pages 0\n{sql};\nexit\n',
                         capture_output=True, text=True).stdout
    return [l.strip() for l in out.splitlines() if l.strip() and 'JAVA_TOOL' not in l]


def login(b, user):
    pg = b.new_page(viewport={'width': 1400, 'height': 900})
    pg.on('pageerror', lambda e: print('JS ERROR', user, str(e)[:200]))
    pg.goto(f'{HOST}/ords/r/xxcus/kyc/login')
    pg.fill('#P9999_USERNAME', user); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
    return pg, re.search(r'session=(\d+)', pg.url).group(1)


def goto(pg, s, page):
    pg.goto(f'{HOST}/ords/f?p={APP}:{page}:{s}'); pg.wait_for_load_state('networkidle')


def confirm_ok(pg):
    """Confirmation dialog of a drawer button: rendered by the drawer or by the page that opened it."""
    sel = '.ui-dialog .js-confirmBtn, .ui-dialog--apex-confirm button:has-text("OK"), .ui-dialog button:has-text("OK")'
    for _ in range(40):
        for scope in (pg.frame_locator('iframe').first, pg):
            btn = scope.locator(sel).first
            if btn.count() and btn.is_visible():
                btn.click()
                return
        pg.wait_for_timeout(250)
    raise AssertionError('no confirmation dialog')


def drawer_submit(pg, label, confirm=False):
    frame = pg.frame_locator('iframe').first
    frame.locator(f'button:has-text("{label}")').click()
    if confirm:
        confirm_ok(pg)
    pg.locator('.ui-dialog iframe').wait_for(state='detached', timeout=30000)
    pg.wait_for_timeout(1500)   # the report behind refreshes


with sync_playwright() as p:
    b = p.chromium.launch(executable_path=os.environ.get('CHROME', '/opt/pw-browsers/chromium-1194/chrome-linux/chrome'),
                          args=['--no-sandbox'])
    # --------------------------------------------------- OFFICER1: reassess
    pg, s = login(b, 'OFFICER1')
    goto(pg, s, 220)
    ok('watchlist shows the approved parties', pg.locator('.a-IRR-table tr').count() > 1)
    tabs = [x.inner_text().strip() for x in pg.query_selector_all('#feature-tabs .t-Tabs-label')]
    ok(f'Monitoring tabs: {tabs}', tabs == ['Watchlist', 'Alerts'])
    link = pg.locator('.a-IRR-table a:has-text("Reassess")').first
    ok('a party without a review in progress can be reassessed', link.count() == 1)
    party = link.locator('xpath=ancestor::tr').locator('td').nth(0).inner_text().strip()
    link.click()
    frame = pg.frame_locator('iframe').first
    frame.locator('#P222_REASON').wait_for()
    case = frame.locator('#P222_CASE_ID').input_value()
    frame.locator('button:has-text("Start Early Review")').click()
    confirm_ok(pg)
    frame.locator('text=Give the reason for the early review').first.wait_for(timeout=30000)
    req = db(f"""select request_number from xxcmp_requests
                  where parent_case_id = {case} and request_type = 'EVENT_TRIGGERED_REVIEW'""")
    ok(f'without a reason the drawer refuses and starts nothing ({req})', req == [])
    frame.locator('button:has-text("Cancel")').click()
    pg.locator('.ui-dialog iframe').wait_for(state='detached', timeout=30000)
    pg.locator('.a-IRR-table a:has-text("Reassess")').first.click()
    frame = pg.frame_locator('iframe').first
    frame.locator('#P222_REASON').wait_for()
    case = frame.locator('#P222_CASE_ID').input_value()
    frame.locator('#P222_REASON').fill('Change of ownership reported by the business.')
    drawer_submit(pg, 'Start Early Review', confirm=True)
    req = db(f"""select request_number || '/' || request_type || '/' || trigger_source from xxcmp_requests
                  where parent_case_id = {case} and request_type = 'EVENT_TRIGGERED_REVIEW'""")
    ok(f'early review started from the watchlist: {req}', len(req) == 1 and req[0].endswith('EVENT_TRIGGERED_REVIEW/MANUAL'))
    status = db(f"select review_status from xxcmp_watchlist_v where case_id = {case}")
    ok(f'the party is now {status}', status in (['IN_REVIEW'], ['OVERDUE']))

    pg.close()

    # --------------------------------------------------- ADMIN: alert rule
    pg, s = login(b, 'ADMIN')
    goto(pg, s, 225)
    ok('Alert Rules lists the starter rules', pg.locator('.a-IRR-table a:has-text("Review overdue")').count() == 1)
    pg.click('button:has-text("Create Rule")')
    pg.frame_locator('iframe').first.locator('#P226_RULE_CODE').wait_for()
    f = [x for x in pg.frames if x != pg.main_frame][-1]
    code = 'UI_TEST_' + str(os.getpid())
    f.evaluate("""(c) => { apex.item('P226_RULE_CODE').setValue(c);
        apex.item('P226_RULE_NAME').setValue('UI test: reviews in the next 5 years');
        apex.item('P226_ALERT_TYPE').setValue('REVIEW_DUE'); apex.item('P226_DAYS_BEFORE').setValue('1900');
        apex.item('P226_RECIPIENT_ROLE_CODE').setValue('COMPLIANCE_OFFICER');
        apex.item('P226_NOTIFY_FLAG').setValue('N'); apex.item('P226_START_REVIEW_FLAG').setValue('Y'); }""", code)
    f.click('button:has-text("Create")')
    f.wait_for_selector('text=Only expiring documents and adverse screenings can start a review', timeout=30000)
    ok('a review-due rule cannot start reviews (validation)',
       db(f"select count(*) from xxcmp_alert_rules where rule_code = '{code}'") == ['0'])
    f.evaluate("apex.item('P226_START_REVIEW_FLAG').setValue('N')")
    f.click('button:has-text("Create")')
    pg.locator('.ui-dialog iframe').wait_for(state='detached', timeout=30000)
    ok('rule created from the admin form', db(f"select count(*) from xxcmp_alert_rules where rule_code = '{code}'") == ['1'])
    pg.close()
    db('declare l number; begin l := xxcmp_monitor_pkg.run_alerts; commit; end;\n/\nselect 1 from dual')
    raised = db(f"""select count(*) from xxcmp_alerts a join xxcmp_alert_rules r on r.alert_rule_id = a.alert_rule_id
                     where r.rule_code = '{code}'""")
    ok(f'the monitoring run raised {raised} alert(s) for the new rule', raised != ['0'])

    # --------------------------------------------------- OFFICER1: alert
    pg, s = login(b, 'OFFICER1')
    goto(pg, s, 221)
    handle = pg.locator('.a-IRR-table tr', has_text='Open').locator('a:has-text("Handle")').first
    ok('open alerts can be handled', handle.count() == 1)
    handle.click()
    frame = pg.frame_locator('iframe').first
    frame.locator('#P222_ALERT_ID').wait_for(state='attached')
    alert = frame.locator('#P222_ALERT_ID').input_value()
    before = db(f"select alert_status from xxcmp_alerts where alert_id = {alert}")
    if frame.locator('button:has-text("Acknowledge Alert")').count():
        drawer_submit(pg, 'Acknowledge Alert')
        after = db(f"select alert_status || ' ' || acknowledged_by from xxcmp_alerts where alert_id = {alert}")
        ok(f'alert {alert} {before} -> {after}', after == ['ACKNOWLEDGED OFFICER1'])
    else:
        ok(f'alert {alert} is {before}: acknowledge not offered', before != ['OPEN'])
    pg.close()
    db(f"""begin
    delete from xxcmp_alerts where alert_rule_id = (select alert_rule_id from xxcmp_alert_rules where rule_code = '{code}');
    delete from xxcmp_alert_rules where rule_code = '{code}';
    commit;
end;
/
select 1 from dual""")

    # --------------------------------------------------- MGR1: dashboard
    pg, s = login(b, 'MGR1')
    goto(pg, s, 230)
    figures = pg.inner_text('#key_figures')
    ok('key figures shown', 'Open Cases' in figures and 'Reviews Due' in figures)
    pg.wait_for_timeout(2500)
    charts = pg.locator('.oj-dvt-chart, oj-chart, svg').count()
    ok(f'charts rendered ({charts} chart elements)', charts >= 4)
    pg.screenshot(path='dashboard.png', full_page=True)
    goto(pg, s, 220)
    pg.screenshot(path='watchlist.png', full_page=True)
    pg.close()
    b.close()
print(f'{sum(results)}/{len(results)} passed')
sys.exit(0 if all(results) else 1)
