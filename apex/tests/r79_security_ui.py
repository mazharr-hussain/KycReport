# COMMON release 79 (Security): the users list (roles and data access per user), the User screen (record on top, tabs
# Roles and privileges / Data access with Effective access), the Role and Data access rule screens with their two
# tabs, and the one Assign dialog (page 183) opened from each of them.
# Usage: python3 r79_security_ui.py
import re
from playwright.sync_api import sync_playwright
ROOT = 'http://localhost:8080/ords'
fails = 0


def check(ok, msg):
    global fails
    print(('PASS ' if ok else 'FAIL ') + msg)
    fails += 0 if ok else 1


def no_error(pg, what):
    body = pg.inner_text('body')
    bad = [w for w in ('ORA-', 'error occurred', 'do not have access', 'Page not available') if w in body]
    check(not bad, f'{what} opens without error {bad or ""}')


def go(pg, alias):
    pg.goto(re.sub(r'/r/xxcus/common/[^?]*', f'/r/xxcus/common/{alias}', pg.url)); pg.wait_for_load_state('networkidle')


def tab_names(scope):
    return [t.strip() for t in scope.locator('ul[aria-label="Access"] .t-Tabs-link, ul[aria-label="Assigned To"] .t-Tabs-link').all_inner_texts() if t.strip()]


def open_assign(pg, frame_parent, button_text):
    frame_parent.locator('button', has_text=button_text).first.click()
    pg.wait_for_timeout(2500)
    frames = [f for f in pg.frames if 'assign' in (f.url or '').lower()]
    return frames[-1] if frames else None


with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args=['--no-sandbox'])
    pg = b.new_page(viewport={'width': 1400, 'height': 1000})
    js_errors = []
    pg.on('pageerror', lambda e: js_errors.append(str(e)[:200]))
    pg.goto(f'{ROOT}/r/xxcus/common/login')
    pg.fill('#P9999_USERNAME', 'ADMIN'); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')

    # users list: roles and data access per user
    go(pg, 'users')
    no_error(pg, 'Users and Access')
    heads = [h.strip() for h in pg.locator('.a-IRR-header').all_inner_texts()]
    check('Roles' in heads and 'Data Access (tables)' in heads and 'Language' in heads,
          f'users list shows roles, data access and language: {heads}')
    check(pg.locator('button', has_text='Sync from Fusion').count() == 0, 'no broken "Sync from Fusion" button')

    # User screen: record on top, two tabs
    with pg.expect_navigation():
        pg.locator('.a-IRR-table a', has_text='ADMIN').first.click()
    pg.wait_for_load_state('networkidle')
    no_error(pg, 'User ADMIN')
    check(pg.locator('#user').count() == 1, 'the user is on top')
    tabs = tab_names(pg)
    check(tabs[:2] == ['Roles and privileges', 'Data access'], f'User tabs: {tabs}')
    check(pg.locator('#user_roles td', has_text='Common Administrator').count() >= 1, 'ADMIN\'s role is listed')
    check(pg.locator('#user_privileges td').count() > 0, 'the privileges the roles give are listed')
    pg.locator('.t-Tabs-link', has_text='Data access').first.click()
    pg.wait_for_timeout(500)
    check(pg.locator('#user_effective').count() == 1, 'Data access tab shows Effective access')
    pg.locator('.t-Tabs-link', has_text='Roles and privileges').first.click(); pg.wait_for_timeout(300)
    fr = open_assign(pg, pg.locator('#user_roles'), 'Assign Roles')
    check(fr is not None, 'Assign Roles opens the Assign dialog')
    if fr:
        no_error(fr, 'Assign dialog (user > roles)')
        body = fr.inner_text('body')
        check('Assign roles to' in body and 'Roles' in body, 'the dialog names what it assigns (Assign roles to ...)')
        pg.keyboard.press('Escape'); pg.wait_for_timeout(800)

    # end to end: assign a role to TEST1 through the picker, then remove it with the Remove link
    go(pg, 'users')
    pg.locator('.a-IRR-search-field').first.fill('TEST1'); pg.keyboard.press('Enter'); pg.wait_for_timeout(1500)
    with pg.expect_navigation():
        pg.locator('.a-IRR-table a', has_text='TEST1').first.click()
    pg.wait_for_load_state('networkidle')
    fr = open_assign(pg, pg.locator('#user_roles'), 'Assign Roles')
    if fr:
        fr.locator('#P183_VALUES').click(); pg.wait_for_timeout(1200)
        pg.keyboard.type('Super Administrator'); pg.wait_for_timeout(1500)
        opt = pg.locator('.a-PopupLOV-results li, .a-IconList-item, .a-GV-row', has_text='Super Administrator').first
        if opt.count() == 0:
            opt = fr.locator('.a-PopupLOV-results li, .a-IconList-item, .a-GV-row', has_text='Super Administrator').first
        opt.click(); pg.wait_for_timeout(800)
        done = fr.locator('.ui-dialog-buttonpane button, .a-PopupLOV-dialog button', has_text='Done')
        if done.count():
            done.first.click(); pg.wait_for_timeout(500)
        fr.locator('#assign, .t-Region-title').first.click(force=True); pg.wait_for_timeout(300)
        fr.locator('button', has_text='Assign').last.click(); pg.wait_for_timeout(3000)
        pg.wait_for_load_state('networkidle')
        check(pg.locator('#user_roles td', has_text='Super Administrator').count() == 1,
              'assigned through the picker: the role shows on the user at once')
        pg.once('dialog', lambda d: d.accept())
        row = pg.locator('#user_roles tr', has_text='Super Administrator')
        if row.count():
            row.locator('a', has_text='Remove').click()
            pg.locator('.ui-dialog button', has_text='OK').first.click(timeout=10000)
            pg.wait_for_load_state('networkidle'); pg.wait_for_timeout(1500)
            check(pg.locator('#user_roles td', has_text='Super Administrator').count() == 0, 'Remove takes the role away')

    # Role screen: tabs Users / Data access and the same dialog
    go(pg, 'roles')
    with pg.expect_navigation(wait_until='networkidle') if False else pg.expect_event('framenavigated'):
        pg.locator('.a-IRR-table td a', has_text='COMMON_ADMIN').first.click()
    pg.wait_for_timeout(3000)
    rf = [f for f in pg.frames if 'role' in (f.url or '').lower() and 'roles' not in (f.url or '').lower()]
    check(bool(rf), 'Role screen opens')
    if rf:
        rf = rf[-1]
        no_error(rf, 'Role Common Administrator')
        tabs = tab_names(rf)
        check(tabs[:2] == ['Users', 'Data access'], f'Role tabs: {tabs}')
        check(rf.locator('#role_users td', has_text='ADMIN').count() >= 1, 'the role lists its users')
        check(rf.locator('#role_rules').count() == 1, 'the role lists its data access rules')

    # Data access rule screen: tabs Users / Roles
    go(pg, 'data-security')
    no_error(pg, 'Data Security')
    heads = [h.strip() for h in pg.locator('.a-IRR-header').all_inner_texts()]
    check('Assigned To' in heads, f'rules list shows who each rule is assigned to: {heads}')
    pg.locator('.a-IRR-table td a').first.click()
    pg.wait_for_timeout(3000)
    df = [f for f in pg.frames if 'data-security-rule' in (f.url or '').lower()]
    check(bool(df), 'Data access rule screen opens')
    if df:
        df = df[-1]
        no_error(df, 'Data access rule')
        tabs = tab_names(df)
        check(tabs[:2] == ['Users', 'Roles'], f'Rule tabs: {tabs}')
        check(df.locator('#P181_ROLE_CODE').count() == 0, 'the rule has no single role field any more')

    check(not js_errors, f'no JavaScript errors {js_errors[:2]}')
    b.close()
print('FAILED' if fails else 'ALL PASSED')
