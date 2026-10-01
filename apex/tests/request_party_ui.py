"""Request module in the browser (release 25): the 4-step wizard (Counterparty, Party Details, Questionnaire, Review and
Submit) with the common Global Page regions; the similar-parties dialog (MATCH_ACK_FLAG); the read-only request view
(Back only); the approval screen from My Tasks (Approve / Reject / Request Information at the top and the bottom, a
comment required for Request Information); the requester answers on the review step; the approval history table;
the list's Edit / Withdraw action; withdraw then cancel; Compliance merges a duplicate party in a popup.
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


def answer_matches(pg, none=True, wait=2500):
    pg.wait_for_timeout(wait)
    btn = pg.locator('.ui-dialog button:has-text("%s")' % ('Confirmed' if none else 'possible match exists'))
    if btn.count() and btn.first.is_visible():
        btn.first.click()
        return True
    return False


def click_nav(pg, label):
    with pg.expect_navigation():
        pg.locator('button', has_text=re.compile(r'^\s*%s\s*$' % label)).first.click()
    pg.wait_for_load_state('networkidle')


def step1(pg, s, name, reg, none=True):
    """Counterparty step: a new organisation in the common party form; Next (answers the similar-parties dialog)."""
    pg.goto(f'{HOST}/ords/f?p={APP}:201:{s}'); pg.wait_for_load_state('networkidle')
    pg.fill('#P0_PARTY_NAME', name); pg.select_option('#P0_PARTY_JURISDICTION', 'AE')
    pg.fill('#P0_PARTY_REGISTRATION_NUMBER', reg); pg.wait_for_timeout(800)
    pg.select_option('#P0_PARTY_ENTITY_TYPE', 'LLC')
    pg.select_option('#P0_PARTY_REGISTRATION_TYPE', 'COMMERCIAL_REGISTRATION')
    pg.fill('#P0_PARTY_EMAIL', 'info@ui.example')
    pg.select_option('#P201_BUSINESS_RELATIONSHIP', 'VENDOR')
    if pg.locator('select#P201_REQUESTING_DEPARTMENT').count():
        pg.select_option('#P201_REQUESTING_DEPARTMENT', 'FINANCE')
    pg.fill('#P201_JUSTIFICATION', 'UI test supplier')
    pg.locator('button', has_text=re.compile(r'^\s*Next\s*$')).first.click()
    asked = answer_matches(pg, none)
    pg.wait_for_load_state('networkidle'); pg.wait_for_timeout(1000)
    return asked


def answer_all(rid):
    db(f"""update xxcmp_request_answers x set answer_option_id = (select max(o.answer_option_id) keep (dense_rank last order by o.risk_points)
            from xxcmp_answer_options o where o.question_id = x.question_id and o.approval_status = 'APPROVED') where x.request_id = {rid};
          commit""")


def to_review_and_submit(pg, rid):
    click_nav(pg, 'Next')                       # party details -> questionnaire
    answer_all(rid); pg.reload(); pg.wait_for_load_state('networkidle')
    click_nav(pg, 'Next')                       # questionnaire -> review


def req(name):
    return db(f"select request_id || ',' || request_number || ',' || party_id from xxcmp_requests where party_name = '{name}'")[0].split(',')


def open_task(pg, s, number):
    pg.goto(f'{HOST}/ords/f?p={APP}:40:{s}'); pg.wait_for_load_state('networkidle')
    if pg.locator(f'a:has-text("{number}")').count() == 0:      # a busy list: search for the request
        search = pg.locator('input[type=search]').first
        search.click()
        for _ in range(6):
            pg.keyboard.press('Backspace')
        search.fill(number); pg.keyboard.press('Enter'); pg.wait_for_timeout(2500)
    with pg.expect_navigation():
        pg.locator(f'a:has-text("{number}")').first.click()
    pg.wait_for_load_state('networkidle')


def wait_task(rid):
    for _ in range(45):
        t = db(f"select max(task_id) from apex_tasks where detail_pk = '{rid}' and task_def_static_id = 'DOC_CHECKLIST_REVIEW' and state_code in ('ASSIGNED','UNASSIGNED')")
        if t and t[0]:
            return t[0]
        time.sleep(2)


with sync_playwright() as p:
    b = p.chromium.launch(executable_path=os.environ.get('CHROME', '/opt/pw-browsers/chromium-1194/chrome-linux/chrome'),
                          args=['--no-sandbox'])
    # ------------------------------------------------------------ requester: the wizard
    pg, s = login(b, 'REQ1')
    pg.goto(f'{HOST}/ords/f?p={APP}:201:{s}'); pg.wait_for_load_state('networkidle')
    ok('step 1: the wizard has 4 steps, the common party form, no match switch',
       pg.locator('#wizard li').count() == 4 and pg.locator('#party-form').is_visible()
       and pg.locator('#P0_PARTY_MATCH_ACK_CONTAINER .a-Switch').count() == 0)
    name = f'UI Org {TAG}'
    step1(pg, s, name, f'UI-{TAG}')
    rid, rno, pid = req(name)
    ok('Next saved the request, created its Pending party and opened Party Details',
       db(f"select party_status from xxcmp_parties where party_id = {pid}") == ['PENDING']
       and pg.locator('button:has-text("Add Contact Person")').count() == 1)
    pg.click('button:has-text("Add Contact Person")')
    f = pg.frame_locator('iframe').first
    f.locator('#P22_CONTACT_NAME').wait_for()
    f.locator('#P22_CONTACT_NAME').fill('Rana Requester'); f.locator('#P22_EMAIL').fill('rana@ui.example')
    f.locator('button:has-text("Create")').click()
    pg.locator('.ui-dialog iframe').wait_for(state='detached', timeout=30000); pg.wait_for_timeout(1000)
    ok('the requester adds a contact person to the party their request created', 'Rana Requester' in pg.inner_text('#party_contacts'))
    to_review_and_submit(pg, rid)
    card = pg.inner_text('#party_card')
    ok('review: the party in full (no Show details, no Party Status), its details, answers, documents, expected path',
       name in card and 'Show details' not in card and 'Party Status' not in card
       and 'Rana Requester' in pg.inner_text('#party_contacts') and pg.locator('#answer_summary').count() == 1
       and pg.locator('#request_attachments').count() == 1 and 'Expected' in pg.inner_text('#approval_history'))
    ok('review: the party number is not a link (everything is on the screen)', pg.locator('#party_card a').count() == 0)
    click_nav(pg, 'Submit Request')
    task = wait_task(rid)
    ok(f'Submit starts the workflow: task {task}', task is not None)
    ok('request view: read only, Back only (no Cancel / Add Document / Edit Party)',
       pg.locator('button:has-text("Back")').count() >= 1
       and all(pg.locator(f'button:has-text("{x}")').count() == 0 for x in ('Cancel Request', 'Add Document', 'Edit Party', 'Approve')))
    pg.reload(); pg.wait_for_load_state('networkidle')
    hist = pg.inner_text('#approval_history')
    ok('approval history in time order: Submitted, then the current step Pending',
       'Submitted' in hist and 'Pending' in hist and hist.index('Submitted') < hist.index('Pending'))
    ok('the request shows its business relationship', 'Vendor' in pg.inner_text('#request'))
    pg.goto(f'{HOST}/ords/f?p={APP}:200:{s}'); pg.wait_for_load_state('networkidle')
    nums = [t.strip() for t in pg.locator('.a-IRR-table tr td:first-child').all_inner_texts()][:5]
    ok(f'list sorted by request number, newest first: {nums}', len(nums) > 1 and nums == sorted(nums, reverse=True))
    ok('list: Withdraw for the request waiting for approval',
       pg.locator(f'.a-IRR-table tr:has-text("{rno}") a.kyc-row-action[data-action="Withdraw"]').count() == 1)
    pg.close()

    # ------------------------------------------------------------ approver: Request Information (comment required)
    pg, s = login(b, 'OFFICER1')
    open_task(pg, s, rno)
    ok('approval screen: Approve / Reject / Request Information at the top and the bottom; no Cancel / Add Document',
       all(pg.locator('button', has_text=re.compile(r'^\s*%s\s*$' % x)).count() == 2 for x in ('Approve', 'Reject Request', 'Request Information'))
       and pg.locator('button:has-text("Cancel Request")').count() == 0 and pg.locator('button:has-text("Add Document")').count() == 0)
    bar = pg.inner_text('#decision_buttons')
    ok('bottom bar: Reject, Request Information and Approve in one row',
       all(x in bar for x in ('Reject Request', 'Request Information', 'Approve')))
    pg.locator('button', has_text=re.compile(r'^\s*Request Information\s*$')).first.click(); pg.wait_for_timeout(2000)
    ok('Request Information needs a comment', 'Enter the information you need' in pg.inner_text('body'))
    pg.fill('#P206_COMMENT', 'Please upload the trade licence.')
    click_nav(pg, 'Request Information')
    ok('Request Information: the request is Information Needed',
       db(f"select request_status from xxcmp_requests where request_id = {rid}") == ['INFO_NEEDED'])
    pg.close()

    # ------------------------------------------------------------ requester answers on the review step
    pg, s = login(b, 'REQ1')
    pg.goto(f'{HOST}/ords/f?p={APP}:200:{s}'); pg.wait_for_load_state('networkidle')
    with pg.expect_navigation():
        pg.locator(f'.a-IRR-table tr:has-text("{rno}") a.kyc-row-action[data-action="Edit"]').click()
    pg.wait_for_load_state('networkidle')
    click_nav(pg, 'Next'); click_nav(pg, 'Next'); click_nav(pg, 'Next')
    ok('review step shows the question', 'Please upload the trade licence.' in pg.inner_text('#respond'))
    pg.fill('#P203_RESPONSE', 'Uploaded now.')
    click_nav(pg, 'Respond')
    ok('Respond: back In Progress', db(f"select request_status from xxcmp_requests where request_id = {rid}") == ['IN_PROGRESS'])
    pg.close()

    # ------------------------------------------------------------ approver approves
    pg, s = login(b, 'OFFICER1')
    wait_task(rid)
    open_task(pg, s, rno)
    click_nav(pg, 'Approve')
    final = None
    for _ in range(30):
        final = db(f"""select r.request_status || ',' || p.party_status || ',' || (select count(*) from xxcmp_cases c where c.request_id = r.request_id)
                         from xxcmp_requests r join xxcmp_parties p on p.party_id = r.party_id where r.request_id = {rid}""")
        if final and final[0].endswith(',1'):
            break
        time.sleep(2)
    ok(f'Approve: request and party Approved, case opened ({final})', final == ['APPROVED,APPROVED,1'])
    existing = db(f"select party_number || ',' || party_name from xxcmp_parties where party_id = {pid}")[0].split(',', 1)
    pg.close()

    # ------------------------------------------------------------ similar party: "a possible match exists", then merge in a popup
    pg, s = login(b, 'REQ2')
    dup = existing[1].replace('UI Org', 'UI Orgg')
    asked = step1(pg, s, dup, f'UI2-{TAG}', none=False)
    did, dno, dpid = req(dup)
    ok('similar parties: the dialog asked; "A possible match exists" is saved (MATCH_ACK_FLAG = N)',
       asked and db(f"select match_ack_flag from xxcmp_requests where request_id = {did}") == ['N'])
    to_review_and_submit(pg, did)
    click_nav(pg, 'Submit Request')
    wait_task(did)
    pg.close()
    pg, s = login(b, 'OFFICER1')
    open_task(pg, s, dno)
    link = pg.locator(f'#match_candidates tr:has-text("{existing[0]}") a.kyc-merge-party')
    ok('the approver sees the approved party as a possible duplicate; no Merge Note box on the page',
       link.count() == 1 and not pg.locator('#P206_MATCH_NOTE').is_visible())
    link.click(); pg.wait_for_timeout(800)
    ok('Merge opens a popup with the note', pg.locator('#P206_MATCH_NOTE').is_visible())
    pg.fill('#P206_MATCH_NOTE', 'Same company, typo in the name.')
    with pg.expect_navigation():
        pg.locator('#merge_dialog').locator('xpath=ancestor::div[contains(@class,"ui-dialog")]').locator('button:has-text("Merge")').first.click()
    pg.wait_for_load_state('networkidle')
    r = db(f"""select r.party_id || ',' || d.enabled_flag || ',' || r.match_status
                 from xxcmp_requests r, xxcmp_parties d where r.request_id = {did} and d.party_id = {dpid}""")
    ok(f'merged: the request uses the existing party, the duplicate is disabled ({r})', r == [f'{pid},N,MERGED'])
    pg.close()

    # ------------------------------------------------------------ withdraw, then cancel on the edit screen
    pg, s = login(b, 'REQ1')
    cname = f'Withdraw Org {TAG}'
    step1(pg, s, cname, f'WD-{TAG}')
    wid, wno, wpid = req(cname)
    to_review_and_submit(pg, wid)
    click_nav(pg, 'Submit Request')
    wait_task(wid)
    pg.goto(f'{HOST}/ords/f?p={APP}:200:{s}'); pg.wait_for_load_state('networkidle')
    pg.locator(f'.a-IRR-table tr:has-text("{wno}") a.kyc-row-action[data-action="Withdraw"]').click()
    pg.locator('.ui-dialog .js-confirmBtn, .ui-dialog button:has-text("OK")').first.click()
    pg.wait_for_timeout(3000)
    ok('Withdraw: back to Draft', db(f"select request_status from xxcmp_requests where request_id = {wid}") == ['DRAFT'])
    pg.reload(); pg.wait_for_load_state('networkidle')
    with pg.expect_navigation():
        pg.locator(f'.a-IRR-table tr:has-text("{wno}") a.kyc-row-action[data-action="Edit"]').click()
    pg.wait_for_load_state('networkidle')
    pg.click('button:has-text("Cancel Request")')
    with pg.expect_navigation():
        pg.locator('.ui-dialog .js-confirmBtn, .ui-dialog button:has-text("OK")').first.click()
    pg.wait_for_load_state('networkidle')
    r = db(f"""select r.request_status || ',' || p.party_status from xxcmp_requests r join xxcmp_parties p on p.party_id = r.party_id
                where r.request_id = {wid}""")
    ok(f'Cancel Request on the edit screen: request and its Pending party Cancelled ({r})', r == ['CANCELLED,CANCELLED'])
    b.close()
print(f'{sum(results)}/{len(results)} passed')
sys.exit(0 if all(results) else 1)
