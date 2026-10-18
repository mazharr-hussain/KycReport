"""Release 93 (COMMON UI issue 9) in the browser, as ADMIN: the Server page (121) of the Fusion server offers the
Fusion Integration Application; with one chosen, its own Web Credential list is hidden (the credential is read from the
application). Other server types do not show the choice. Usage: r93_fusion_server_ui.py [user]
"""
import os, re, sys
from playwright.sync_api import sync_playwright

ROOT = os.environ.get('HOST', 'http://localhost:8080') + '/ords'
USER = sys.argv[1] if len(sys.argv) > 1 else 'ADMIN'
results = []


def ok(label, cond):
    results.append(bool(cond))
    print(('PASS ' if cond else 'FAIL ') + label)


with sync_playwright() as p:
    b = p.chromium.launch(executable_path=os.environ.get('CHROME', '/opt/pw-browsers/chromium-1194/chrome-linux/chrome'))
    pg = b.new_page(viewport={'width': 1400, 'height': 1000})
    pg.goto(f'{ROOT}/r/xxcus/common/login')
    pg.fill('#P9999_USERNAME', USER); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
    pg.goto(re.sub(r'/r/xxcus/common/[^?]*', '/r/xxcus/common/120', pg.url)); pg.wait_for_load_state('networkidle')
    pg.locator('a', has_text='Oracle Fusion').first.click()
    pg.wait_for_selector('iframe', timeout=30000)          # the Server page is a modal dialog
    dlg = pg.query_selector('iframe').content_frame()
    dlg.wait_for_selector('#P121_SERVER_TYPE', timeout=30000)
    pg = dlg
    body = pg.inner_text('body')
    ok('Server page opens without error', not any(w in body for w in ('ORA-', 'PLS-', 'error occurred')))
    app = pg.locator('#P121_SOURCE_APPLICATION_ID')
    ok('Fusion server: Fusion Integration Application shown', app.is_visible())
    opts = [o for o in app.locator('option').all_inner_texts() if not o.startswith('-')]
    print('  applications offered:', opts)
    if opts:
        app.select_option(index=1); pg.wait_for_timeout(500)
        ok('application chosen: own Web Credential hidden', not pg.locator('#P121_CREDENTIAL_STATIC_ID').is_visible())
        app.select_option(index=0); pg.wait_for_timeout(500)
        ok('no application: own Web Credential shown', pg.locator('#P121_CREDENTIAL_STATIC_ID').is_visible())
    pg.select_option('#P121_SERVER_TYPE', 'OUTLOOK'); pg.wait_for_timeout(500)
    ok('other type: no Fusion application choice', not app.is_visible())
    b.close()
print(f'{sum(results)}/{len(results)} passed')
sys.exit(0 if results and all(results) else 1)
