"""Request module in the browser: counterparty selection and matching (requester), department from the employee
profile, contact details, the exact-match block, Save as Draft and Edit, and the Compliance decision inside the
document checklist review (checklist task -> request page -> Merge into this party -> Approve).
Usage: request_party_ui.py [app-id]   (SQLCL env var: the SQLcl command, default 'sql'; connection name kyc_local)"""
import os, random, re, string, subprocess, sys
from playwright.sync_api import sync_playwright

APP = sys.argv[1] if len(sys.argv) > 1 else '134'
HOST = 'http://localhost:8080'
SQLCL = os.environ.get('SQLCL', 'sql')
TAG = ''.join(random.choice(string.ascii_uppercase) for _ in range(8))
EXISTING = f'Harbour Logistics {TAG} LLC'
results = []


def ok(label, cond):
    results.append(bool(cond))
    print(('PASS ' if cond else 'FAIL ') + label)


def db(sql):
    out = subprocess.run([SQLCL, '-S', '-name', 'kyc_local'], input=f'set heading off feedback off pages 0\n{sql};\nexit\n',
                         capture_output=True, text=True).stdout
    return [l.strip() for l in out.splitlines() if l.strip() and 'JAVA_TOOL' not in l]


def wait_db(sql, secs=90):
    import time
    for _ in range(secs // 2):
        r = db(sql)
        if r and r[0] not in ('', '0'):
            return r[0]
        time.sleep(2)
    return None


def login(b, user):
    pg = b.new_page(viewport={'width': 1400, 'height': 1000})
    pg.on('pageerror', lambda e: print('JS ERROR', user, str(e)[:200]))
    pg.goto(f'{HOST}/ords/r/xxcus/kyc/login')
    pg.fill('#P9999_USERNAME', user); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
    return pg, re.search(r'session=(\d+)', pg.url).group(1)


def goto(pg, s, page):
    pg.goto(f'{HOST}/ords/f?p={APP}:{page}:{s}'); pg.wait_for_load_state('networkidle')


def visible(pg, sel):
    return pg.locator(sel).first.is_visible()


db(f"""begin insert into xxcmp_parties (party_type, party_name, registration_number, jurisdiction, entity_type)
       values ('ORGANIZATION', '{EXISTING}', 'HL-{TAG}', 'AE', 'LLC'); commit; end;
/
select 1 from dual""")
party_id = db(f"select party_id from xxcmp_parties where party_name = '{EXISTING}'")[0]
db("begin update xxfnd_employees set department_name = 'Finance' where user_name = 'REQ1'; commit; end;\n/\nselect 1 from dual")

with sync_playwright() as p:
    b = p.chromium.launch(executable_path=os.environ.get('CHROME', '/opt/pw-browsers/chromium-1194/chrome-linux/chrome'),
                          args=['--no-sandbox'])
    # ------------------------------------------------------------ requester
    pg, s = login(b, 'REQ1')
    goto(pg, s, 201)
    ok('department from the employee profile, read only for a requester',
       pg.evaluate("apex.item('P201_REQUESTING_DEPARTMENT').getValue()") == 'FINANCE'
       and pg.locator('select#P201_REQUESTING_DEPARTMENT').count() == 0)
    ok('new counterparty by default: details shown, party search hidden',
       visible(pg, '#new_party') and not visible(pg, '#P201_PARTY_ID_CONTAINER'))
    pg.check('#P201_PARTY_SELECTION input[value=EXISTING]'); pg.wait_for_timeout(500)
    ok('existing counterparty: party search shown, new details hidden',
       visible(pg, '#P201_PARTY_ID_CONTAINER') and not visible(pg, '#new_party'))
    pg.check('#P201_PARTY_SELECTION input[value=NEW]'); pg.wait_for_timeout(500)
    pg.fill('#P201_PARTY_NAME', f'Harbor Logistics {TAG} L.L.C.'); pg.keyboard.press('Tab')
    pg.wait_for_timeout(2500)
    rows = pg.locator('#possible_matches a.kyc-use-party')
    ok(f'typing the name lists the similar existing party ({rows.count()} match)', rows.count() >= 1
       and EXISTING in pg.inner_text('#possible_matches'))
    ok('the confirmation switch appears only now', visible(pg, '#P201_MATCH_ACK_CONTAINER'))
    heads = pg.inner_text('#possible_matches thead') if pg.locator('#possible_matches thead').count() else pg.inner_text('#possible_matches')
    ok('matches show Registration No and Registration Match %', 'Registration No' in heads and 'Registration Match %' in heads)
    # same registration number and country as the existing party: refused even when confirmed
    pg.evaluate(f"""() => {{ apex.item('P201_REGISTRATION_NUMBER').setValue('hl {TAG}'); apex.item('P201_JURISDICTION').setValue('AE');
                           apex.item('P201_MATCH_ACK').setValue('Y'); apex.item('P201_CONTACT_NAME').setValue('Ops Desk');
                           apex.item('P201_CONTACT_EMAIL').setValue('ops@example.com'); apex.item('P201_CONTACT_PHONE').setValue('+971 4 111 2222'); }}""")
    pg.click('button:has-text("Next")'); pg.wait_for_timeout(3000)
    ok('same registration number and country is refused even when confirmed',
       'already has this registration number and country' in pg.inner_text('body'))
    pg.evaluate("apex.item('P201_MATCH_ACK').setValue('N')")
    pg.evaluate("""() => { apex.item('P201_REGISTRATION_NUMBER').setValue('HL2-' + Date.now()); apex.item('P201_ENTITY_TYPE').setValue('LLC');
                           apex.item('P201_JURISDICTION').setValue('AE'); }""")
    pg.click('button:has-text("Next")'); pg.wait_for_timeout(3000)
    ok('Next is refused until the requester chooses a party or confirms none is it',
       'choose one with Use this party, or confirm' in pg.inner_text('body'))
    pg.screenshot(path='request_matches.png', full_page=True)
    pg.locator('#possible_matches a.kyc-use-party').first.click(); pg.wait_for_timeout(800)
    ok('Use this party switches to the existing party',
       pg.evaluate("apex.item('P201_PARTY_SELECTION').getValue()") == 'EXISTING'
       and pg.evaluate("apex.item('P201_PARTY_ID').getValue()") == party_id)
    # back to new and confirm (Compliance will decide)
    pg.check('#P201_PARTY_SELECTION input[value=NEW]'); pg.wait_for_timeout(1500)
    pg.evaluate("apex.item('P201_MATCH_ACK').setValue('Y')")
    with pg.expect_navigation(): pg.click('button:has-text("Next")')
    pg.wait_for_load_state('networkidle')
    req = db(f"select request_id from xxcmp_requests where party_name = 'Harbor Logistics {TAG} L.L.C.'")
    ok(f'confirmed as new and saved (request {req}), on to the questionnaire', req and 'Questionnaire' in pg.title())
    req = req[0]
    with pg.expect_navigation(): pg.click('button:has-text("Save as Draft")')
    pg.wait_for_load_state('networkidle')
    ok('Save as Draft returns to KYC Requests', 'KYC Requests' in pg.title())
    # the list may hold many requests: search for this one
    pg.locator('.a-IRR-search-field').first.fill(f'Harbor Logistics {TAG}')
    pg.keyboard.press('Enter'); pg.wait_for_load_state('networkidle'); pg.wait_for_timeout(2000)
    edit = pg.locator(f'.a-IRR-table tr:has-text("Harbor Logistics {TAG}") a:has-text("Edit")')
    ok('the draft has an Edit link', edit.count() == 1)
    with pg.expect_navigation(): edit.click()
    pg.wait_for_load_state('networkidle')
    ok('Edit reopens the counterparty step with the saved values',
       pg.evaluate("apex.item('P201_PARTY_NAME').getValue()") == f'Harbor Logistics {TAG} L.L.C.')
    with pg.expect_navigation(): pg.click('button:has-text("Next")')
    pg.wait_for_load_state('networkidle')
    for fs in pg.locator('fieldset.kyc-q').all():
        fs.locator('label.kyc-q-option').last.click()
    with pg.expect_navigation(): pg.click('button:has-text("Next")')
    pg.wait_for_load_state('networkidle')
    with pg.expect_navigation(): pg.click('button:has-text("Submit Request")')
    pg.wait_for_load_state('networkidle')
    task = wait_db(f"select max(task_id) from apex_tasks where task_def_static_id = 'DOC_CHECKLIST_REVIEW' and detail_pk = '{req}'")
    ok(f'submitted: the workflow starts and Compliance has the checklist review task {task}', task is not None)
    ok('no separate Counterparty Match task',
       db(f"select count(*) from apex_tasks where task_def_static_id = 'COUNTERPARTY_MATCH' and detail_pk = '{req}'") == ['0'])
    pg.close()

    # ------------------------------------------------------------ Compliance
    pg, s = login(b, 'OFFICER1')
    goto(pg, s, 40)
    link = pg.locator(f'a[href*="p205_task_id={task}"]').first
    ok('the checklist review task is in My Tasks', link.count() == 1)
    with pg.expect_navigation(): link.click()
    pg.wait_for_load_state('networkidle')
    ok('the request page shows Counterparty Matching with the existing party',
       visible(pg, '#counterparty_matching') and EXISTING in pg.inner_text('#counterparty_matching'))
    ok('Approve waits for the match decision', pg.locator('button:has-text("Approve - Open Case")').count() == 0)
    pg.screenshot(path='request_compliance.png', full_page=True)
    pg.fill('#P205_MATCH_NOTE', 'Same company: spelling differs.')
    pg.locator('#match_candidates a.kyc-merge-party', has_text='Merge').first.click()
    with pg.expect_navigation():
        pg.locator('.ui-dialog .js-confirmBtn, .ui-dialog button:has-text("OK")').first.click()
    pg.wait_for_load_state('networkidle')
    r = db(f"select match_status || '/' || party_id || '/' || match_resolved_by from xxcmp_requests where request_id = {req}")
    ok(f'merged into the existing party: {r}', r == [f'MERGED/{party_id}/OFFICER1'])
    ok('after the decision the same task can be approved', pg.locator('button:has-text("Approve - Open Case")').count() == 1)
    with pg.expect_navigation(): pg.click('button:has-text("Approve - Open Case")')
    pg.wait_for_load_state('networkidle')
    case = wait_db(f"select max(case_id) from xxcmp_cases where request_id = {req}")
    ok(f'checklist approved in the same review: case {case} opened for the existing party', case is not None)
    pg.close()
    b.close()
db("begin update xxfnd_employees set department_name = null where user_name = 'REQ1'; commit; end;\n/\nselect 1 from dual")
print(f'{sum(results)}/{len(results)} passed')
sys.exit(0 if all(results) else 1)
