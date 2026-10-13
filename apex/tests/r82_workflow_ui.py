# COMMON release 82 (C5 Workflow): Home shows the open task count; My Tasks (40) lists every application's tasks;
# the Workflow Monitor (141) opens, with the Workflow dialog (142) when a workflow exists; the Process Catalogue (147)
# shows the participants type and asks before a workflow is switched off (Cancel keeps it on); a Notification (110) is
# edited as plain text with its Arabic translation, a preview and "Send Test to Me"; Notifications (109) shows the
# XXFND_STANDARD layout; an Approval Rule (149) has "Test the Rules".
# Usage: python3 r82_workflow_ui.py
import re
from playwright.sync_api import sync_playwright
ROOT = 'http://localhost:8080/ords'
fails = 0


def check(ok, msg):
    global fails
    print(('PASS ' if ok else 'FAIL ') + msg)
    fails += 0 if ok else 1


def no_error(scope, what):
    body = scope.inner_text('body')
    bad = [w for w in ('ORA-', 'error occurred', 'do not have access', 'Page not available', 'went wrong') if w in body]
    check(not bad, f'{what} opens without error {bad or ""}')


def go(pg, alias):
    pg.goto(re.sub(r'/r/xxcus/common/[^?]*', f'/r/xxcus/common/{alias}', pg.url)); pg.wait_for_load_state('networkidle')


def dialog(pg, url_part, selector, wait=15000):
    for _ in range(30):
        frames = [f for f in pg.frames if url_part in (f.url or '').lower()]
        if frames:
            frames[-1].wait_for_selector(selector, timeout=wait)
            return frames[-1]
        pg.wait_for_timeout(500)
    return None


with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args=['--no-sandbox'])
    pg = b.new_page(viewport={'width': 1400, 'height': 1000})
    js_errors = []
    pg.on('pageerror', lambda e: (js_errors.append(str(e)[:200]), print('JSERR', pg.url[-60:], (e.stack or '')[:300])))
    pg.goto(f'{ROOT}/r/xxcus/common/login')
    pg.fill('#P9999_USERNAME', 'ADMIN'); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')

    # Home: the open task count, and My Tasks in the menu
    no_error(pg, 'Home')
    check(pg.locator('#my_tasks').count() == 1 and 'Open Tasks' in pg.locator('#my_tasks').inner_text(),
          'Home shows the open task count')
    check(pg.locator('#t_TreeNav').get_by_text('My Tasks', exact=True).count() > 0, 'My Tasks is in the menu')

    # My Tasks (40)
    go(pg, 'my-tasks')
    no_error(pg, 'My Tasks')
    check(pg.locator('#tasks').count() == 1, 'My Tasks lists the tasks of every application')

    # Workflow Monitor (141) and the Workflow dialog (142)
    go(pg, 'workflow-monitor')
    no_error(pg, 'Workflow Monitor')
    links = pg.locator('#workflows .a-IRR-table td a')
    if links.count():
        links.first.click()
        fr = dialog(pg, 'workflow?', '#P142_TITLE_DISPLAY, #P142_TITLE')
        check(fr is not None, 'Workflow dialog opens')
        if fr:
            no_error(fr, 'Workflow dialog')
            check(fr.locator('#task_action').count() == 1, 'Workflow dialog offers the task actions')
        pg.keyboard.press('Escape'); pg.wait_for_timeout(800)
    else:
        print('INFO no workflow in this database: the Workflow dialog is not opened')

    # Process Catalogue (147): participants, confirmation before switching a workflow off
    go(pg, 'process-catalogue')
    no_error(pg, 'Process Catalogue')
    grid = pg.locator('#processes')
    check('Participants' in grid.inner_text(), 'Process Catalogue shows the participants type')
    check(grid.get_by_text('Request for Information').count() > 0, 'the RFI process is in the catalogue')
    heads = pg.locator('#processes .a-GV-header th, #processes .a-GV-hdr th').all_inner_texts()
    idx = [i for i, h in enumerate(heads) if 'Approval Workflow' in h][0] - 1   # the row selector has no cell here
    cell = pg.locator('#processes .a-GV-bdy tbody tr, #processes .a-GV-table tbody tr').first.locator('td').nth(idx)
    check(cell.inner_text().strip() == 'On', 'the first process has its workflow on')
    cell.click(); pg.wait_for_timeout(700); cell.dblclick(); pg.wait_for_timeout(700)
    pg.keyboard.press('Space'); pg.wait_for_timeout(1500)
    asked = pg.locator('.ui-dialog:visible', has_text='Records of this process will be approved automatically').count() > 0
    check(asked, 'switching a workflow off asks for confirmation')
    if asked:
        pg.locator('.ui-dialog:visible button', has_text='Cancel').first.click(); pg.wait_for_timeout(800)
        pg.keyboard.press('Escape'); pg.wait_for_timeout(500)
        check(cell.inner_text().strip() in ('On', ''), 'Cancel keeps the workflow on')
    pg.goto(pg.url); pg.wait_for_load_state('networkidle')

    # Notifications (109) and a notification (110)
    go(pg, 'notification-templates')
    no_error(pg, 'Notifications')
    check('XXFND_STANDARD' in pg.inner_text('body') and pg.locator('#layout').count() == 1,
          'Notifications shows the XXFND_STANDARD layout and who uses it')
    link = pg.locator('#report .a-IRR-table td a', has_text=re.compile('TASK_ASSIGNED')).or_(pg.locator('#report .a-IRR-table td a')).first
    link.click()
    fr = dialog(pg, 'notification-template?', '#P110_MESSAGE_TEXT')
    check(fr is not None, 'Notification opens with a plain-text message')
    if fr:
        no_error(fr, 'Notification')
        check(fr.locator('#P110_BODY_HTML').count() == 0, 'no HTML editor any more')
        check(fr.locator('#translation').count() == 1, 'Arabic translation grid')
        check(len(fr.locator('#preview').inner_text()) > 20, 'preview shows the wording')
        fr.locator('#P110_PREVIEW_LANGUAGE').select_option('ar'); fr.wait_for_timeout(1500)
        no_error(fr, 'Preview in Arabic')
        fr.locator('button', has_text='Send Test to Me').click(); pg.wait_for_timeout(3000)
        fr2 = dialog(pg, 'notification-template?', '#P110_MESSAGE_TEXT')
        txt = fr2.inner_text('body') if fr2 else ''
        check(any(m in txt for m in ('The test e-mail was sent to you', 'You have no e-mail address',
                                     'The sender address (application setting MAIL_FROM) is not set')),
              'Send Test to Me answers (sent, or why not)')
        pg.keyboard.press('Escape'); pg.wait_for_timeout(800)

    # Approval Rule (149): test the rules
    go(pg, 'approval-setup')
    no_error(pg, 'Approval Setup')
    links = pg.locator('#report .a-IRR-table td a')
    if links.count():
        links.first.click()
        fr = dialog(pg, 'approval-rule', '#P149_TEST_ATTRIBUTES')
        check(fr is not None, 'Approval Rule has Test the Rules')
        if fr:
            fr.locator('#P149_TEST_ATTRIBUTES').fill('RISK_TIER=HIGH')
            fr.locator('button', has_text='Test').click(); fr.wait_for_timeout(2000)
            no_error(fr, 'Test the Rules')
        pg.keyboard.press('Escape'); pg.wait_for_timeout(800)
    else:
        print('INFO no approval rule in this database')

    check(not js_errors, f'no JavaScript errors {js_errors[:2]}')
    b.close()
print('FAILED' if fails else 'ALL PASSED')
