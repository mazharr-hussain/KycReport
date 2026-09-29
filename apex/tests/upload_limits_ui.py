"""R15 upload limits in the browser: OFFICER1 adds attachments to a party (page 21 -> Add Attachment drawer 90).
The drawer shows the accepted files and updates them with the category; a blocked type and a file over the limit
are refused with a clear message; an accepted file passes the checks (it then needs a configured document store:
without one the store step reports that, which proves the limits let it through).
Page 21 is limited to 1 MB for the test and restored afterwards.
Usage: upload_limits_ui.py [app-id]   (SQLCL env var: the SQLcl command, default 'sql'; connection name kyc_local)"""
import os, re, subprocess, sys, tempfile
from playwright.sync_api import sync_playwright

APP = sys.argv[1] if len(sys.argv) > 1 else '101'
HOST = 'http://localhost:8080'
SQLCL = os.environ.get('SQLCL', 'sql')
results = []


def ok(label, cond):
    results.append(cond)
    print(('PASS ' if cond else 'FAIL ') + label)


def db(sql):
    out = subprocess.run([SQLCL, '-S', '-name', 'kyc_local'], input=f'set heading off feedback off pages 0\n{sql};\nexit\n',
                         capture_output=True, text=True).stdout
    return [l.strip() for l in out.splitlines() if l.strip() and 'JAVA_TOOL' not in l]


tmp = tempfile.mkdtemp()
files = {'bad.exe': b'MZ' + b'0' * 1000, 'big.pdf': b'%PDF-1.4\n' + b'0' * (2 * 1024 * 1024), 'good.pdf': b'%PDF-1.4\n%%EOF\n'}
for name, data in files.items():
    open(os.path.join(tmp, name), 'wb').write(data)

db("begin update xxfnd_attachment_functions set max_file_size_mb = 1 where apex_app_alias = 'KYC' and apex_page_id = 21; commit; end;\n/\nselect 1 from dual")
try:
    with sync_playwright() as p:
        b = p.chromium.launch(executable_path=os.environ.get('CHROME', '/opt/pw-browsers/chromium-1194/chrome-linux/chrome'),
                              args=['--no-sandbox'])
        pg = b.new_page(viewport={'width': 1400, 'height': 900})
        pg.goto(f'{HOST}/ords/r/xxcus/kyc/login')
        pg.fill('#P9999_USERNAME', 'OFFICER1'); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
        pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
        s = re.search(r'session=(\d+)', pg.url).group(1)
        pg.goto(f'{HOST}/ords/f?p={APP}:20:{s}'); pg.wait_for_load_state('networkidle')
        pg.locator('.a-IRR-table a[href*="p21_party_id"]').first.click(); pg.wait_for_load_state('networkidle')

        def open_drawer():
            pg.click('button:has-text("Add Attachment")')
            f = pg.frame_locator('iframe').first
            f.locator('#P90_CATEGORY_CODE').wait_for()
            return f

        def attempt(f, filename):
            f.locator('#P90_CATEGORY_CODE').select_option('OTHER')
            pg.wait_for_timeout(1000)
            f.locator('#P90_FILE_CONTAINER input[type=file]').first.set_input_files(os.path.join(tmp, filename))
            f.locator('button:has-text("Add")').last.click()
            pg.wait_for_timeout(4000)
            frames = [x for x in pg.frames if x != pg.main_frame]
            return frames[-1].inner_text('body') if frames else pg.inner_text('body')

        f = open_drawer()
        f.locator('#P90_CATEGORY_CODE').select_option('OTHER')
        pg.wait_for_timeout(1500)
        rules = f.locator('#P90_UPLOAD_RULES_DISPLAY, #P90_UPLOAD_RULES').first.inner_text()
        ok(f'drawer shows the accepted files for the page: "{rules}"', 'up to 1 MB' in rules and 'PDF' in rules)

        text = attempt(f, 'bad.exe')
        ok('an .exe is refused', 'Files of type EXE are not accepted here' in text)
        text = attempt(pg.frame_locator('iframe').first, 'big.pdf')
        ok('a 2 MB file is refused on a 1 MB page', 'the limit for this document is 1 MB' in text)
        text = attempt(pg.frame_locator('iframe').first, 'good.pdf')
        ok('a small PDF passes the limits (reaches the store step)',
           'not accepted here' not in text and 'the limit for this document' not in text)
        b.close()
finally:
    db("begin update xxfnd_attachment_functions set max_file_size_mb = null where apex_app_alias = 'KYC' and apex_page_id = 21; commit; end;\n/\nselect 1 from dual")
print(f'{sum(results)}/{len(results)} passed')
sys.exit(0 if all(results) else 1)
