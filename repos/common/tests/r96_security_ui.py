"""Release 96 (COMMON security model) in the browser, as ADMIN (after r96_security_ui_setup.sql):
User (104) names the user in its title, shows the user's applications and the data access values per role; the Data
Access Values dialog (184) gives Requester's assignment of REQ1 Finance and Procurement by default and Finance only on
the test object; Data Security (180) lists the data objects, Data Object (181) the roles reaching it; Role (106) has the
Roles inside and Data access tabs; Organizations (186) lists the departments. Usage: r96_security_ui.py
"""
import os, re, subprocess, sys
from playwright.sync_api import sync_playwright

ROOT = os.environ.get('HOST', 'http://localhost:8080') + '/ords'
SQLCL = os.environ.get('SQLCL', 'sql')
results = []


def ok(label, cond):
    results.append(bool(cond))
    print(('PASS ' if cond else 'FAIL ') + label)


def db(sql):
    out = subprocess.run([SQLCL, '-S', '-name', 'xxfusion_local'], input=f'set heading off feedback off pages 0\n{sql};\nexit\n',
                         capture_output=True, text=True).stdout
    return [l.strip() for l in out.splitlines() if l.strip() and 'JAVA_TOOL' not in l][-1]


def bad(body):
    return [w for w in ('ORA-', 'PLS-', 'error occurred', 'Something went wrong') if w in body]


def go(pg, page):
    pg.goto(re.sub(r'/r/xxcus/common/[^?]*', f'/r/xxcus/common/{page}', pg.url)); pg.wait_for_load_state('networkidle')


def dialog(pg):
    pg.wait_for_selector('iframe', timeout=30000)
    fr = pg.query_selector('iframe').content_frame(); fr.wait_for_load_state('networkidle')
    return fr


with sync_playwright() as p:
    b = p.chromium.launch(executable_path=os.environ.get('CHROME', '/opt/pw-browsers/chromium-1194/chrome-linux/chrome'))
    pg = b.new_page(viewport={'width': 1400, 'height': 1000})
    pg.goto(f'{ROOT}/r/xxcus/common/login')
    pg.fill('#P9999_USERNAME', 'ADMIN'); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')

    # User page of REQ1
    go(pg, 103)
    pg.locator('a', has_text='REQ1').first.click(); pg.wait_for_load_state('networkidle')
    body = pg.inner_text('body')
    ok(f'User page opens without error {bad(body)}', not bad(body))
    crumbs = pg.inner_text('.t-Breadcrumb')
    ok(f'title and breadcrumb name the user: "{crumbs.splitlines()[-1] if crumbs else ""}"', 'REQ1' in crumbs)
    ok('Applications region lists KYC', 'KYC' in pg.inner_text('#user_applications'))
    roles = pg.inner_text('#user_roles')
    ok('roles show Data Access Values and a Values link', 'Values' in roles)
    pg.screenshot(path=os.environ.get('SHOT', '/tmp') + '/r96_user.png', full_page=True)

    # Data Access Values of the Requester assignment: default Finance + Procurement, override Finance on the test object
    pg.locator('#user_roles tr', has_text='Requester').locator('a', has_text='Values').first.click()
    fr = dialog(pg)
    ok('Data Access Values dialog lists the Department rows', 'Department' in fr.inner_text('#assignment_values'))
    fr.locator('#assignment_values tr', has_text='All data objects').locator('a', has_text='Change').first.click()
    fr.wait_for_selector('#change_values:has-text("default")'); fr.wait_for_load_state('networkidle')
    for v in ('FINANCE', 'PROCUREMENT'):
        fr.check(f'#P184_VALUES input[value="{v}"]')
    fr.click('#change_values button:has-text("Save")'); fr.wait_for_selector('text=Values saved.'); fr.wait_for_load_state('networkidle')
    fr.locator('#assignment_values tr', has_text='Approval Paths').locator('a', has_text='Change').first.click()
    fr.wait_for_selector('#change_values:has-text("Approval Paths")'); fr.wait_for_load_state('networkidle')
    for cb in fr.query_selector_all('#P184_VALUES input'):
        if cb.is_checked():
            cb.uncheck()
    fr.check('#P184_VALUES input[value="FINANCE"]')
    fr.click('#change_values button:has-text("Save")'); fr.wait_for_selector('text=Values saved.'); fr.wait_for_load_state('networkidle')
    v_req = db("select xxfnd_vpd_pkg.allowed_values('XXCMP_REQUESTS', 'REQUESTING_DEPARTMENT', 'REQ1') from dual")
    v_obj = db("select xxfnd_vpd_pkg.allowed_values('XXCMP_APPROVAL_PATHS', 'REQUESTING_DEPARTMENT', 'REQ1') from dual")
    ok(f'saved: requests {v_req}, test object {v_obj}', v_req == 'FINANCE,PROCUREMENT' and v_obj == 'FINANCE')
    pg.keyboard.press('Escape')

    # Data Security list and a data object
    go(pg, 180)
    body = pg.inner_text('body')
    ok(f'Data Security lists data objects and dimensions {bad(body)}',
       not bad(body) and 'KYC Requests' in body and 'Department' in pg.inner_text('#dimensions'))
    pg.locator('#report a', has_text='KYC Requests').first.click()
    fr = dialog(pg)
    ok('Data Object shows the roles reaching it', 'Requester' in fr.inner_text('#object_roles'))
    pg.keyboard.press('Escape')

    # Role page tabs
    go(pg, 105)
    pg.locator('a', has_text='Requester').first.click()
    fr = dialog(pg)
    txt = fr.inner_text('body')
    ok(f'Role has Roles inside and Data access {bad(txt)}', 'Roles inside' in txt and 'Data access' in txt and not bad(txt))
    pg.keyboard.press('Escape')

    # Organizations
    go(pg, 186)
    body = pg.inner_text('body')
    ok(f'Organizations lists the departments {bad(body)}', 'Finance' in body and 'Procurement' in body and not bad(body))
    b.close()
print(f'{sum(results)}/{len(results)} passed')
sys.exit(0 if results and all(results) else 1)
