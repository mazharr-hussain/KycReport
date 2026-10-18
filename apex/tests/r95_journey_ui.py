"""Release 95 (COMMON UI issue 2) in the browser, as ADMIN: the Application Journey registers a new application when
step 1 (application and administrator) is left with Next; step 2 then shows the application's Roles set-up (not the
note "Roles are added once the application is registered"), and later steps their set-up too.
Usage: r95_journey_ui.py <APEX app id to register> <code>   (the test application is deleted afterwards by the caller)
"""
import os, re, sys
from playwright.sync_api import sync_playwright

ROOT = os.environ.get('HOST', 'http://localhost:8080') + '/ords'
APP_ID = sys.argv[1] if len(sys.argv) > 1 else '188'
CODE = sys.argv[2] if len(sys.argv) > 2 else 'JRN95'
results = []


def ok(label, cond):
    results.append(bool(cond))
    print(('PASS ' if cond else 'FAIL ') + label)


with sync_playwright() as p:
    b = p.chromium.launch(executable_path=os.environ.get('CHROME', '/opt/pw-browsers/chromium-1194/chrome-linux/chrome'))
    pg = b.new_page(viewport={'width': 1400, 'height': 1000})
    pg.goto(f'{ROOT}/r/xxcus/common/login')
    pg.fill('#P9999_USERNAME', 'ADMIN'); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
    pg.goto(re.sub(r'/r/xxcus/common/[^?]*', '/r/xxcus/common/160', pg.url)); pg.wait_for_load_state('networkidle')
    with pg.expect_navigation():                      # Applications > Register Application (the journey, with its checksum)
        pg.click('button:has-text("Register"), a:has-text("Register")')
    pg.wait_for_load_state('networkidle')
    body = pg.inner_text('body')
    ok('step 1 asks for the administrator with the application', pg.locator('#P165_ADMIN_USER').count() > 0)
    pg.select_option('#P165_APEX_APPLICATION_ID', APP_ID); pg.wait_for_timeout(800)
    pg.fill('#P165_APPLICATION_CODE', CODE)
    pg.evaluate("apex.item('P165_ADMIN_USER').setValue('ADMIN', 'ADMIN')")
    with pg.expect_navigation():
        pg.click('button:has-text("Next")')
    pg.wait_for_load_state('networkidle')
    body = pg.inner_text('body')
    ok(f'Next registered {CODE} (no error)', 'registered' in body and not any(w in body for w in ('ORA-', 'PLS-', 'error occurred')))
    ok('step 2 sets up the roles (no "added once registered" note)',
       'Roles are added once' not in body and 'Role' in body)
    for step, words in ((3, ('User',)), (7, ('otif',)), (8, ('torage',)), (9, ('urpose', 'ntegration'))):
        while True:
            m = re.search(r'P165_STEP[^0-9]*(\d+)', '')
            cur = pg.evaluate("apex.item('P165_STEP').getValue()")
            if int(cur) >= step:
                break
            with pg.expect_navigation():
                pg.click('button:has-text("Next")')
            pg.wait_for_load_state('networkidle')
        body = pg.inner_text('body')
        ok(f'step {step} shows its set-up', any(w in body for w in words) and 'after registering' not in body
           and not any(w in body for w in ('ORA-', 'PLS-')))
    pg.screenshot(path=os.environ.get('SHOT', '/tmp') + '/r95_journey.png', full_page=True)
    b.close()
print(f'{sum(results)}/{len(results)} passed')
sys.exit(0 if results and all(results) else 1)
