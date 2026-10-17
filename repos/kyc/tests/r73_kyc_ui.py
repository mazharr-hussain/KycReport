"""Release 73 in the browser (KYC): Request Information offered when the approver is the requester (206); a screening
added in the dialog appears in the case list at once (211, I15); a case opened from the Cases list opens again from
the breadcrumb (211 without items, I16). Uses open data (an open approval / investigation task); screenings it adds
are deleted. Usage: r73_kyc_ui.py   (SQLCL env var: the SQLcl command; connection name kyc_local)"""
import os, re, subprocess
from playwright.sync_api import sync_playwright
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
    pg = b.new_page()
    pg.goto(f'{HOST}/ords/r/xxcus/kyc/login')
    pg.fill('#P9999_USERNAME', user); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
    return pg, re.search(r'session=(\d+)', pg.url).group(1)


def goto(pg, s, page):
    pg.goto(f'{HOST}/ords/f?p=134:{page}:{s}'); pg.wait_for_load_state('networkidle')


def open_href(pg, s, page, pattern, search=None):
    """Open the record link of a list page (checksummed URL) whose href matches pattern."""
    goto(pg, s, page)
    if search:
        pg.fill('input[type=search]', search); pg.keyboard.press('Enter'); pg.wait_for_timeout(3000)
    href = pg.evaluate("p => [...document.querySelectorAll('a[href]')].map(a => a.href).filter(h => new RegExp(p, 'i').test(h))[0]",
                       pattern)
    if href:
        pg.goto(href); pg.wait_for_load_state('networkidle')
    return href


def error(pg):
    m = re.search(r'ORA-\d{5}.{0,100}', pg.inner_text('body'))
    return m.group(0) if m else None


with sync_playwright() as p:
    b = p.chromium.launch(executable_path=os.environ.get('CHROME', '/opt/pw-browsers/chromium-1194/chrome-linux/chrome'),
                          args=['--no-sandbox'])
    # I12: the approver is the requester
    r = db("""select max(t.task_id) || ',' || max(t.initiator) keep (dense_rank last order by t.task_id)
                from apex_tasks t
               where t.task_def_static_id = 'DOC_CHECKLIST_REVIEW' and t.state_code in ('UNASSIGNED', 'ASSIGNED')
                 and exists (select 1 from apex_task_participants p where p.task_id = t.task_id
                                and p.participant_type = 'POTENTIAL_OWNER' and upper(p.participant) = upper(t.initiator))""")
    if not r or r[0] == ',':
        print('SKIP no open approval task whose approver is the requester')
    else:
        task, user = r[0].split(',')
        pg, s = login(b, user)
        goto(pg, s, 40)
        subject = db(f"select subject from apex_tasks where task_id = {task}")
        if subject:
            pg.locator('input[type=search]').first.fill(subject[0].split(' - ')[0]); pg.keyboard.press('Enter')
            pg.wait_for_load_state('networkidle'); pg.wait_for_timeout(2500)
        href = pg.evaluate("t => [...document.querySelectorAll('a[href]')].map(a => a.href).filter(h => h.toLowerCase().includes('p206_task_id=' + t) || h.toLowerCase().includes('p206_task_id%3d' + t))[0]", task)
        if href:
            pg.goto(href); pg.wait_for_load_state('networkidle')
            ok('Request Information offered to the approver who is the requester',
               pg.locator('#decision_buttons button:has-text("Request Information")').count() == 1)
        else:
            print('SKIP the task is not on the first page of My Tasks')
        pg.close()
    # I15 / I16: an open investigation
    r = db("""select max(c.case_id || ',' || c.case_number || ',' || c.assigned_to) keep (dense_rank last order by c.case_id)
                from xxcmp_cases c where c.case_status = 'INVESTIGATION' and c.assigned_to is not null""")
    if not r or r[0].count(',') < 2:
        print('SKIP no case under investigation')
    else:
        case, num, user = r[0].split(',')
        pg, s = login(b, user)
        ok(f'case {num} opens from the Cases list', open_href(pg, s, 210, rf'p211_case_id=\b{case}\b', num) is not None and not error(pg))
        goto(pg, s, 211)
        ok(f'the case opens again without items (breadcrumb) ({error(pg) or "no error"})', not error(pg) and num in pg.inner_text('body'))
        with pg.expect_navigation():
            pg.locator('#case_sections a', has_text='Screening').first.click()
        pg.wait_for_load_state('networkidle')
        before = pg.locator('#screenings tbody tr').count()
        pg.click('button:has-text("Add Screening")')
        frame = pg.frame_locator('iframe').first
        frame.locator('#P213_SCREENING_TYPE').wait_for()
        frame.locator('#P213_SCREENING_TYPE').select_option('SANCTIONS')
        frame.locator('#P213_MATCH_STATUS').select_option('NO_MATCH')
        frame.locator('#P213_RESULT_NOTES').fill('r73 ui test')
        frame.locator('button:has-text("Create")').click()
        pg.locator('.ui-dialog iframe').wait_for(state='detached', timeout=30000)
        pg.wait_for_timeout(3000)
        ok('the new screening is listed at once (no refresh)', 'r73 ui test' in pg.inner_text('#screenings'))
        db(f"delete from xxcmp_screenings where case_id = {case} and result_notes = 'r73 ui test';\ncommit")
        pg.close()
    b.close()
print('ALL PASSED' if all(results) else 'FAILED')
