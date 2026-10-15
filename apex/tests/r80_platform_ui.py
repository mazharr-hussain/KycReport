# COMMON release 80 (C1 Platform, C3 Reference Data): the screens that now call the component packages open and save -
# Application (166 since release 86), Setup Type (163, save through XXFND_APPLICATION_PKG), Optional Features
# (10020/10021) and Application Settings (10022/10023), Lookup Type (102) and Descriptive Flexfield (153, save
# through XXFND_DFF_PKG); the level label reads "Workspace (all applications)".
# Usage: python3 r80_platform_ui.py
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


def open_dialog(pg, link_locator, url_part):
    link_locator.first.click(); pg.wait_for_timeout(3000)
    frames = [f for f in pg.frames if url_part in (f.url or '').lower()]
    return frames[-1] if frames else None


with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args=['--no-sandbox'])
    pg = b.new_page(viewport={'width': 1400, 'height': 1000})
    js_errors = []
    pg.on('pageerror', lambda e: js_errors.append(str(e)[:200]))
    pg.goto(f'{ROOT}/r/xxcus/common/login')
    pg.fill('#P9999_USERNAME', 'ADMIN'); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')

    # Application: since release 86 a row opens the application page (166; page 161 retired)
    go(pg, 'applications')
    no_error(pg, 'Applications')
    row = pg.locator('.a-IRR-table a', has_text='KYC')
    if row.count():
        with pg.expect_navigation():
            row.first.click()
        pg.wait_for_load_state('networkidle')
        no_error(pg, 'Application KYC')
        check('KYC' in pg.inner_text('body'), 'the application page shows the application')
    else:
        check(False, 'the KYC row is listed')

    # Setup Type (163): saved through the Applications package
    go(pg, 'setup-types')
    no_error(pg, 'Setup Types')
    check(pg.locator('td', has_text='Workspace (all applications)').count() > 0, 'level label reads Workspace (all applications)')
    fr = open_dialog(pg, pg.locator('.a-IRR-table a', has_text='Lookups'), 'setup-type')
    if fr:
        no_error(fr, 'Setup Type Lookups')
        fr.locator('button', has_text='Apply Changes').or_(fr.locator('button', has_text='Save')).first.click()
        pg.wait_for_timeout(3000)
        check(not [f for f in pg.frames if 'setup-type?' in (f.url or '').lower()], 'Setup Type saves and closes')
    else:
        check(False, 'Setup Type opens as a dialog')

    # Optional Features and Application Settings open
    go(pg, 'optional-features')
    no_error(pg, 'Optional Features')
    go(pg, 'application-settings')
    no_error(pg, 'Application Settings')

    # Lookup Type (102) and Descriptive Flexfield (153)
    go(pg, 'lookups')
    no_error(pg, 'Lookups')
    fr = open_dialog(pg, pg.locator('.a-IRR-table td a'), 'lookup-type')
    if fr:
        no_error(fr, 'Lookup Type')
        t = fr.locator('#P102_LOOKUP_TYPE').bounding_box(); a = fr.locator('#P102_APPLICATION_CODE').bounding_box()
        check(t and a and abs(t['y'] - a['y']) < 5, 'lookup type and application sit on one row')
        pg.keyboard.press('Escape'); pg.wait_for_timeout(800)
    go(pg, 'descriptive-flexfields')
    no_error(pg, 'Descriptive Flexfields')
    links = pg.locator('.a-IRR-table td a')
    if links.count():
        with pg.expect_navigation():
            links.first.click()
        pg.wait_for_load_state('networkidle')
        no_error(pg, 'Descriptive Flexfield')
        pg.locator('button', has_text='Apply Changes').or_(pg.locator('button', has_text='Save')).first.click()
        pg.wait_for_load_state('networkidle')
        no_error(pg, 'Descriptive Flexfield after save (XXFND_DFF_PKG.SAVE_FLEXFIELD_NAME)')

    check(not js_errors, f'no JavaScript errors {js_errors[:2]}')
    b.close()
print('FAILED' if fails else 'ALL PASSED')
