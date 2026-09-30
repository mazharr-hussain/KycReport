"""Request page (205) approval in the browser: the Approval region shows who the request is with; an approver who
opens the request from KYC Requests (not My Tasks) gets the decision buttons; Request Information sends a question
to the requester; the requester never gets the decision.
Usage: request_approval_ui.py [app-id]   (SQLCL env var: the SQLcl command, default 'sql'; connection name kyc_local)"""
import os, random, re, string, subprocess, sys, time
from playwright.sync_api import sync_playwright

APP = sys.argv[1] if len(sys.argv) > 1 else '101'
HOST = 'http://localhost:8080'
SQLCL = os.environ.get('SQLCL', 'sql')
NAME = 'APPR ' + ''.join(random.choice(string.ascii_uppercase) for _ in range(12))
results = []


def ok(label, cond):
    results.append(bool(cond))
    print(('PASS ' if cond else 'FAIL ') + label)


def db(sql):
    out = subprocess.run([SQLCL, '-S', '-name', 'kyc_local'], input=f'set heading off feedback off pages 0\n{sql};\nexit\n',
                         capture_output=True, text=True).stdout
    return [l.strip() for l in out.splitlines() if l.strip() and 'JAVA_TOOL' not in l]


def wait_db(sql, secs=90):
    for _ in range(secs // 2):
        r = db(sql)
        if r and r[0] not in ('', '0'):
            return r[0]
        time.sleep(2)
    return None


# a submitted request that goes to Compliance (high-risk answers)
db(f"""declare
    l_app number;
    l_req number;
begin
    select application_id into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'KYC';
    apex_session.create_session(l_app, 1, 'REQ1');
    xxcmp_request_pkg.save_counterparty(l_req, 'NEW', null, 'ORGANIZATION', '{NAME}', null, null, null, null, null, 'AE',
                                        null, null, 'FINANCE', 'Approval UI test',
                                        p_contact_name => 'A Person', p_contact_email => 'a@b.co', p_contact_phone => '1');
    update xxcmp_request_answers x
       set answer_option_id = (select max(o.answer_option_id) keep (dense_rank last order by o.risk_points)
                                 from xxcmp_answer_options o where o.question_id = x.question_id and o.approval_status = 'APPROVED')
     where x.request_id = l_req;
    xxcmp_request_pkg.submit(l_req);
    commit;
    apex_session.delete_session;
end;
/
select 1 from dual""")
req = db(f"select request_id || ',' || request_number from xxcmp_requests where party_name = '{NAME}'")[0].split(',')
task = wait_db(f"select max(task_id) from apex_tasks where task_def_static_id = 'DOC_CHECKLIST_REVIEW' and detail_pk = '{req[0]}'")
ok(f'request {req[1]} submitted: checklist task {task}', task is not None)


def open_request(b, user):
    pg = b.new_page(viewport={'width': 1400, 'height': 1000})
    pg.goto(f'{HOST}/ords/r/xxcus/kyc/login')
    pg.fill('#P9999_USERNAME', user); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
    s = re.search(r'session=(\d+)', pg.url).group(1)
    pg.goto(f'{HOST}/ords/f?p={APP}:200:{s}'); pg.wait_for_load_state('networkidle')
    pg.locator('.a-IRR-search-field').first.fill(req[1]); pg.keyboard.press('Enter')
    pg.wait_for_load_state('networkidle'); pg.wait_for_timeout(1500)
    with pg.expect_navigation():
        pg.locator(f'.a-IRR-table a:has-text("{req[1]}")').first.click()
    pg.wait_for_load_state('networkidle')
    return pg


with sync_playwright() as p:
    b = p.chromium.launch(executable_path=os.environ.get('CHROME', '/opt/pw-browsers/chromium-1194/chrome-linux/chrome'),
                          args=['--no-sandbox'])
    pg = open_request(b, 'REQ1')
    appr = pg.inner_text('#approval_history') if pg.locator('#approval_history').count() else ''
    ok('the requester sees who the request is with: ' + ' '.join(appr.split())[:160],
       'Document' in appr and 'OFFICER1' in appr)
    ok('the requester has no decision buttons', pg.locator('button:has-text("Approve - Open Case")').count() == 0)
    pg.close()

    pg = open_request(b, 'OFFICER1')
    ok('an approver opening it from KYC Requests gets Approve / Reject / Request Information',
       all(pg.locator(f'button:has-text("{x}")').count() == 1 for x in ('Approve - Open Case', 'Reject Request', 'Request Information')))
    pg.fill('#P205_COMMENT', 'Please send the trade licence.')
    with pg.expect_navigation(): pg.click('button:has-text("Request Information")')
    pg.wait_for_load_state('networkidle')
    state = db(f"select state_code from apex_tasks where task_id = {task}")
    ok(f'information requested from the requester: {state}', state == ['INFO_REQUESTED'])
    b.close()
print(f'{sum(results)}/{len(results)} passed')
sys.exit(0 if all(results) else 1)
