#!/usr/bin/env python3
"""COMMON pipeline step 6.3 - browser smoke test of the deployed application (Playwright, headless Chromium).

Each test user signs in, then opens every page of the application (one page file per page in the built app, except
the global page 0 and the login page). Every page gets a screenshot; each user gets a video and a Playwright trace
(open it with `playwright show-trace trace.zip`). A page that shows an Oracle / APEX error (outside its report cells) fails the step; a page the
user is not allowed to open is recorded as "no access" (expected for some users).

Usage: smoke_ui.py --base <ords url> --app-id 135 --app-path xxcus/common --pages <dist/app/pages> \
                   --users "TCOM_ADMIN TALL_ACCESS" --out <dir> [--skip "12 34"]
Env: UI_PASSWORD (the test users' password, from repos/common/db/admin/test-users.sql); CHROMIUM_PATH (optional).
"""
import argparse, json, os, re, sys
from urllib.parse import parse_qs, urlparse
from playwright.sync_api import sync_playwright

ERROR = re.compile(r'\b(ORA|PLS)-\d{5}\b|Error processing request|unexpected internal error|Application Express internal error',
                   re.I)
NO_ACCESS = re.compile(r'do not have access|not authorized|access denied|insufficient privileges', re.I)


def pages_of(folder, skip):
    out = []
    for name in sorted(os.listdir(folder)):
        m = re.match(r'p(\d+)-(.+)\.apx$', name)
        if m and int(m.group(1)) not in (0, 9999) and int(m.group(1)) not in skip:
            out.append((int(m.group(1)), m.group(2)))
    return out


def session_of(url):
    q = parse_qs(urlparse(url).query)
    if 'session' in q:
        return q['session'][0]
    m = re.search(r'f\?p=\d+:\d+:(\d+)', url)
    return m.group(1) if m else ''


def run_user(browser, args, user, pages, password):
    folder = os.path.join(args.out, user)
    os.makedirs(os.path.join(folder, 'screens'), exist_ok=True)
    ctx = browser.new_context(record_video_dir=os.path.join(folder, 'video'), viewport={'width': 1440, 'height': 900})
    ctx.tracing.start(screenshots=True, snapshots=True)
    page = ctx.new_page()
    results = []
    try:
        page.goto(f'{args.base}/r/{args.app_path}/login', wait_until='domcontentloaded')
        page.fill('#P9999_USERNAME', user)
        page.fill('#P9999_PASSWORD', password)
        page.click('#LOGIN, button:has-text("Sign In")')
        page.wait_for_load_state('networkidle', timeout=60000)
        session = session_of(page.url)
        page.screenshot(path=os.path.join(folder, 'screens', 'home.png'), full_page=True)
        if '/login' in page.url or not session:
            return [{'user': user, 'page': 'login', 'status': 'error', 'detail': 'sign-in failed: ' + page.url}]
        for number, name in pages:
            page.goto(f'{args.base}/f?p={args.app_id}:{number}:{session}', wait_until='domcontentloaded')
            try:
                page.wait_for_load_state('networkidle', timeout=30000)
            except Exception:
                pass                                  # long polling regions: the screenshot is still taken
            # the page's own text, without the cells of its reports: a report may show error messages as data (e.g.
            # Platform Activity lists earlier page errors) - an error page or a failed region is never inside a cell
            text = page.evaluate("""() => { const c = document.body.cloneNode(true);
                                             c.querySelectorAll('td').forEach(e => e.remove());
                                             return c.textContent; }""")
            hit = ERROR.search(text)
            status = 'error' if hit else 'no access' if NO_ACCESS.search(text) else 'ok'
            page.screenshot(path=os.path.join(folder, 'screens', f'p{number:05d}-{name}.png'), full_page=True)
            results.append({'user': user, 'page': number, 'name': name, 'status': status,
                            'detail': text[max(hit.start() - 80, 0):hit.end() + 160].strip() if hit else ''})
    finally:
        ctx.tracing.stop(path=os.path.join(folder, 'trace.zip'))
        ctx.close()
    return results


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--base', required=True)
    ap.add_argument('--app-id', required=True)
    ap.add_argument('--app-path', required=True)
    ap.add_argument('--pages', required=True)
    ap.add_argument('--users', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--skip', default='')
    args = ap.parse_args()
    password = os.environ.get('UI_PASSWORD') or sys.exit('UI_PASSWORD is not set')
    pages = pages_of(args.pages, {int(x) for x in args.skip.split()})
    results = []
    with sync_playwright() as p:
        # CHROMIUM_PATH: an already installed Chromium (local runs); the pipeline uses Playwright's own browser
        browser = p.chromium.launch(executable_path=os.environ.get('CHROMIUM_PATH') or None)
        for user in args.users.split():
            results += run_user(browser, args, user, pages, password)
        browser.close()
    json.dump(results, open(os.path.join(args.out, 'results.json'), 'w'), indent=1)
    errors = [r for r in results if r['status'] == 'error']
    counts = {s: sum(1 for r in results if r['status'] == s) for s in ('ok', 'no access', 'error')}
    print(f"UI smoke test: {len(pages)} page(s) x {len(args.users.split())} user(s) - "
          f"ok {counts['ok']}, no access {counts['no access']}, errors {counts['error']}")
    for r in errors:
        print(f"FAIL {r['user']} page {r['page']} {r.get('name', '')}: {r['detail']}")
    sys.exit(1 if errors else 0)


if __name__ == '__main__':
    main()
