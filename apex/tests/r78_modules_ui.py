# COMMON release 78 (Foundation): the six modules. Home shows a card per module (no Applications report); the menu
# is Home then the modules; a module opens page 100 with its components and is expanded in the menu; the breadcrumb is
# Home > Module > Component; Optional Features and Approval Setup have their own menu entries; Subscriptions page.
# Usage: python3 r78_modules_ui.py
import re
from playwright.sync_api import sync_playwright
ROOT = 'http://localhost:8080/ords'
MODULES = ['Platform', 'Security', 'Reference Data', 'Documents and Records', 'Workflow', 'Integrations']
fails = 0


def check(ok, msg):
    global fails
    print(('PASS ' if ok else 'FAIL ') + msg)
    fails += 0 if ok else 1


def no_error(pg, what):
    body = pg.inner_text('body')
    bad = [w for w in ('ORA-', 'error occurred', 'do not have access', 'Page not available') if w in body]
    check(not bad, f'{what} opens without error {bad or ""}')


with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args=['--no-sandbox'])
    pg = b.new_page(viewport={'width': 1400, 'height': 1000})
    js_errors = []
    pg.on('pageerror', lambda e: js_errors.append(str(e)[:200]))
    pg.goto(f'{ROOT}/r/xxcus/common/login')
    pg.fill('#P9999_USERNAME', 'ADMIN'); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')

    # Home: module cards, no Applications report
    no_error(pg, 'Home')
    cards = [t.strip() for t in pg.locator('#modules .t-Card-title').all_inner_texts()]
    check(cards == MODULES, f'Home shows the six module cards in order: {cards}')
    check(pg.locator('text=APEX ID').count() == 0, 'Home has no Applications report')
    check(pg.locator('#modules .t-Card', has_text='Documents and Records').filter(
        has_text='Retention not active').count() == 1, 'module card shows its state (Retention not active yet)')

    # menu: Home, (release 82) My Tasks, then the modules (no Administration level); the menu starts collapsed: open it
    if pg.locator('#t_TreeNav .a-TreeView-label:visible').count() == 0:
        pg.locator('#t_Button_navControl').click(); pg.wait_for_timeout(500)
    top = [t.strip() for t in pg.locator('#t_TreeNav > ul > li > div .a-TreeView-label').all_inner_texts()]
    check(top[:1] == ['Home'] and [t for t in top[1:] if t != 'My Tasks'] == MODULES, f'menu top level: {top}')
    check('Administration' not in top, 'no Administration level in the menu')

    # a module opens page 100 with its components and is expanded in the menu
    with pg.expect_navigation():
        pg.locator('#t_TreeNav .a-TreeView-label:visible', has_text='Security').first.click()
    pg.wait_for_load_state('networkidle'); pg.wait_for_timeout(800)
    if pg.locator('#t_TreeNav .a-TreeView-label:visible').count() == 0:
        pg.locator('#t_Button_navControl').click(); pg.wait_for_timeout(500)
    no_error(pg, 'Security module page')
    comps = [t.strip() for t in pg.locator('#components .t-Card-title').all_inner_texts()]
    check(comps == ['Users & Access', 'Roles & Privileges', 'Data Security', 'Audit Log'], f'Security components: {comps}')
    check(pg.title().startswith('Security'), f'page title is the module: {pg.title()}')
    node = pg.locator('#t_TreeNav .a-TreeView-label:visible', has_text='Security').first
    check(node.get_attribute('aria-expanded') == 'true', 'Security is expanded in the menu')
    check(pg.locator('#t_TreeNav .a-TreeView-label:visible', has_text='Audit Log').count() == 1,
          'its components are visible in the menu')

    # breadcrumb Home > Module > Component
    with pg.expect_navigation():
        pg.locator('#components .t-Card', has_text='Roles & Privileges').locator('a').first.click()
    pg.wait_for_load_state('networkidle')
    crumbs = [t.strip() for t in pg.locator('.t-Breadcrumb-label').all_inner_texts()]
    check(crumbs[:2] == ['Home', 'Security'], f'breadcrumb Home > Security > ...: {crumbs}')
    with pg.expect_navigation():
        pg.locator('.t-Breadcrumb-item a', has_text='Security').first.click()
    pg.wait_for_load_state('networkidle')
    check(pg.title().startswith('Security'), 'the module breadcrumb opens the module page')

    # Platform: Optional Features entry; Workflow: Approval Setup entry; Notifications under Workflow
    with pg.expect_navigation():
        pg.locator('#t_TreeNav .a-TreeView-label:visible', has_text='Platform').first.click()
    pg.wait_for_load_state('networkidle')
    comps = [t.strip() for t in pg.locator('#components .t-Card-title').all_inner_texts()]
    check(comps == ['Applications', 'Application Settings', 'Optional Features'], f'Platform components: {comps}')
    with pg.expect_navigation():
        pg.locator('#components .t-Card', has=pg.locator('.t-Card-title', has_text=re.compile('^Optional Features$'))).locator('a').first.click()
    pg.wait_for_load_state('networkidle')
    no_error(pg, 'Optional Features')
    check(pg.title().startswith('Optional Features'), f'page 10020 is Optional Features: {pg.title()}')
    with pg.expect_navigation():
        pg.locator('#t_TreeNav .a-TreeView-label:visible', has_text='Workflow').first.click()
    pg.wait_for_load_state('networkidle')
    comps = [t.strip() for t in pg.locator('#components .t-Card-title').all_inner_texts()]
    check(comps[:3] == ['Workflow Setup', 'Approval Setup', 'Notifications'] and set(comps[3:]) <= {'Workflow Monitor'}, f'Workflow components: {comps}')   # release 82: + Workflow Monitor

    # Subscriptions (tab of Applications)
    pg.goto(re.sub(r'/r/xxcus/common/[^?]*', '/r/xxcus/common/applications', pg.url)); pg.wait_for_load_state('networkidle')
    tabs = [t.strip() for t in pg.locator('.t-Tabs-label').all_inner_texts()]
    check('Subscriptions' in tabs, f'Applications tabs include Subscriptions: {tabs}')
    with pg.expect_navigation():
        pg.locator('.t-Tabs-link', has_text='Subscriptions').first.click()
    pg.wait_for_load_state('networkidle')
    no_error(pg, 'Subscriptions')

    check(not js_errors, f'no JavaScript errors {js_errors[:2]}')
    b.close()
print('FAILED' if fails else 'ALL PASSED')
