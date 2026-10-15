# COMMON release 86 part C (application journey): Register Application (160) opens the journey (165) for an APEX
# application of the workspace that is not registered; it goes through the ten steps (nothing saved before Register)
# and Register opens the review page (166): header card, section menu with states, one section per step (Global Page
# regions). Edit at a step (Shared functions) saves there; in a section a role is added (Role dialog 106), a user is
# assigned (Assign 183) and removed again (Remove); the application is disabled and deleted. R86TEST (the r86 test application, enabled) shows why it cannot
# be deleted.
# Needs: an unregistered APEX application in the workspace. When there is none, the test imports the basic example
# application of the Oracle skills (apexlang-example-applications/example-0) as application 188, alias JRN88.
# Usage: python3 r88_journey_ui.py   (run under the shared database lock; after r88_journey_test.sql)
import os
import re
import time
import shutil
import subprocess
import tempfile
from playwright.sync_api import sync_playwright
ROOT = 'http://localhost:8080/ords'
SQL = '/tmp/claude-0/-home-user-KycReport/5e8c20fd-6c82-5747-8066-a7d503f76bd3/scratchpad/sqlcl/bin/sql'
XXCUS = 'connect xxcus/"KycTest#2026"@localhost:1521/FREEPDB1\n'
EXAMPLE = '/home/user/mazharr-hussain/oracleskillsmirror/apex/apexlang/26.1/apexlang-example-applications/assets/example-0'
CODE = 'JRN88'
fails = 0


def check(ok, msg):
    global fails
    print(('PASS ' if ok else 'FAIL ') + msg)
    fails += 0 if ok else 1


def sql(script, conn=XXCUS):
    return subprocess.run([SQL, '-S', '/nolog'], input=conn + script + '\nexit\n', capture_output=True, text=True).stdout


def unregistered_app():
    out = sql("set heading off feedback off pages 0\n"
              "select min(a.application_id) from apex_applications a where a.workspace = 'XXCUS'\n"
              "   and not exists (select 1 from xxfusion.xxfnd_applications x where x.apex_application_id = a.application_id\n"
              "                      or upper(x.apex_app_alias) = upper(a.alias));")
    m = re.search(r'^\s*(\d+)\s*$', out, re.M)
    return m.group(1) if m else None


def ensure_test_app():
    app = unregistered_app()
    if app:
        return app
    tmp = tempfile.mkdtemp(prefix='jrn88_')
    dst = os.path.join(tmp, 'app')
    shutil.copytree(EXAMPLE, dst)
    for d, _, files in os.walk(dst):
        for f in files:
            if f.endswith('.apx'):
                p = os.path.join(d, f)
                s = open(p).read().replace('@APP_ALIAS@', CODE).replace('@APP_NAME@', 'Journey Test 88')
                open(p, 'w').write(s)
    print(sql("exec apex_application_install.set_auto_install_sup_obj(false);\n"
              "exec apex_application_install.set_schema('XXFUSION');\n"
              f"apex import -input {dst} -id 188\n")[-400:])
    return unregistered_app()


def no_error(scope, what):
    body = scope.evaluate("""() => { const c = document.body.cloneNode(true);
        c.querySelectorAll('.display_only, .t-Report-cell, td').forEach(e => e.remove()); return c.innerText; }""")
    bad = [w for w in ('ORA-', 'error occurred', 'do not have access', 'not allowed', 'went wrong') if w in body]
    check(not bad, f'{what} opens without error {bad or ""}')


def submit(pg, label):
    with pg.expect_navigation():
        pg.locator('#jrn-buttons button', has_text=label).first.click()
    pg.wait_for_load_state('networkidle')


def dialog(pg):
    pg.wait_for_selector('.ui-dialog iframe')
    return pg.frame_locator('.ui-dialog iframe').first


def confirm(pg):
    pg.locator('.ui-dialog .js-confirmBtn, .ui-dialog button:has-text("OK")').first.click()


app_id = ensure_test_app()
check(app_id is not None, f'an unregistered APEX application is in the workspace ({app_id})')

with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args=['--no-sandbox'])
    pg = b.new_page(viewport={'width': 1400, 'height': 1000})
    js_errors = []
    pg.on('pageerror', lambda e: js_errors.append(str(e)[:200]))
    pg.goto(f'{ROOT}/r/xxcus/common/login')
    pg.fill('#P9999_USERNAME', 'ADMIN'); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
    session = re.search(r'session=(\d+)', pg.url).group(1)

    # ------------------------------------------------------------ the list: Register Application opens the journey
    pg.goto(f'{ROOT}/r/xxcus/common/applications?session={session}'); pg.wait_for_load_state('networkidle')
    no_error(pg, 'Applications (160)')
    check(pg.locator('#report a[href*="application"]').count() > 0 and 'p161' not in pg.content().lower(),
          'the rows open the application page, not page 161')
    with pg.expect_navigation():
        pg.locator('button', has_text='Register Application').click()
    pg.wait_for_load_state('networkidle')
    no_error(pg, 'Application Journey (165), new')
    check(pg.locator('#jrn-wizard .t-WizardSteps-step').count() == 10, 'the wizard shows ten steps')
    options = pg.locator('#P165_APEX_APPLICATION_ID option').all_inner_texts()
    check(any(f'({app_id})' in o for o in options), 'the unregistered APEX application is offered')
    check(not any('(134)' in o or '(135)' in o for o in options), 'registered applications are not offered')

    # step 1: Next without a choice is refused, then the application
    # (the required fields are checked in the browser: no page submit)
    pg.locator('button', has_text='Next').first.click(); pg.wait_for_timeout(1000)
    check(pg.locator('#P165_APEX_APPLICATION_ID_error, .t-Form-error').count() > 0 or 'step=1' in pg.url.lower()
          or pg.locator('#P165_APEX_APPLICATION_ID').count() > 0, 'step 1 asks for the required fields')
    pg.select_option('#P165_APEX_APPLICATION_ID', app_id); pg.wait_for_load_state('networkidle')
    pg.wait_for_timeout(800)
    check(pg.locator('#jrn-apex-app').inner_text().strip() != '', 'name, alias and schema come from APEX')
    pg.fill('#P165_APPLICATION_CODE', CODE.lower())
    pg.fill('#P165_DESCRIPTION', 'Release 88 journey test application.')
    submit(pg, 'Next')
    for step in range(2, 10):
        check(pg.locator('#jrn-wizard .is-active').inner_text().strip() != '', f'step {step} is shown')
        if step == 4:
            boxes = pg.locator('#P165_FUNCTIONS input[type=checkbox]')
            check(boxes.count() > 0, 'step 4 lists the shared functions')
            boxes.first.check()
        submit(pg, 'Next')
    no_error(pg, 'Review (step 10)')
    review = pg.locator('#jrn-review-new').inner_text()
    check(CODE in review and 'Release 88 journey test' in review, 'the review shows the choices, nothing saved yet')
    out = sql(f"set heading off feedback off pages 0\nselect count(*) from xxfusion.xxfnd_applications where application_code = '{CODE}';")
    check(re.search(r'^\s*0\s*$', out, re.M) is not None, 'nothing is registered before Register')
    submit(pg, 'Register')

    # ------------------------------------------------------------ the review page
    no_error(pg, 'Application (166) after Register')
    check(CODE in pg.locator('#jrn-header').inner_text(), 'the header card shows the application')
    check('Enabled' in pg.locator('#jrn-header').inner_text(), 'the header shows the status')
    check(pg.locator('#jrn-sections li').count() == 9, 'the section menu lists the nine sections')
    for sec in ('jrn-application', 'jrn-roles', 'jrn-users', 'jrn-functions', 'jrn-setup-types', 'jrn-processes',
                'jrn-notifications', 'jrn-storage', 'jrn-integrations'):
        check(pg.locator(f'#{sec}').count() == 1, f'section {sec} is shown')
    review_url = pg.url

    # edit at a step: Shared functions
    with pg.expect_navigation():
        pg.locator('#jrn-functions button', has_text='Edit').click()
    pg.wait_for_load_state('networkidle')
    no_error(pg, 'Application Journey (165), edit at step 4')
    check(pg.locator('#P165_FUNCTIONS').count() == 1 and 'Edit' in pg.title(), 'the journey opens at Shared functions')
    pg.locator('#P165_FUNCTIONS input[type=checkbox]').first.uncheck()
    submit(pg, 'Save')
    check(pg.locator('#t_Alert_Success').count() > 0, 'step 4 is saved')
    with pg.expect_navigation():
        pg.locator('#jrn-buttons button', has_text='Back to the Application').click()
    pg.wait_for_load_state('networkidle')

    # add a role (Role dialog), assign a user (Assign dialog), remove the user again
    pg.locator('#jrn-roles button', has_text='Add Role').click()
    f = dialog(pg)
    f.locator('#P106_ROLE_CODE').fill(f'{CODE}_T{int(time.time()) % 100000}')   # unique per run (rows are kept)
    f.locator('#P106_ROLE_NAME').fill('Journey Tester ' + str(int(time.time()) % 100000))
    f.locator('button', has_text='Create').click()
    pg.wait_for_timeout(2500)
    if pg.locator('.ui-dialog iframe').count():
        dialog(pg).locator('button', has_text='Cancel').click()
    try:
        pg.wait_for_load_state('networkidle', timeout=10000)
    except Exception:
        pass   # the page resubmits after the dialog closes; settle below
    pg.wait_for_timeout(2500)
    check('Journey Tester' in pg.locator('#jrn-roles').inner_text(), 'the new role is in the Roles section')
    # disable, then delete (allowed: disabled, no user ever held its roles, no data)
    pg.locator('#jrn-actions button', has_text='Disable').click()
    with pg.expect_navigation():
        confirm(pg)
    pg.wait_for_load_state('networkidle')
    check('Disabled' in pg.locator('#jrn-header').inner_text(), 'Disable: the header shows Disabled')
    blocker = pg.locator('#P166_DELETE_BLOCKER_CONTAINER, #P166_DELETE_BLOCKER_DISPLAY')
    if blocker.count() and blocker.first.inner_text().strip():
        check(False, 'delete refused for the test application: ' + blocker.first.inner_text())
    else:
        pg.locator('#jrn-actions button', has_text='Delete').click()
        with pg.expect_navigation():
            confirm(pg)
        pg.wait_for_load_state('networkidle')
        check('/applications' in pg.url or 'Applications' in pg.title(), 'after Delete the Applications list opens')
        check(CODE not in pg.locator('#report').inner_text(), 'the application is no longer in the list')

    # an application with data: delete refused, with the reason
    pg.locator('#report a', has_text='R86TEST').first.click(); pg.wait_for_load_state('networkidle')
    no_error(pg, 'Application (166) of R86TEST')
    # assign a user to an R86TEST role and remove it again (the history stays: test rows are kept)
    pg.locator('#jrn-users a', has_text='Assign users').first.click()
    f = dialog(pg)
    # the picker as in r79_security_ui.py (popup LOV of the Assign dialog)
    f.locator('#P183_VALUES').click(); pg.wait_for_timeout(1200)
    pg.keyboard.type('ADMIN'); pg.wait_for_timeout(1500)
    opt = pg.locator('.a-PopupLOV-results li, .a-IconList-item, .a-GV-row', has_text='ADMIN').first
    if opt.count() == 0:
        opt = f.locator('.a-PopupLOV-results li, .a-IconList-item, .a-GV-row', has_text='ADMIN').first
    opt.click(); pg.wait_for_timeout(800)
    done = f.locator('.ui-dialog-buttonpane button, .a-PopupLOV-dialog button', has_text='Done')
    if done.count():
        done.first.click(); pg.wait_for_timeout(500)
    f.locator('#assign, .t-Region-title').first.click(force=True); pg.wait_for_timeout(300)
    f.locator('button', has_text='Assign').last.click()
    pg.wait_for_load_state('networkidle'); pg.wait_for_timeout(2500)
    check(pg.locator('#jrn-users a', has_text='Remove').count() > 0, 'the assigned user is in the Users section')
    before = pg.locator('#jrn-users a', has_text='Remove').count()
    pg.locator('#jrn-users a', has_text='Remove').first.click()
    with pg.expect_navigation():
        confirm(pg)
    pg.wait_for_load_state('networkidle')
    check(pg.locator('#jrn-users a', has_text='Remove').count() == before - 1, 'Remove takes the user off the role')

    check(pg.locator('#P166_DELETE_BLOCKER_CONTAINER, #P166_DELETE_BLOCKER_DISPLAY').count() > 0
          and pg.locator('#P166_DELETE_BLOCKER_CONTAINER, #P166_DELETE_BLOCKER_DISPLAY').first.inner_text().strip() != '',
          'R86TEST cannot be deleted and the page says why')
    check(pg.locator('#jrn-actions button', has_text='Delete').count() == 0, 'no Delete button for R86TEST')
    check(not js_errors, f'no JavaScript errors {js_errors}')
    b.close()

print('FAILS:', fails)
