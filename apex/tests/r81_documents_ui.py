# COMMON release 81 (C4 Documents and Records): the attachment setup screens open (Document Entities, Document
# Categories, Attachment Pages, Document Storage); Document Entity (131) saves its display name through
# XXFND_ATTACH_PKG; Retention (112) shows only the "not active yet" message, without the policy report.
# Usage: python3 r81_documents_ui.py
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


def dialog(pg, url_part):
    # the dialog's iframe gets its URL only once it loads: wait up to 15 s for it and its first field
    for _ in range(30):
        frames = [f for f in pg.frames if url_part in (f.url or '').lower()]
        if frames:
            frames[-1].wait_for_selector('#P131_USER_ENTITY_NAME', timeout=15000)
            return frames[-1]
        pg.wait_for_timeout(500)
    return None


with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args=['--no-sandbox'])
    pg = b.new_page(viewport={'width': 1400, 'height': 1000})
    js_errors = []
    pg.on('pageerror', lambda e: js_errors.append(str(e)[:200]))
    pg.goto(f'{ROOT}/r/xxcus/common/login')
    pg.fill('#P9999_USERNAME', 'ADMIN'); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')

    for alias, name in (('document-entities', 'Document Entities'), ('document-categories', 'Document Categories'),
                        ('attachment-pages', 'Attachment Pages'), ('document-storage', 'Document Storage')):
        go(pg, alias)
        no_error(pg, name)

    # Document Entity (131): display name saved through XXFND_ATTACH_PKG.SAVE_ENTITY_DISPLAY_NAME
    go(pg, 'document-entities')
    links = pg.locator('.a-IRR-table td a')
    if links.count():
        links.first.click()
        target = dialog(pg, 'document-entity')
        check(target is not None, 'Document Entity opens as a dialog')
        no_error(target, 'Document Entity')
        name = target.locator('#P131_USER_ENTITY_NAME')
        old = name.input_value()
        name.fill(old + ' R81'); target.locator('button', has_text='Apply Changes').first.click()
        pg.wait_for_timeout(3000); pg.wait_for_load_state('networkidle')
        no_error(pg, 'Document Entities after save')
        check(pg.locator('td', has_text=old + ' R81').count() > 0, 'display name saved')
        # put the name back
        pg.locator('.a-IRR-table td a').first.click()
        target = dialog(pg, 'document-entity')
        target.locator('#P131_USER_ENTITY_NAME').fill(old)
        target.locator('button', has_text='Apply Changes').first.click(); pg.wait_for_timeout(3000)
    else:
        check(False, 'a document entity to open')

    # Retention (112): the message only
    go(pg, 'retention-policies')
    no_error(pg, 'Retention')
    check('Retention is not active yet' in pg.inner_text('body'), 'Retention shows the not-active message')
    check(pg.locator('.a-IRR').count() == 0 and pg.locator('button', has_text='Create').count() == 0,
          'no policy report and no Create button')

    check(not js_errors, f'no JavaScript errors {js_errors[:2]}')
    b.close()
print('FAILED' if fails else 'ALL PASSED')
