"""Release 90 (COMMON, C12) in the browser: COMMON's My Tasks opens another application's task page (KYC 206 approval,
KYC 211 case) without "Session state protection violation", and COMMON's own tasks still open.
Needs open tasks of OFFICER1 of both kinds (the KYC DB tests leave them). Usage: r90_my_tasks_ui.py [user]
"""
import os, re, sys
from playwright.sync_api import sync_playwright

HOST = os.environ.get('HOST', 'http://localhost:8080')
USER = sys.argv[1] if len(sys.argv) > 1 else 'OFFICER1'
results = []


def ok(label, cond):
    results.append(cond)
    print(('PASS ' if cond else 'FAIL ') + label)


with sync_playwright() as p:
    b = p.chromium.launch(executable_path=os.environ.get('CHROME', '/opt/pw-browsers/chromium-1194/chrome-linux/chrome'))
    pg = b.new_page(viewport={'width': 1280, 'height': 800})
    pg.goto(f'{HOST}/ords/r/xxcus/kyc/login')
    pg.fill('#P9999_USERNAME', USER); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
    s = re.search(r'session=(\d+)', pg.url).group(1)
    for task_type, expect in [('Document Checklist Review', 'KYC Request'), ('Case Investigation', 'Case'),
                              ('Case Approval', 'Case'), ('Review Information Received', None),
                              ('Provide Requested Information', None)]:
        pg.goto(f'{HOST}/ords/r/xxcus/common/my-tasks?session={s}'); pg.wait_for_load_state('networkidle')
        pg.wait_for_timeout(1000)     # no search: an Interactive Report search would add up across the loop
        row = pg.locator('.a-IRR-table tr', has_text=task_type).locator('td a').first
        if row.count() == 0:
            print(f'SKIP no open "{task_type}" task of {USER}')
            continue
        href = row.get_attribute('href') or ''
        with pg.expect_navigation(timeout=120000):
            row.click()
        pg.wait_for_load_state('networkidle')
        body = pg.inner_text('body')
        if 'Access denied by Page security check' in body:
            # the link works; the user lacks the page's privilege (test data: e.g. a requester owning a case task)
            ok(f'"{task_type}": the link is accepted, the page refuses {USER} by its own privilege check',
               'Session state protection violation' not in body)
            continue
        ok(f'"{task_type}" opens from COMMON My Tasks: {pg.title()} (link has a checksum: {"cs=" in href})',
           'Session state protection violation' not in body and (expect is None or expect in pg.title()))
    b.close()
print(f'{sum(results)}/{len(results)} passed')
sys.exit(0 if results and all(results) else 1)
