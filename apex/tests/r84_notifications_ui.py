# COMMON release 84 (workflow processes and notifications): the bell in the navigation bar opens Notifications (43)
# with the push switch of the device and Mark All as Read; Notification Delivery (116) shows the channels, events,
# rules and who can be told; the Notification Log (117) opens; an RFI task opens its page (143) with the questions
# and answers; Communications (45) opens for a record from a plain URL (any application) and E-mail (46) records a
# received e-mail; the public page Provide Information (50) opens without signing in and refuses an unknown link.
# Usage: python3 r84_notifications_ui.py   (after r84_notifications_test.sql, which leaves RFI tasks)
import re
from playwright.sync_api import sync_playwright
ROOT = 'http://localhost:8080/ords'
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
    # the page by its alias in the same session (no checksum of another page carried over)
    m = re.search(r'session=(\d+)|f\?p=\d+:\d+:(\d+)', pg.url)
    session = m.group(1) or m.group(2)
    url = f'{ROOT}/r/xxcus/common/{alias}?' + (query + '&' if query else '') + f'session={session}'
    try:
        pg.goto(url)
    except Exception:
        # the PWA service worker of the previous page may interrupt the first navigation: once more
        pg.wait_for_timeout(1500)
        pg.goto(url)
    pg.wait_for_load_state('networkidle')


with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args=['--no-sandbox'])
    pg = b.new_page(viewport={'width': 1400, 'height': 1000})
    js_errors = []
    pg.on('pageerror', lambda e: js_errors.append(str(e)[:200]))

    # the public page first: no sign-in, an unknown link is refused
    pg.goto(f'{ROOT}/r/xxcus/common/provide-information?p50_token=not-a-valid-token'); pg.wait_for_load_state('networkidle')
    check(pg.locator('#P50_QUESTION, #P50_QUESTION_DISPLAY').count() > 0 and 'not valid' in pg.inner_text('body'),
          'Provide Information opens without signing in and says an unknown link is not valid')

    pg.goto(f'{ROOT}/r/xxcus/common/login')
    pg.fill('#P9999_USERNAME', 'ADMIN'); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')

    # the bell
    bell = pg.locator('.t-NavigationBar a', has=pg.locator('.fa-bell-o')).or_(pg.locator('.t-NavigationBar a', has_text='Notifications'))
    check(bell.count() > 0, 'the bell is in the navigation bar')
    bell.first.click(); pg.wait_for_load_state('networkidle')
    no_error(pg, 'Notifications')
    check(pg.locator('#device').count() == 1 and pg.locator('button', has_text='Turn On for This Device').count() == 1,
          'push notifications can be turned on for this device')
    check(pg.locator('#notifications').count() == 1, 'the notification list is shown')
    with pg.expect_navigation():
        pg.locator('button', has_text='Mark All as Read').click()
    pg.wait_for_load_state('networkidle')
    check(pg.locator('#notifications td', has_text=re.compile(r'^New$')).count() == 0, 'Mark All as Read')

    # setup and log
    go(pg, 'notification-delivery')
    no_error(pg, 'Notification Delivery')
    for r, words in (('#channels', ('IN_APP', 'EMAIL', 'PUSH', 'FUSION')), ('#events', ('TASK_ASSIGNED', 'RFI_RAISED')),
                     ('#rules', ('Notifications', )), ('#recipients', ('TASK_OWNERS', 'RFI_OUTSIDE_PERSON'))):
        txt = pg.inner_text(r) if pg.locator(r).count() else ''
        check(all(w in txt for w in words) if r != '#rules' else pg.locator(r).count() == 1, f'{r[1:]} are shown')
    go(pg, 'notification-log')
    no_error(pg, 'Notification Log')
    check('TASK_ASSIGNED' in pg.inner_text('#log') or 'A task is assigned' in pg.inner_text('#log'), 'the log lists notifications')

    # an RFI task opens its page
    go(pg, 'my-tasks')
    link = pg.locator('#tasks .a-IRR-table td a', has_text=re.compile('Information requested|Answer received'))
    if link.count():
        link.first.click(); pg.wait_for_load_state('networkidle')
        no_error(pg, 'Information Request')
        check(pg.locator('#rounds').count() == 1 and 'QUESTION' in pg.inner_text('#rounds'),
              'the task page lists the questions and answers')
        check(pg.locator('#answer').count() + pg.locator('#review').count() == 1, 'it offers the answer or the review')
        if pg.locator('#P143_RESPONSE').count():
            pg.fill('#P143_RESPONSE', 'Answered in the R84 browser test.')
            with pg.expect_navigation():
                pg.locator('button', has_text='Submit Answer').click()
            pg.wait_for_load_state('networkidle')
            check('my-tasks' in pg.url.lower() or ':40:' in pg.url or 'My Tasks' in pg.title(),
                  f'the answer is sent and My Tasks opens again ({pg.url[-60:]} {pg.title()})')
            no_error(pg, 'My Tasks after the answer')
    else:
        print('INFO no open RFI task: run r84_notifications_test.sql first')

    # communications of a record, from a plain URL (as any application opens it)
    go(pg, 'communications', 'p45_application_code=COMMON&p45_entity_name=R84_TEST&p45_pk1_value=UI')
    no_error(pg, 'Communications')
    pg.locator('button', has_text='Record Received E-mail').click(); pg.wait_for_load_state('networkidle')
    no_error(pg, 'E-mail')
    pg.fill('#P46_FROM', 'someone.r84@example.com'); pg.fill('#P46_SUBJECT', 'R84 received')
    pg.fill('#P46_BODY', 'An e-mail received by the R84 browser test.')
    pg.locator('button', has_text='Save').click(); pg.wait_for_load_state('networkidle')
    check('R84 received' in pg.inner_text('#history'), 'the received e-mail is kept with the record')

    check(not js_errors, f'no JavaScript errors {js_errors[:2]}')
    b.close()
print('FAILED' if fails else 'ALL PASSED')
