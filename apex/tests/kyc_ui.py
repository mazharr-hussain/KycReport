"""Chunk 5 in the browser: REQ1 creates a request with the wizard (201-203) and submits it; OFFICER1 approves the
document checklist on the request (205), which opens the case; OFFICER1 sets the risk on the Case page (211) and
submits it for approval; MGR1 approves in the Case Decision drawer (212). The case must end APPROVED.
Usage: kyc_ui.py [app-id]   (SQLCL env var: the SQLcl command, default 'sql'; connection name kyc_local)"""
import os, random, re, string, subprocess, sys, time
from playwright.sync_api import sync_playwright

APP = sys.argv[1] if len(sys.argv) > 1 else '101'
HOST = 'http://localhost:8080'
SQLCL = os.environ.get('SQLCL', 'sql')
# random name: resembles no earlier test party (else Compliance first decides the counterparty match)
NAME = 'UIT ' + ''.join(random.choice(string.ascii_uppercase) for _ in range(10))
results = []
CURRENT = []   # the page in use, for a screenshot when a step fails


def on_failure(kind, value, tb):
    if CURRENT:
        try:
            CURRENT[-1].screenshot(path='kyc_ui_failure.png', full_page=True)
        except Exception:
            pass
    sys.__excepthook__(kind, value, tb)


sys.excepthook = on_failure


def ok(label, cond):
    results.append(cond)
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


def login(b, user):
    pg = b.new_page()
    CURRENT.append(pg)
    pg.on('pageerror', lambda e: print('JS ERROR', user, pg.url[-60:], str(e)[:200]))
    pg.goto(f'{HOST}/ords/r/xxcus/kyc/login')
    pg.fill('#P9999_USERNAME', user); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
    return pg, re.search(r'session=(\d+)', pg.url).group(1)


def goto(pg, s, page):
    pg.goto(f'{HOST}/ords/f?p={APP}:{page}:{s}'); pg.wait_for_load_state('networkidle')


def errors(pg):
    txt = pg.inner_text('body')
    m = re.search(r'ORA-\d{5}.{0,120}|Contact your application administrator.{0,80}|error has occurred.{0,120}', txt)
    return m.group(0) if m else None


def click(pg, label, confirm=False):
    """Press a submit button (and OK its confirmation) and wait for the page that follows."""
    with pg.expect_navigation(timeout=60000):
        pg.click(f'button:has-text("{label}")')
        if confirm:
            btn = pg.locator('.ui-dialog .js-confirmBtn, .ui-dialog button:has-text("OK"), .ui-dialog button:has-text("Confirm")').first
            try:
                btn.click(timeout=10000)
            except Exception:
                pg.screenshot(path='kyc_ui_failure.png', full_page=True)
                raise
    pg.wait_for_load_state('networkidle')


def open_task(pg, s, page_item, task):
    """The task list links each task to its details page (task definition details page)."""
    # search by subject (on a busy list the task may be beyond the first page); a new task can take a
    # moment to be listed, so try a few times
    subject = db(f"select subject from apex_tasks where task_id = {task}")
    for attempt in range(4):
        goto(pg, s, 40)
        if subject:
            # the task list keeps earlier search terms (chips) in the session: remove them first
            search = pg.locator('input[type=search]').first
            search.click()
            for _ in range(6):
                pg.keyboard.press('Backspace')
            pg.wait_for_load_state('networkidle')
            pg.wait_for_timeout(1500)
            search.fill(subject[0].split(' - ')[0])
            pg.keyboard.press('Enter')
            pg.wait_for_load_state('networkidle')
            pg.wait_for_timeout(2500)
        link = pg.locator(f'a[href*="{page_item.lower()}={task}"], a[href*="{page_item.lower()}%3D{task}"]').first
        if link.count():
            return link
        pg.wait_for_timeout(3000)
    return link


with sync_playwright() as p:
    b = p.chromium.launch(executable_path=os.environ.get('CHROME', '/opt/pw-browsers/chromium-1194/chrome-linux/chrome'),
                          args=['--no-sandbox'])
    # ------------------------------------------------------------ REQ1: wizard
    pg, s = login(b, 'REQ1')
    goto(pg, s, 201)
    pg.evaluate('''(n) => {
        apex.item("P201_PARTY_NAME").setValue(n);
        apex.item("P201_REGISTRATION_NUMBER").setValue("REG-" + Date.now());
        apex.item("P201_ENTITY_TYPE").setValue("LLC");
        apex.item("P201_JURISDICTION").setValue("AE");
        apex.item("P201_REQUESTING_DEPARTMENT").setValue("PROCUREMENT");
        apex.item("P201_JUSTIFICATION").setValue("New supplier for the UI test");
        apex.item("P201_CONTACT_NAME").setValue("UI Contact");
        apex.item("P201_CONTACT_EMAIL").setValue("ui.contact@example.com");
        apex.item("P201_CONTACT_PHONE").setValue("+971 4 000 0000");
    }''', NAME)
    click(pg, 'Next')
    ok(f'step 1 saved the counterparty and moved to the questionnaire ({pg.title()})', 'Questionnaire' in pg.title() and not errors(pg))
    req = db(f"select request_id from xxcmp_requests where party_name = '{NAME}'")[0]
    answers = {'regulated stock exchange': 'No', 'country of incorporation': 'Medium-risk jurisdiction',
               'transaction volume': 'Above 10 million', 'politically exposed': 'No', 'cash-intensive': 'Yes'}
    opts = {}
    for frag, label in answers.items():
        opts[frag] = db(f"""select o.answer_option_id from xxcmp_answer_options o join xxcmp_questions q on q.question_id = o.question_id
                             where q.questionnaire_code = 'CORPORATE' and q.question_text like '%{frag}%' and o.answer_label = '{label}'""")[0]
    # the questionnaire form (page 202): click the answer under each question
    set_count = 0
    for frag, label in answers.items():
        fs = pg.locator('fieldset.kyc-q', has_text=frag)
        if fs.count():
            fs.first.locator('label.kyc-q-option', has_text=label).first.click()
            set_count += 1
    click(pg, 'Next')
    ok(f'step 2 saved {set_count} answers and moved to review ({pg.title()})', set_count == 5 and 'Submit' in pg.title() and not errors(pg))
    click(pg, 'Submit Request')
    ok(f'submitted; the request page shows stage "{pg.inner_text("#P205_STAGE_CONTAINER").split(chr(10))[-1]}"',
       'KYC Request' in pg.title() and not errors(pg))
    task = wait_db(f"select max(task_id) from apex_tasks where task_def_static_id = 'DOC_CHECKLIST_REVIEW' and detail_pk = '{req}'")
    ok(f'intake scored the request and created the checklist task {task}', task is not None)
    pg.close()

    # ------------------------------------------------ OFFICER1: checklist, case
    pg, s = login(b, 'OFFICER1')
    link = open_task(pg, s, 'P205_TASK_ID', task)
    ok('the checklist task is in My Tasks', link.count() == 1)
    with pg.expect_navigation():
        link.click()
    pg.wait_for_load_state('networkidle')
    ok('the task opens the request with the decision buttons', pg.locator('button:has-text("Approve - Open Case")').count() == 1)
    click(pg, 'Approve - Open Case')
    ok(f'checklist approved ({(errors(pg) or "no error")})', not errors(pg))
    case = wait_db(f"select max(case_id) from xxcmp_cases where request_id = {req}")
    itask = wait_db(f"select max(task_id) from apex_tasks where task_def_static_id = 'CASE_INVESTIGATION' and detail_pk = '{case}'")
    ok(f'the case {case} was opened with an investigation task {itask}', case is not None and itask is not None)
    link = open_task(pg, s, 'P211_TASK_ID', itask)
    with pg.expect_navigation():
        link.click()
    pg.wait_for_load_state('networkidle')
    ok('the investigation task opens the Case page', 'Case' in pg.title() and pg.locator('button:has-text("Submit for Approval")').count() == 1)
    pg.evaluate('apex.item("P211_RISK_TIER").setValue("MEDIUM")')
    click(pg, 'Save')
    ok(f'risk saved ({errors(pg) or "no error"})', not errors(pg) and db(f"select risk_tier from xxcmp_cases where case_id = {case}")[0] == 'MEDIUM')
    # submitting without a screening is refused inline
    pg.click('button:has-text("Submit for Approval")')
    pg.locator('.ui-dialog .js-confirmBtn, .ui-dialog button:has-text("OK")').first.click()
    pg.wait_for_selector('text=Record at least one screening', timeout=30000)
    ok('submitting without a screening is refused', db(f"select case_status from xxcmp_cases where case_id = {case}")[0] == 'INVESTIGATION')
    # record a sanctions screening in the Screening drawer
    pg.click('button:has-text("Add Screening")')
    frame = pg.frame_locator('iframe').first
    frame.locator('#P213_SCREENING_TYPE').wait_for()
    frame.locator('#P213_SCREENING_TYPE').select_option('SANCTIONS')
    frame.locator('#P213_MATCH_STATUS').select_option('NO_MATCH')
    frame.locator('button:has-text("Create")').click()
    pg.locator('.ui-dialog iframe').wait_for(state='detached', timeout=30000)
    ok('screening recorded in the drawer', db(f"select count(*) from xxcmp_screenings where case_id = {case}")[0] == '1')
    pg.reload()
    pg.wait_for_load_state('networkidle')
    click(pg, 'Submit for Approval', confirm=True)
    ok(f'submitted for approval ({errors(pg) or "no error"})', not errors(pg))
    atask = wait_db(f"select max(task_id) from apex_tasks where task_def_static_id = 'CASE_APPROVAL' and detail_pk = '{case}'")
    ok(f'approval task {atask} created', atask is not None)
    pg.close()

    # --------------------------------------------------------- MGR1: decision
    pg, s = login(b, 'MGR1')
    link = open_task(pg, s, 'P212_TASK_ID', atask)
    ok('the approval task is in the manager\'s task list', link.count() == 1)
    link.click()
    frame = pg.frame_locator('iframe').first
    frame.locator('#P212_COMMENT').wait_for()
    frame.locator('#P212_COMMENT').fill('Approved in the UI test.')
    frame.locator('button:has-text("Approve")').click()
    if frame.locator('.ui-dialog button:has-text("OK")').count():
        frame.locator('.ui-dialog button:has-text("OK")').click()
    pg.locator('.ui-dialog iframe').wait_for(state='detached', timeout=30000)
    pg.wait_for_load_state('networkidle')
    closed = wait_db(f"select count(*) from xxcmp_cases where case_id = {case} and case_status = 'APPROVED'")
    ok('level 1 approval (medium risk: one level) approves and closes the case', closed == '1')
    ok('request completed', db(f"select request_status from xxcmp_requests where request_id = {req}")[0] == 'COMPLETED')
    pg.close()
    b.close()
print(f'{sum(results)}/{len(results)} passed')
sys.exit(0 if all(results) else 1)
