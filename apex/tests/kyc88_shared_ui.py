"""KYC release 88 in the browser: KYC has no copy of a COMMON screen; its menu opens COMMON's pages in the same session.
  - ADMIN: the Administration menu lists KYC's own setup (KYC Rules, Alert Rules) and Shared Setup (COMMON page 100);
    My Tasks opens COMMON page 40 and Feedback COMMON page 173 without a second sign-in; KYC's list and setup pages
    open without an error
  - REQ1 (requester): My Tasks opens COMMON page 40; no Administration menu
  - the removed KYC pages are gone (40, 100, 10050 answer "page not found")
Usage: kyc88_shared_ui.py [app-id]"""
import os, re, sys
from playwright.sync_api import sync_playwright

APP = sys.argv[1] if len(sys.argv) > 1 else '134'
HOST = 'http://localhost:8080'
results = []
ERR = re.compile(r'Contact your application administrator|ORA-\d{5}|Session state protection violation|'
                 r'An unexpected (internal )?error|Technical Info|Error processing|checksum', re.I)
DENY = re.compile(r'You do not have access to|You are not allowed to|Insufficient privileges', re.I)


def ok(label, cond):
    results.append(bool(cond))
    print(('PASS ' if cond else 'FAIL ') + label)


def login(b, user):
    pg = b.new_page()
    errors = []
    pg.on('pageerror', lambda e: errors.append(str(e)[:200]))
    pg.goto(f'{HOST}/ords/r/xxcus/kyc/login')
    pg.fill('#P9999_USERNAME', user); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
    return pg, re.search(r'session=(\d+)', pg.url).group(1), errors


def body(pg):
    return pg.inner_text('body') if pg.query_selector('body') else ''


def menu_link(pg, label):
    # the tree renders a parent's entries when it is expanded
    pg.evaluate("() => { try { apex.jQuery('#t_TreeNav').treeView('expandAll'); } catch (e) {} }")
    return pg.locator(f'#t_TreeNav a:text-is("{label}"), #t_TreeNav span:text-is("{label}")').first


def href_of(pg, label):
    link = pg.locator(f'#t_TreeNav a:text-is("{label}")')
    if menu_link(pg, label).count() == 0 or link.count() == 0:
        return ''
    return link.first.get_attribute('href') or ''


def follow(pg, href):
    if not href:
        return
    if href.startswith('/'):
        href = HOST + href
    elif not href.startswith('http'):
        href = f'{HOST}/ords/' + href
    pg.goto(href); pg.wait_for_load_state('networkidle')


with sync_playwright() as p:
    b = p.chromium.launch(executable_path=os.environ.get('CHROME', '/opt/pw-browsers/chromium-1194/chrome-linux/chrome'),
                          args=['--no-sandbox'])
    # ------------------------------------------------------------ ADMIN
    pg, s, jserr = login(b, 'ADMIN')
    ok('ADMIN signs in to KYC', '/kyc/' in pg.url and not ERR.search(body(pg)))
    ok('the menu has Administration', menu_link(pg, 'Administration').count() == 1)
    for label in ('KYC Rules', 'Alert Rules', 'Shared Setup'):
        ok(f'Administration lists {label}', menu_link(pg, label).count() == 1)
    ok('no menu entry links to a removed KYC page',
       not re.search(r'/kyc/(my-tasks|workflow-monitor|administration|setup|feedback|activity-reports)\b', pg.content()))

    href = href_of(pg, 'Shared Setup')
    follow(pg, href)
    ok('Shared Setup opens COMMON Administration in the same session (' + pg.url.split('/ords/')[-1][:60] + ')',
       '/common/' in pg.url and '/login' not in pg.url and not ERR.search(body(pg)))

    pg.goto(f'{HOST}/ords/f?p={APP}:1:{s}'); pg.wait_for_load_state('networkidle')
    href = href_of(pg, 'KYC Rules')
    follow(pg, href)
    ok('KYC Rules opens the KYC Questionnaires page', '/kyc/' in pg.url and not ERR.search(body(pg)) and not DENY.search(body(pg)))

    pg.goto(f'{HOST}/ords/f?p={APP}:1:{s}'); pg.wait_for_load_state('networkidle')
    href = href_of(pg, 'My Tasks')
    follow(pg, href)
    ok('My Tasks opens COMMON page 40 without a second sign-in (' + pg.url.split('/ords/')[-1][:60] + ')',
       '/common/' in pg.url and '/login' not in pg.url and 'My Tasks' in pg.title() and not ERR.search(body(pg)))

    pg.goto(f'{HOST}/ords/f?p={APP}:1:{s}'); pg.wait_for_load_state('networkidle')
    fb = pg.locator('.t-NavigationBar a:has-text("Feedback")').first
    href = fb.get_attribute('href') if fb.count() else ''
    ok('Feedback in the navigation bar links to COMMON (' + (href or '')[:70] + ')', href and 'common' in href.lower())
    if href:
        follow(pg, href)
        ok('Give Feedback opens in COMMON for the KYC page', '/common/' in pg.url and not ERR.search(body(pg))
           and not DENY.search(body(pg)))

    for page in (40, 100, 10050):
        pg.goto(f'{HOST}/ords/f?p={APP}:{page}:{s}'); pg.wait_for_load_state('networkidle')
        ok(f'KYC page {page} is gone', re.search(r'not found|does not exist', body(pg), re.I) is not None)

    for page in (1, 160, 163, 167, 138, 165, 225, 10010):
        pg.goto(f'{HOST}/ords/f?p={APP}:{page}:{s}'); pg.wait_for_load_state('networkidle')
        t = body(pg)
        ok(f'KYC page {page} opens for ADMIN without an error', not ERR.search(t) and not DENY.search(t))
    ok('no JavaScript error for ADMIN: ' + '; '.join(jserr[:2]), not jserr)

    # ------------------------------------------------------------ REQ1
    pg, s, jserr = login(b, 'REQ1')
    ok('REQ1 has no Administration menu', menu_link(pg, 'Administration').count() == 0)
    href = href_of(pg, 'My Tasks')
    follow(pg, href)
    ok('REQ1: My Tasks opens COMMON page 40 (' + pg.url.split('/ords/')[-1][:60] + ')',
       '/common/' in pg.url and '/login' not in pg.url and not ERR.search(body(pg)) and not DENY.search(body(pg)))
    for page in (1, 200):
        pg.goto(f'{HOST}/ords/f?p={APP}:{page}:{s}'); pg.wait_for_load_state('networkidle')
        t = body(pg)
        ok(f'KYC page {page} opens for REQ1 without an error', not ERR.search(t) and not DENY.search(t))
    ok('no JavaScript error for REQ1: ' + '; '.join(jserr[:2]), not jserr)
    b.close()

print(f'{sum(results)} of {len(results)} passed')
