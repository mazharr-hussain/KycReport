"""Release 94 (COMMON UI issue 8) in the browser, as ADMIN: Workflow Setup > Process Catalogue (147) shows each
process with its rules, steps, approvers, step deadlines and delegations (Approval Path per Process).
Usage: r94_process_ui.py [user]
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
    pg = b.new_page(viewport={'width': 1500, 'height': 1000})
    pg.goto(f'{ROOT}/r/xxcus/common/login')
    pg.fill('#P9999_USERNAME', USER); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
    pg.goto(re.sub(r'/r/xxcus/common/[^?]*', '/r/xxcus/common/147', pg.url)); pg.wait_for_load_state('networkidle')
    body = pg.inner_text('body')
    ok('Process Catalogue opens without error', not any(w in body for w in ('ORA-', 'PLS-', 'error occurred')))
    reg = pg.locator('#approval_paths')
    txt = reg.inner_text() if reg.count() else ''
    ok('Approval Path per Process shown with its columns',
       all(h in txt for h in ('Process', 'Rule', 'Step', 'Approver', 'Deadline', 'Delegated To')))
    rows = reg.locator('.a-IRR-table tr').count()
    ok(f'processes and their steps listed ({rows - 1} rows)', rows > 1)
    pg.screenshot(path=os.environ.get('SHOT', '/tmp') + '/r94_process.png', full_page=True)
    b.close()
print(f'{sum(results)}/{len(results)} passed')
sys.exit(0 if results and all(results) else 1)
