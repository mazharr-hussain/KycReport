"""Request module in the browser (release 23): Create Request step 1 with the common party region (a new counterparty
becomes a Pending party), required justification, submit starts the KYC_REQUEST workflow, Compliance requests
information (Information Needed), the requester responds, Compliance approves (request and party Approved, case
opened); the list shows Status, KYC Required, Pending With and Action Date; a requester cancels a draft (its Pending
party is cancelled); Compliance merges a duplicate new counterparty into an existing party from the request page.
Usage: request_party_ui.py [app-id]   (SQLCL env var: the SQLcl command, default 'sql'; connection name kyc_local)"""
import os, random, re, string, subprocess, sys, time
from playwright.sync_api import sync_playwright

APP = sys.argv[1] if len(sys.argv) > 1 else '134'
HOST = 'http://localhost:8080'
SQLCL = os.environ.get('SQLCL', 'sql')
TAG = ''.join(random.choice(string.ascii_uppercase) for _ in range(6))
results = []


def ok(label, cond):
    results.append(bool(cond))
    print(('PASS ' if cond else 'FAIL ') + label)


def db(sql):
    out = subprocess.run([SQLCL, '-S', '-name', 'kyc_local'], input=f'set heading off feedback off pages 0\n{sql};\nexit\n',
                         capture_output=True, text=True).stdout
    return [l.strip() for l in out.splitlines() if l.strip() and 'JAVA_TOOL' not in l]


def login(b, user):
    pg = b.new_page(viewport={'width': 1400, 'height': 1100})
    pg.on('pageerror', lambda e: print('JS ERROR', str(e)[:200]))
    pg.goto(f'{HOST}/ords/r/xxcus/kyc/login')
    pg.fill('#P9999_USERNAME', user); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
    return pg, re.search(r'session=(\d+)', pg.url).group(1)


def open_request(pg, s, number):
    pg.goto(f'{HOST}/ords/f?p={APP}:200:{s}'); pg.wait_for_load_state('networkidle')
    pg.locator('.a-IRR-search-field').first.fill(number); pg.keyboard.press('Enter')
    pg.wait_for_load_state('networkidle'); pg.wait_for_timeout(1500)
    with pg.expect_navigation():
        pg.locator(f'.a-IRR-table a:has-text("{number}")').first.click()
    pg.wait_for_load_state('networkidle')


def messages(pg):
    return ' '.join(m for m in pg.locator('.t-Alert-body, .a-Notification-item, .t-Form-error').all_inner_texts() if m.strip())


def step1(pg, s, name, reg, next_button='Next'):
    """Create Request step 1: a new organisation in the common party region."""
    pg.goto(f'{HOST}/ords/f?p={APP}:201:{s}'); pg.wait_for_load_state('networkidle')
    pg.fill('#P0_PARTY_NAME', name); pg.select_option('#P0_PARTY_JURISDICTION', 'AE')
    pg.fill('#P0_PARTY_REGISTRATION_NUMBER', reg); pg.wait_for_timeout(800)
    pg.select_option('#P0_PARTY_ENTITY_TYPE', 'LLC')
    pg.fill('#P0_PARTY_EMAIL', 'info@ui.example')
    if pg.locator('select#P201_REQUESTING_DEPARTMENT').count():
        pg.select_option('#P201_REQUESTING_DEPARTMENT', 'FINANCE')
    pg.fill('#P201_JUSTIFICATION', 'UI test supplier')
    with pg.expect_navigation():
        pg.click(f'button:has-text("{next_button}")')
    pg.wait_for_load_state('networkidle')


with sync_playwright() as p:
    b = p.chromium.launch(executable_path=os.environ.get('CHROME', '/opt/pw-browsers/chromium-1194/chrome-linux/chrome'),
                          args=['--no-sandbox'])
    # ------------------------------------------------------------ requester: step 1 with the common party region
    pg, s = login(b, 'REQ1')
    pg.goto(f'{HOST}/ords/f?p={APP}:201:{s}'); pg.wait_for_load_state('networkidle')
    ok('step 1 shows the common party region; the contact person fields are hidden (build option)',
       pg.locator('#party-form').is_visible() and pg.locator('#P201_CONTACT_NAME').count() == 0)
    pg.fill('#P0_PARTY_NAME', f'No Reason {TAG}')
    pg.click('button:has-text("Next")'); pg.wait_for_timeout(1500)
    ok('the business justification is required', 'Business Justification must have some value' in messages(pg))
    name = f'UI Org {TAG}'
    step1(pg, s, name, f'UI-{TAG}')
    row = db(f"select request_id || ',' || request_number || ',' || party_id from xxcmp_requests where party_name = '{name}'")[0].split(',')
    rid, rno, pid = row
    ok('Next saved the request and created its party as Pending',
       db(f"select party_status from xxcmp_parties where party_id = {pid}") == ['PENDING'])
    db(f"""update xxcmp_request_answers x set answer_option_id = (select max(o.answer_option_id) keep (dense_rank last order by o.risk_points)
            from xxcmp_answer_options o where o.question_id = x.question_id and o.approval_status = 'APPROVED') where x.request_id = {rid};
          commit""")
    pg.reload(); pg.wait_for_load_state('networkidle')
    with pg.expect_navigation():
        pg.click('button:has-text("Next")')
    pg.wait_for_load_state('networkidle')
    with pg.expect_navigation():
        pg.click('button:has-text("Submit Request")')
    pg.wait_for_load_state('networkidle')
    task = None
    for _ in range(45):
        t = db(f"select max(task_id) from apex_tasks where detail_pk = '{rid}' and task_def_static_id = 'DOC_CHECKLIST_REVIEW'")
        if t and t[0]:
            task = t[0]; break
        time.sleep(2)
    ok(f'Submit starts the workflow: checklist task {task}', task is not None
       and db(f"select request_status from xxcmp_requests where request_id = {rid}") == ['IN_PROGRESS'])
    pg.close()

    # ------------------------------------------------------------ Compliance asks for information
    pg, s = login(b, 'OFFICER1')
    open_request(pg, s, rno)
    ok('Compliance gets Approve / Reject / Request Information and no Raise RFI',
       all(pg.locator(f'button:has-text("{x}")').count() == 1 for x in ('Approve - Open Case', 'Reject Request', 'Request Information'))
       and pg.locator('button:has-text("Raise RFI")').count() == 0)
    info = ' '.join(pg.inner_text('#request').split())
    ok('the request shows Status, KYC Required, Pending With and Action Date: ' + info[:150],
       'Status In Progress' in info and 'KYC Required Yes' in info and 'Pending With Compliance' in info and 'Action Date' in info)
    pg.fill('#P205_COMMENT', 'Please upload the trade licence.')
    with pg.expect_navigation():
        pg.click('button:has-text("Request Information")')
    pg.wait_for_load_state('networkidle')
    ok('Request Information: the request is Information Needed',
       db(f"select request_status from xxcmp_requests where request_id = {rid}") == ['INFO_NEEDED'])
    pg.close()

    # ------------------------------------------------------------ the requester responds
    pg, s = login(b, 'REQ1')
    open_request(pg, s, rno)
    ok('the requester sees the question, Edit Request, Cancel Request and Respond',
       'Please upload the trade licence.' in pg.inner_text('#respond')
       and all(pg.locator(f'button:has-text("{x}")').count() == 1 for x in ('Edit Request', 'Cancel Request', 'Respond')))
    pg.fill('#P205_RESPONSE', 'Uploaded now.')
    with pg.expect_navigation():
        pg.click('button:has-text("Respond")')
    pg.wait_for_load_state('networkidle')
    ok('Respond: the request is back In Progress',
       db(f"select request_status from xxcmp_requests where request_id = {rid}") == ['IN_PROGRESS'])
    pg.close()

    # ------------------------------------------------------------ Compliance approves
    pg, s = login(b, 'OFFICER1')
    open_request(pg, s, rno)
    with pg.expect_navigation():
        pg.click('button:has-text("Approve - Open Case")')
    pg.wait_for_load_state('networkidle')
    final = None
    for _ in range(30):
        final = db(f"""select r.request_status || ',' || p.party_status || ',' || (select count(*) from xxcmp_cases c where c.request_id = r.request_id)
                         from xxcmp_requests r join xxcmp_parties p on p.party_id = r.party_id where r.request_id = {rid}""")
        if final and final[0].endswith(',1'):
            break
        time.sleep(2)
    ok(f'Approve: request and party Approved, case opened ({final})', final == ['APPROVED,APPROVED,1'])
    pg.goto(f'{HOST}/ords/f?p={APP}:200:{s}'); pg.wait_for_load_state('networkidle')
    heads = [h.strip() for h in pg.locator('.a-IRR-table .a-IRR-header').all_inner_texts()]
    ok('the list shows Status, KYC Required, Pending With, Action Date; Type and Intake Score are hidden',
       all(x in heads for x in ('Status', 'KYC Required', 'Pending With', 'Action Date'))
       and 'Type' not in heads and 'Intake Score' not in heads)

    # ------------------------------------------------------------ Compliance merges a duplicate counterparty
    existing = db(f"""select party_number || ',' || party_name from xxcmp_parties where party_id = {pid}""")[0].split(',', 1)
    pg.close()
    pg, s = login(b, 'REQ2')
    dup = existing[1].replace('UI Org', 'UI Orgg')
    step1(pg, s, dup, f'UI2-{TAG}', 'Save as Draft')
    drow = db(f"select request_number || ',' || party_id from xxcmp_requests where party_name = '{dup}'")[0].split(',')
    pg.close()
    pg, s = login(b, 'OFFICER1')
    open_request(pg, s, drow[0])
    link = pg.locator(f'#match_candidates tr:has-text("{existing[0]}") a.kyc-merge-party')
    ok('Compliance sees the approved party as a possible duplicate', link.count() == 1)
    if link.count():
        link.click()
        with pg.expect_navigation():
            pg.locator('.ui-dialog .js-confirmBtn, .ui-dialog button:has-text("OK")').first.click()
        pg.wait_for_load_state('networkidle')
    r = db(f"""select r.party_id || ',' || d.enabled_flag || ',' || d.merged_into_party_id || ',' || r.match_status
                 from xxcmp_requests r, xxcmp_parties d where r.request_number = '{drow[0]}' and d.party_id = {drow[1]}""")
    ok(f'merged: the request now uses the existing party, the duplicate is disabled ({r})', r == [f'{pid},N,{pid},MERGED'])
    pg.close()

    # ------------------------------------------------------------ the requester cancels a draft
    pg, s = login(b, 'REQ1')
    cname = f'Cancel Org {TAG}'
    step1(pg, s, cname, f'CX-{TAG}', 'Save as Draft')
    crow = db(f"select request_number || ',' || party_id from xxcmp_requests where party_name = '{cname}'")[0].split(',')
    open_request(pg, s, crow[0])
    pg.click('button:has-text("Cancel Request")')
    with pg.expect_navigation():
        pg.locator('.ui-dialog .js-confirmBtn, .ui-dialog button:has-text("OK")').first.click()
    pg.wait_for_load_state('networkidle')
    r = db(f"""select r.request_status || ',' || p.party_status from xxcmp_requests r join xxcmp_parties p on p.party_id = r.party_id
                where r.request_number = '{crow[0]}'""")
    ok(f'Cancel Request: request and its Pending party Cancelled ({r})', r == ['CANCELLED,CANCELLED'])
    b.close()
print(f'{sum(results)}/{len(results)} passed')
sys.exit(0 if all(results) else 1)
