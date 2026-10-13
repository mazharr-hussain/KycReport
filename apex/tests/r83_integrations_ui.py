# COMMON release 83 (C6 Integrations): Servers (120) lists the APEX Remote Servers with owner and health, the
# "How to change a server" note and the read-only registered endpoints; a Server (121) opens and Test Connection
# answers; a Purpose (123) chooses a REST Data Source; the Transmission Log (124) opens on APEX's web service log and a
# call made through the COMMON call procedure opens its detail (125).
# Usage: python3 r83_integrations_ui.py
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
    pg.on('pageerror', lambda e: js_errors.append(str(e)[:200]))
    pg.goto(f'{ROOT}/r/xxcus/common/login')
    pg.fill('#P9999_USERNAME', 'ADMIN'); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')

    # Servers (120)
    go(pg, 'servers')
    no_error(pg, 'Servers')
    body = pg.inner_text('#servers')
    check(all(s in body for s in ('FUSION', 'UCM_MAIN', 'SHAREPOINT_MAIN', 'OUTLOOK_GRAPH')), 'the four Remote Servers are listed')
    check('Workspace administrator' in body, 'the owner is named')
    check(pg.locator('#howto').count() == 1 and 'Workspace Utilities' in pg.inner_text('#howto'), 'How to change a server')
    check(pg.locator('#endpoints').count() == 1, 'registered endpoints shown read-only')
    check(pg.locator('.t-Tabs-link', has_text='Servers').count() > 0 or 'Servers' in pg.inner_text('body'), 'tab reads Servers')

    # Server (121): Test Connection
    pg.locator('#servers .a-IRR-table td a', has_text='Oracle Fusion Cloud').first.click()
    fr = dialog(pg, 'server?', '#P121_SERVER_NAME, #P121_SERVER_NAME_DISPLAY')
    check(fr is not None, 'Server dialog opens')
    if fr:
        no_error(fr, 'Server')
        fr.locator('button', has_text='Test Connection').click(); pg.wait_for_timeout(8000)
        fr = dialog(pg, 'server?', '#P121_SERVER_NAME, #P121_SERVER_NAME_DISPLAY')
        txt = fr.inner_text('body') if fr else ''
        check('Reachable' in txt or 'Not reachable' in txt, 'Test Connection answers (reachable or why not)')
        pg.keyboard.press('Escape'); pg.wait_for_timeout(800)
    go(pg, 'servers')
    check('REACHABLE' in pg.inner_text('#servers') or 'FAILED' in pg.inner_text('#servers'), 'Last Test shows in the list')

    # Purpose (123): REST Data Source
    go(pg, 'integration-purposes')
    no_error(pg, 'Purposes')
    pg.locator('#report .a-IRR-table td a', has_text='HCM_SYNC').or_(pg.locator('.a-IRR-table td a', has_text='HCM_SYNC')).first.click()
    fr = dialog(pg, 'integration-purpose?', '#P123_REST_SOURCE_STATIC_ID')
    check(fr is not None, 'Purpose opens with its REST Data Source')
    if fr:
        no_error(fr, 'Purpose HCM_SYNC')
        check(fr.locator('#P123_REST_SOURCE_STATIC_ID').input_value() == 'FUSION_HCM_WORKERS', 'HCM_SYNC uses FUSION_HCM_WORKERS')
        pg.keyboard.press('Escape'); pg.wait_for_timeout(800)

    # Transmission Log (124) and a call (125)
    go(pg, 'transmission-log')
    no_error(pg, 'Transmission Log')
    links = pg.locator('#log .a-IRR-table td a')
    if links.count():
        links.first.click()
        fr = dialog(pg, 'call?', '#P125_PURPOSE, #P125_PURPOSE_DISPLAY')
        check(fr is not None, 'a call opens its detail')
        if fr:
            no_error(fr, 'Call')
        pg.keyboard.press('Escape'); pg.wait_for_timeout(800)
    else:
        print('INFO no call made through the COMMON call procedure yet')

    check(not js_errors, f'no JavaScript errors {js_errors[:2]}')
    b.close()
print('FAILED' if fails else 'ALL PASSED')
