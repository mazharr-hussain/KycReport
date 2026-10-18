"""Release 92 (COMMON UI issues 6, 7) in the browser, as ADMIN: the Descriptive Flexfield page (153) of the parties
flexfield shows the fixed columns read-only, the Context Rule (By attribute, with its attribute shown and the function
hidden), and the segments grid with Display Name, API Name and Validation. Usage: r92_flexfield_ui.py [user]
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
    pg.goto(re.sub(r'/r/xxcus/common/[^?]*', '/r/xxcus/common/152', pg.url)); pg.wait_for_load_state('networkidle')
    pg.locator('a', has_text=re.compile('XXCMP_PARTIES|Part(y|ies)')).first.click()
    pg.wait_for_load_state('networkidle')
    body = pg.inner_text('body')
    ok('page opens without error', not any(w in body for w in ('ORA-', 'PLS-', 'error occurred')))
    ok('no "Derive Context From Column"; Context Rule shown', 'Derive Context From Column' not in body and 'Context Rule' in body)
    ok('Primary Key and Context Column are read-only (no select list)',
       pg.locator('select#P153_PK_COLUMN_NAME').count() == 0 and pg.locator('select#P153_CONTEXT_COLUMN_NAME').count() == 0)
    ok('rule is By attribute', pg.locator('#P153_CONTEXT_RULE_TYPE').input_value() == 'ATTRIBUTE')
    ok('attribute shown, function hidden',
       pg.locator('#P153_CONTEXT_REFERENCE_COLUMN').is_visible() and not pg.locator('#P153_CONTEXT_RULE_FUNCTION').is_visible())
    pg.select_option('#P153_CONTEXT_RULE_TYPE', 'FUNCTION'); pg.wait_for_timeout(500)
    ok('rule By function: function shown, attribute hidden',
       pg.locator('#P153_CONTEXT_RULE_FUNCTION').is_visible() and not pg.locator('#P153_CONTEXT_REFERENCE_COLUMN').is_visible())
    seg = pg.locator('#segments').inner_text()
    ok('segments grid: Display Name, API Name, Validation', all(h in seg for h in ('Display Name', 'API Name', 'Validation')))
    pg.screenshot(path=os.environ.get('SHOT', '/tmp') + '/r92_flexfield.png', full_page=True)
    b.close()
print(f'{sum(results)}/{len(results)} passed')
sys.exit(0 if results and all(results) else 1)
