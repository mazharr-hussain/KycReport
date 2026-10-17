# COMMON release 86 part B (workspace servers, storage per application): Servers (120) lists the defined servers with
# their state; a Server (121) shows the fields its type needs (OCI Object Storage: region and namespace; SharePoint /
# Outlook: OAuth token URL) and keeps Test Connection; Document Storage (136) lists the applications with their storage
# state and opens the one storage editor (137: application default + category grid; the server decides the fields);
# a change of the application default is saved through XXFND_ATTACH_PKG; a Purpose (123) picks its server.
# Usage: python3 r87_servers_ui.py   (after r87_servers_test.sql, which leaves R87TEST, R87_OS, R87_REST, R87_TEST)
import re
from playwright.sync_api import sync_playwright
ROOT = 'http://localhost:8080/ords'
fails = 0


def check(ok, msg):
    global fails
    print(('PASS ' if ok else 'FAIL ') + msg)
    fails += 0 if ok else 1


def no_error(scope, what):
    body = scope.evaluate("""() => { const c = document.body.cloneNode(true);
        c.querySelectorAll('.display_only, .t-Report-cell, td').forEach(e => e.remove()); return c.innerText; }""")
    bad = [w for w in ('ORA-', 'error occurred', 'do not have access', 'Page not available', 'went wrong') if w in body]
    check(not bad, f'{what} opens without error {bad or ""}')


def go(pg, alias):
    pg.goto(re.sub(r'/r/xxcus/common/[^?]*', f'/r/xxcus/common/{alias}', pg.url)); pg.wait_for_load_state('networkidle')


def dialog(pg, url_part, selector, wait=15000):
    for _ in range(30):
        frames = [f for f in pg.frames if url_part in (f.url or '').lower()]
        if frames:
            frames[-1].wait_for_selector(selector, timeout=wait, state='attached')
            return frames[-1]
        pg.wait_for_timeout(500)
    return None


def visible(fr, item):
    return fr.locator(f'#{item}_CONTAINER').is_visible()


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
    check(all(s in body for s in ('FUSION', 'UCM_MAIN', 'SHAREPOINT_MAIN', 'R87_OS')), 'the defined servers are listed')
    check('OCI Object Storage' in body and 'Storage' in body and 'Integration' in body, 'type and use are shown')
    check('Incomplete' in body or 'OK' in body, 'the state of each server is shown')
    check(pg.locator('#endpoints').count() == 0, 'no registered endpoints any more')
    check(pg.locator('button', has_text='Create Server').count() == 1, 'a server can be created')

    # Server (121): the type decides the fields
    pg.locator('#servers .a-IRR-table td a', has_text='R87 Object Storage').first.click()
    fr = dialog(pg, 'server?', '#P121_SERVER_TYPE')
    check(fr is not None, 'Server dialog opens')
    if fr:
        no_error(fr, 'Server')
        fr.wait_for_timeout(800)
        check(visible(fr, 'P121_OCI_REGION') and visible(fr, 'P121_OCI_NAMESPACE')
              and not visible(fr, 'P121_OAUTH_TOKEN_URL'), 'Object Storage: region and namespace, no token URL')
        fr.select_option('#P121_SERVER_TYPE', 'SHAREPOINT'); fr.wait_for_timeout(600)
        check(visible(fr, 'P121_OAUTH_TOKEN_URL') and not visible(fr, 'P121_OCI_REGION'),
              'SharePoint: the OAuth token URL, no region')
        fr.select_option('#P121_SERVER_TYPE', 'REST'); fr.wait_for_timeout(600)
        check(not visible(fr, 'P121_OAUTH_TOKEN_URL') and not visible(fr, 'P121_OCI_REGION'), 'REST: no extra fields')
        check(fr.locator('button', has_text='Test Connection').count() == 1, 'Test Connection stays')
        check('eu-frankfurt-1' in (fr.locator('#P121_BASE_URL_CONTAINER').inner_text() or ''),
              'the URL of the region is shown without a Remote Server')
        fr.locator('button', has_text='Cancel').click(); pg.wait_for_timeout(800)

    # Document Storage (136): the applications and their storage state
    go(pg, 'document-storage')
    no_error(pg, 'Document Storage')
    body = pg.inner_text('#report')
    check('R87TEST' in body and 'COMMON' in body, 'every registered application is listed')
    row = pg.locator('#report .a-IRR-table tr', has_text='R87TEST').first
    check('OCI Object Storage' in row.inner_text() and 'OK' in row.inner_text(),
          f'R87TEST: Object Storage, OK ({row.inner_text()[:120]!r})')

    # the storage editor (137)
    pg.locator('#report .a-IRR-table td a', has_text='R87TEST').first.click()
    fr = dialog(pg, 'storage-rule?', '#P137_SERVER_CODE')
    check(fr is not None, 'the storage editor opens as a dialog')
    if fr:
        no_error(fr, 'Storage editor')
        fr.wait_for_timeout(800)
        check(fr.input_value('#P137_SERVER_CODE') == 'R87_OS' and fr.input_value('#P137_BUCKET') == 'bkt-app',
              'application default: server and bucket')
        check(visible(fr, 'P137_BUCKET') and not visible(fr, 'P137_SITE') and not visible(fr, 'P137_SECURITY_GROUP'),
              'Object Storage: the bucket only')
        grid = fr.inner_text('#categories')
        check('R87_CAT_B' in grid and 'bkt-b' in grid, f'the category grid shows the overrides ({grid[:1500]!r})')
        check('INCOMPLETE - using database' in grid or 'OK' in grid, 'each category shows its state')
        fr.select_option('#P137_SERVER_CODE', ''); fr.wait_for_timeout(1500)
        check(not visible(fr, 'P137_BUCKET') and not visible(fr, 'P137_FOLDER'), 'the database: no storage fields')
        fr.select_option('#P137_SERVER_CODE', 'R87_OS'); fr.wait_for_timeout(1500)
        check(visible(fr, 'P137_BUCKET'), 'back to Object Storage: the bucket again')
        fr.fill('#P137_FOLDER', '/r87ui/#PK1_VALUE#')
        # a category override typed in the grid (saved through XXFND_ATTACH_PKG.SAVE_CATEGORY_STORAGE)
        row_e = fr.locator('#categories .a-GV-row', has_text='R87_CAT_F').last
        cols = fr.locator('#categories .a-GV-hdr .a-GV-header').all_inner_texts()
        bucket_idx = [i for i, t in enumerate(cols) if t.strip() == 'Bucket']
        if bucket_idx:
            cell = row_e.locator('td').nth(bucket_idx[0] - 1)   # the row selector is a header without a cell here
            cell.dblclick(); fr.wait_for_timeout(500)
            pg.keyboard.press('Control+A'); pg.keyboard.type('bkt-e-ui'); pg.keyboard.press('Tab'); fr.wait_for_timeout(500)
        # leave the grid cell (the cell editor can cover the button on a short grid), then save
        fr.locator('#P137_FOLDER').click(); fr.wait_for_timeout(500)
        fr.locator('button', has_text='Apply Changes').scroll_into_view_if_needed()
        fr.locator('button', has_text='Apply Changes').click(force=True); pg.wait_for_timeout(4000)
        still = [f for f in pg.frames if 'storage-rule' in (f.url or '').lower()]
        if still:
            print('DIALOG STILL OPEN:', still[-1].inner_text('body')[:600])
        go(pg, 'document-storage')
        check('/r87ui/#PK1_VALUE#' in pg.inner_text('#report'), 'Apply Changes saves the application default')
        pg.locator('#report .a-IRR-table td a', has_text='R87TEST').first.click()
        fr = dialog(pg, 'storage-rule?', '#categories')
        grid = fr.inner_text('#categories') if fr else ''
        check('bkt-e-ui' in grid, 'Apply Changes saves the category typed in the grid')
        if fr:
            fr.locator('button', has_text='Cancel').click(); pg.wait_for_timeout(800)

    # Purposes (122/123): a purpose picks its server
    go(pg, 'integration-purposes')
    no_error(pg, 'Purposes')
    check('R87_REST' in pg.inner_text('#report'), 'the purposes list shows their server')
    pg.locator('#report .a-IRR-table td a', has_text='R87_TEST').first.click()
    fr = dialog(pg, 'integration-purpose?', '#P123_SERVER_CODE')
    check(fr is not None, 'Purpose opens')
    if fr:
        no_error(fr, 'Purpose')
        check(fr.input_value('#P123_SERVER_CODE') == 'R87_REST', 'the purpose shows its server')
        check(fr.locator('#P123_ENDPOINT_CODE').count() == 0, 'no retired endpoint field')
        fr.locator('button', has_text='Cancel').click(); pg.wait_for_timeout(800)

    check(not js_errors, f'no JavaScript error {js_errors[:3]}')
    b.close()
print('FAILS:', fails)
