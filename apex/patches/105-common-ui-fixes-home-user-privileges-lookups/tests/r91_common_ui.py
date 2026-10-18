"""Release 91 (COMMON UI issues 1, 3, 4, 5) in the browser, as ADMIN:
1 Home shows KPI tiles (Metric Card); 3 the User page (104) opens to create a user (Employee list of values);
4 Privileges (182) and Segregation of Duties (107) show the application of each row; 5 Lookup Type (102) has no
Customization Level field. Usage: r91_common_ui.py [user]
"""
import os, re, sys
from playwright.sync_api import sync_playwright

ROOT = os.environ.get('HOST', 'http://localhost:8080') + '/ords'
USER = sys.argv[1] if len(sys.argv) > 1 else 'ADMIN'
results = []


def ok(label, cond):
    results.append(cond)
    print(('PASS ' if cond else 'FAIL ') + label)


def open_page(pg, n):
    pg.goto(re.sub(r'/r/xxcus/common/[^?]*', f'/r/xxcus/common/{n}', pg.url)); pg.wait_for_load_state('networkidle')
    body = pg.inner_text('body')
    return body, [w for w in ('ORA-', 'PLS-', 'error occurred', 'Something went wrong', 'do not have access') if w in body]


with sync_playwright() as p:
    b = p.chromium.launch(executable_path=os.environ.get('CHROME', '/opt/pw-browsers/chromium-1194/chrome-linux/chrome'))
    pg = b.new_page(viewport={'width': 1280, 'height': 900})
    pg.goto(f'{ROOT}/r/xxcus/common/login')
    pg.fill('#P9999_USERNAME', USER); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')

    body, bad = open_page(pg, 1)
    tiles = pg.locator('#my_tasks .a-MetricCard, #my_tasks .t-MetricCard, #my_tasks [class*="etric"]').count()
    ok(f'1 Home: KPI tiles shown ({tiles}) {bad or ""}',
       not bad and all(t in body for t in ('Open tasks', 'Overdue tasks', 'Unread notifications')))
    pg.screenshot(path=os.environ.get('SHOT', '/tmp') + '/r91_home.png')

    body, bad = open_page(pg, 104)
    ok(f'3 User (104) opens to create a user, with the Employee list {bad or ""}',
       not bad and pg.locator('#P104_EMPLOYEE_ID').count() > 0)

    body, bad = open_page(pg, 182)
    ok(f'4 Privileges: Application column, roles with their application {bad or ""}',
       not bad and 'Application' in body and re.search(r'\((COMMON|KYC)\)', body) is not None)

    body, bad = open_page(pg, 107)
    ok(f'4 Segregation of Duties: Application column {bad or ""}', not bad and 'Application' in body)

    body, bad = open_page(pg, 102)
    ok(f'5 Lookup Type (create): no Customization Level field {bad or ""}',
       not bad and 'Customization Level' not in body and pg.locator('#P102_LOOKUP_TYPE').count() > 0)
    b.close()
print(f'{sum(results)}/{len(results)} passed')
sys.exit(0 if results and all(results) else 1)
