"""KYC release 89 in the browser: information requests through COMMON.
The officer raises an RFI from the case's Notes and RFIs section (dialog on the case page, no KYC RFI page); the
colleague (REQ1) finds the step on the KYC home page and answers it on COMMON's task page Information Request (143);
the officer opens the review from the case's RFI row (COMMON 143) and resolves it.
Usage: kyc89_rfi_ui.py [app-id]   (SQLCL env var: the SQLcl command; connection name kyc_local, or KYC_CONNECT)"""
import os, random, re, string, subprocess, sys, time
from playwright.sync_api import sync_playwright

APP = sys.argv[1] if len(sys.argv) > 1 else '134'
HOST = os.environ.get('HOST', 'http://localhost:8080')
SQLCL = os.environ.get('SQLCL', 'sql')
CONNECT = os.environ.get('KYC_CONNECT')
TAG = ''.join(random.choice(string.ascii_uppercase) for _ in range(6))
results = []


def ok(label, cond):
    results.append(bool(cond))
    print(('PASS ' if cond else 'FAIL ') + label)


def db(sql):
    args = [SQLCL, '-S', CONNECT] if CONNECT else [SQLCL, '-S', '-name', 'kyc_local']
    out = subprocess.run(args, input=f'set heading off feedback off pages 0\n{sql};\nexit\n',
                         capture_output=True, text=True).stdout
    return [l.strip() for l in out.splitlines() if l.strip() and 'JAVA_TOOL' not in l]


def wait_db(sql, secs=120):
    for _ in range(secs // 3):
        r = db(sql)
        if r and r[0] not in ('', 'null'):
            return r[0]
        time.sleep(3)
    return None


def login(b, user):
    pg = b.new_page()
    pg.on('pageerror', lambda e: print('JS ERROR', str(e)[:200]))
    pg.goto(f'{HOST}/ords/r/xxcus/kyc/login')
    pg.fill('#P9999_USERNAME', user); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
    return pg, re.search(r'session=(\d+)', pg.url).group(1)


def open_notes(pg, s, cnum):
    pg.goto(f'{HOST}/ords/f?p={APP}:210:{s}'); pg.wait_for_load_state('networkidle')
    pg.fill('#report_search_field', cnum); pg.keyboard.press('Enter'); pg.wait_for_timeout(2500)
    with pg.expect_navigation():
        pg.locator('#report td a', has_text=cnum).first.click()
    pg.wait_for_load_state('networkidle')
    with pg.expect_navigation():
        pg.locator('#case_sections a', has_text='Notes').first.click()
    pg.wait_for_load_state('networkidle')


def errors(pg):
    return pg.locator('.t-Alert--danger, .a-Notification--error, #t_Alert_Notification').all_inner_texts()


row = db("""select case_number || '|' || case_id from (select c.case_number, c.case_id from xxcmp_cases c
             where c.case_status = 'INVESTIGATION' and upper(c.assigned_to) = 'OFFICER1' order by c.case_id desc) where rownum = 1""")
cnum, case_id = row[0].split('|')
question = f'R89 UI question {TAG}'

with sync_playwright() as p:
    b = p.chromium.launch(executable_path=os.environ.get('CHROME', '/opt/pw-browsers/chromium-1194/chrome-linux/chrome'),
                          args=['--no-sandbox'])
    # 1. the officer raises the RFI on the case page
    pg, s = login(b, 'OFFICER1')
    open_notes(pg, s, cnum)
    ok('Notes and RFIs offers Raise RFI', pg.locator('button:has-text("Raise RFI")').count() == 1)
    pg.click('button:has-text("Raise RFI")')
    pg.locator('#rfi_dialog').wait_for(state='visible', timeout=10000)
    ok('Raise RFI opens the dialog on the case page (no KYC RFI page)', pg.locator('#P211_RFI_DESCRIPTION').is_visible())
    ok('the colleague field shows only for A colleague I choose', not pg.locator('#P211_RFI_USER').is_visible())
    pg.locator('#P211_RFI_RECIPIENT_TYPE label', has_text='A colleague I choose').click()
    pg.wait_for_timeout(500)
    ok('choosing A colleague shows the colleague field', pg.locator('#P211_RFI_USER').is_visible())
    pg.evaluate("apex.item('P211_RFI_USER').setValue('REQ1', 'REQ1')")
    pg.locator('#P211_RFI_CATEGORY').select_option('CLARIFICATION')
    pg.fill('#P211_RFI_DESCRIPTION', question)
    with pg.expect_navigation():
        pg.locator('#rfi_dialog').locator('xpath=ancestor::div[contains(@class,"ui-dialog")]') \
          .locator('button:has-text("Send Request")').click()
    pg.wait_for_load_state('networkidle')
    ok(f'sent without error ({errors(pg) or "no error"})', not errors(pg))
    rfi = db(f"select max(rfi_id) from xxfnd_rfis where description = '{question}'")
    rfi = rfi[0] if rfi else None
    ok(f'the RFI is raised for the case ({rfi})', rfi and rfi != '')
    ok('it is listed in Notes and RFIs', f'RFI ' in pg.inner_text('#notes') and question in pg.inner_text('#notes'))
    task = wait_db(f"select max(task_id) from apex_tasks where task_def_static_id = 'RFI_RESPONSE' and detail_pk = '{rfi}' "
                   f"and state_code in ('UNASSIGNED', 'ASSIGNED')")
    ok(f'COMMON\'s workflow asks REQ1 (task {task})', task is not None)

    # 2. REQ1 answers on COMMON's task page from the KYC home page
    pg2, s2 = login(b, 'REQ1')
    pg2.goto(f'{HOST}/ords/f?p={APP}:1:{s2}'); pg2.wait_for_load_state('networkidle')
    link = pg2.locator('#my-tasks a', has_text=re.compile(r'RFI-'))
    found = None
    for i in range(link.count()):
        if f'P143_TASK_ID={task}'.lower() in (link.nth(i).get_attribute('href') or '').lower() \
           or f'p143_task_id={task}' in (link.nth(i).get_attribute('href') or '').lower():
            found = link.nth(i)
    ok('the KYC home page lists the RFI step with a link to COMMON page 143', found is not None)
    if found is not None:
        with pg2.expect_navigation():
            found.click()
        pg2.wait_for_load_state('networkidle')
        ok(f'COMMON\'s Information Request opens in the same session ({pg2.url.split("?")[0][-40:]})',
           '/common/' in pg2.url.lower() and question in pg2.inner_text('body'))
        pg2.fill('#P143_RESPONSE', f'R89 UI answer {TAG}')
        with pg2.expect_navigation():
            pg2.locator('button', has_text='Submit Answer').click()
        pg2.wait_for_load_state('networkidle')
        st = db(f"select rfi_status from xxfnd_rfis where rfi_id = {rfi}")
        ok(f'the answer is kept ({st})', st == ['RESPONDED'])

    # 3. the officer reviews it from the case's RFI row
    review = wait_db(f"select max(task_id) from apex_tasks where task_def_static_id = 'RFI_REVIEW' and detail_pk = '{rfi}' "
                     f"and state_code in ('UNASSIGNED', 'ASSIGNED')")
    ok(f'the workflow has it reviewed (task {review})', review is not None)
    open_notes(pg, s, cnum)
    row_link = pg.locator('#notes a', has_text=re.compile(r'RFI '))
    href = [row_link.nth(i).get_attribute('href') for i in range(row_link.count())]
    target = [h for h in href if h and str(review) in h]
    ok('the case\'s RFI row links to COMMON page 143 for the review', len(target) == 1)
    if target:
        with pg.expect_navigation():
            pg.locator(f'#notes a[href="{target[0]}"]').click()
        pg.wait_for_load_state('networkidle')
        ok('the review opens (COMMON page 143)', pg.locator('#P143_NOTES').count() == 1)
        pg.fill('#P143_NOTES', 'R89 UI resolved')
        with pg.expect_navigation():
            pg.locator('button', has_text='Resolve').click()
        pg.wait_for_load_state('networkidle')
        st = db(f"select rfi_status from xxfnd_rfis where rfi_id = {rfi}")
        ok(f'resolved ({st})', st == ['RESOLVED'])
    b.close()
print(f'{sum(results)}/{len(results)} passed')
sys.exit(0 if all(results) else 1)
