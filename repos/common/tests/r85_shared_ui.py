# COMMON release 85 (shared screens): Give Feedback (173) from the navigation bar on any page, Feedback (171) lists it
# and its Follow-up (172) adds an answer; Platform Activity (170) shows the slowest pages, top users, errors and page
# views; Attachments (47) of a record opened from a plain URL (as any application opens it) lists its documents for
# a record the user may see and says "not available" for one that does not exist.
# Usage: python3 r85_shared_ui.py   (after r85_shared_test.sql, which leaves the record "R85 document test")
import re
import subprocess
import time
from playwright.sync_api import sync_playwright
ROOT = 'http://localhost:8080/ords'
SQL = '/tmp/claude-0/-home-user-KycReport/5e8c20fd-6c82-5747-8066-a7d503f76bd3/scratchpad/sqlcl/bin/sql'
fails = 0


def check(ok, msg):
    global fails
    print(('PASS ' if ok else 'FAIL ') + msg)
    fails += 0 if ok else 1


def no_error(scope, what):
    body = scope.evaluate("""() => { const c = document.body.cloneNode(true);
        c.querySelectorAll('.display_only, .t-Report-cell, td').forEach(e => e.remove()); return c.innerText; }""")
    bad = [w for w in ('ORA-', 'error occurred', 'do not have access', 'Page not available', 'went wrong') if w in body]
    check(not bad, f'{what} opens without error {bad or ""}')


def go(pg, alias, query=''):
    m = re.search(r'session=(\d+)|f\?p=\d+:\d+:(\d+)', pg.url)
    session = m.group(1) or m.group(2)
    url = f'{ROOT}/r/xxcus/common/{alias}?' + (query + '&' if query else '') + f'session={session}'
    try:
        pg.goto(url)
    except Exception:
        pg.wait_for_timeout(1500)   # the PWA service worker may interrupt the first navigation
        pg.goto(url)
    pg.wait_for_load_state('networkidle')


def pdf(version):
    # a one-page PDF (the attachment rules accept PDF)
    text = f'R85 browser test file, version {version}'
    stream = f'BT /F1 12 Tf 72 720 Td ({text}) Tj ET'
    objs = ['<< /Type /Catalog /Pages 2 0 R >>', '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
            '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
            f'<< /Length {len(stream)} >>\nstream\n{stream}\nendstream',
            '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>']
    out, offs = '%PDF-1.4\n', []
    for i, o in enumerate(objs, 1):
        offs.append(len(out)); out += f'{i} 0 obj\n{o}\nendobj\n'
    xref = len(out)
    out += f'xref\n0 {len(objs) + 1}\n0000000000 65535 f \n' + ''.join(f'{o:010d} 00000 n \n' for o in offs)
    out += f'trailer\n<< /Size {len(objs) + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n'
    open('/tmp/r85_file.pdf', 'w').write(out)


def last_communication():
    out = subprocess.run([SQL, '-S', '/nolog'], input='connect xxfusion/"Xxfusion#Local1"@localhost:1521/FREEPDB1\n'
                         "set heading off feedback off pages 0\n"
                         "select max(communication_id) from xxfnd_communications where subject = 'R85 document test';\nexit\n",
                         capture_output=True, text=True).stdout
    m = re.search(r'^\s*(\d+)\s*$', out, re.M)
    return m.group(1) if m else None


with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args=['--no-sandbox'])
    pg = b.new_page(viewport={'width': 1400, 'height': 1000})
    js_errors = []
    pg.on('pageerror', lambda e: js_errors.append(str(e)[:200]))
    pg.goto(f'{ROOT}/r/xxcus/common/login')
    pg.fill('#P9999_USERNAME', 'ADMIN'); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')

    # Give Feedback from the navigation bar
    link = pg.locator('.t-NavigationBar a', has=pg.locator('.fa-comment-o'))
    check(link.count() > 0, 'Feedback is in the navigation bar')
    link.first.click(); pg.wait_for_load_state('networkidle')
    no_error(pg, 'Give Feedback')
    check('Common' in pg.inner_text('#give'), 'it says which application and page the feedback is about')
    pg.select_option('#P173_TYPE', '2'); pg.fill('#P173_FEEDBACK', 'R85 browser test: an idea for an improvement.')
    with pg.expect_navigation():
        pg.locator('button', has_text='Send Feedback').click()
    pg.wait_for_load_state('networkidle')
    check(pg.locator('#thanks').count() == 1, 'the feedback is sent (thank you)')

    # Feedback list and follow-up
    go(pg, 'feedback')
    no_error(pg, 'Feedback')
    fb = pg.locator('#feedback .a-IRR-table td a', has_text='R85 browser test')
    check(fb.count() > 0, 'the feedback is listed with its application')
    if fb.count():
        fb.first.click(); pg.wait_for_load_state('networkidle')
        no_error(pg, 'Feedback Follow-up')
        pg.fill('#P172_FOLLOW_UP', 'R85 browser test follow-up.')
        with pg.expect_navigation():
            pg.locator('button', has_text='Add Follow-up').click()
        pg.wait_for_load_state('networkidle')
        check('R85 browser test follow-up.' in pg.inner_text('#followups'), 'the follow-up is added')

    # Platform Activity
    go(pg, 'platform-activity')
    no_error(pg, 'Platform Activity')
    check(all(pg.locator(r).count() == 1 for r in ('#performance', '#top-users', '#errors', '#activity')),
          'slowest pages, top users, errors and page views are shown')
    check('ADMIN' in pg.inner_text('#top-users'), 'the signed-in user is among the top users')

    # Attachments of a record, from a plain URL
    comm = last_communication()
    base = 'p47_app_alias=COMMON&p47_source_page=45&p47_entity_name=XXFND_COMMUNICATIONS'
    if comm:
        # a page and region without an attachment registration: the documents are shown, nothing can be changed
        go(pg, 'attachments', f'{base}&p47_source_region=not-registered&p47_pk1_value={comm}')
        no_error(pg, 'Attachments')
        check(pg.locator('#documents').count() == 1 and 'R85 note' in pg.inner_text('#documents'),
              'the documents of the record are listed')
        check(pg.locator('button', has_text='Add Document').count() == 0,
              'no Add Document where the calling page has no attachment registration')
        # COMMON's Communications page (45, region history) is registered: add, then replace with a new version
        go(pg, 'attachments', f'{base}&p47_source_region=history&p47_pk1_value={comm}')
        pg.locator('button', has_text='Add Document').click(); pg.wait_for_load_state('networkidle')
        no_error(pg, 'Document')
        pdf(1)
        pg.select_option('#P48_CATEGORY_CODE', 'OTHER')
        pg.set_input_files('input[type=file]', '/tmp/r85_file.pdf')
        title = 'R85 uploaded file ' + str(int(time.time()))
        pg.fill('#P48_TITLE', title)
        with pg.expect_navigation():
            pg.locator('button', has_text='Save').click()
        pg.wait_for_load_state('networkidle')
        check(title in pg.inner_text('#documents'), 'a document is added and listed')
        row = pg.locator('#documents tr', has_text=title)
        row.locator('a', has_text='Replace').click(); pg.wait_for_load_state('networkidle')
        check(pg.locator('#P48_CURRENT_DISPLAY, #P48_CURRENT').count() > 0, 'Replace shows the current version')
        pdf(2)
        pg.set_input_files('input[type=file]', '/tmp/r85_file.pdf')
        with pg.expect_navigation():
            pg.locator('button', has_text='Save').click()
        pg.wait_for_load_state('networkidle')
        row = pg.locator('#documents tr', has_text=title)
        check(row.count() == 1 and re.search(r'\b2\b', row.inner_text()) is not None, 'the new version replaces it (version 2)')
        check(pg.locator('#documents td a', has_text='Remove').count() == 0, 'no Remove where the registration does not allow it')
        with pg.expect_download() as d:
            row.locator('a', has_text='Download').click()
        check(d.value.suggested_filename.endswith('.pdf'), 'the document downloads')
    else:
        print('INFO run r85_shared_test.sql first (record "R85 document test")')
    go(pg, 'attachments', f'{base}&p47_source_region=history&p47_pk1_value=-1')
    check(pg.locator('#not-allowed').count() == 1 and pg.locator('#documents').count() == 0,
          'a record that is not available shows nothing')

    check(not js_errors, f'no JavaScript errors {js_errors[:2]}')
    b.close()
print('FAILED' if fails else 'ALL PASSED')
