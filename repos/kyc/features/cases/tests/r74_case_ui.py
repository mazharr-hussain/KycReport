"""Release 74 case records in the browser: on the case's Risk Assessment section the officer records a guided source of
funds (the evidence expected is shown; unfitting evidence is refused) and raises an FIU (goAML) report; another manager
approves it and records the filing (reference, date) in the same drawer.
Usage: r74_case_ui.py [app-id]   (SQLCL env var: the SQLcl command; connection name kyc_local)"""
import os, re, subprocess, sys, time
from playwright.sync_api import sync_playwright

APP = sys.argv[1] if len(sys.argv) > 1 else '134'
HOST = 'http://localhost:8080'
SQLCL = os.environ.get('SQLCL', 'sql')
results = []


def ok(label, cond):
    results.append(bool(cond))
    print(('PASS ' if cond else 'FAIL ') + label)


def db(sql):
    out = subprocess.run([SQLCL, '-S', '-name', 'kyc_local'], input=f'set heading off feedback off pages 0\n{sql};\nexit\n',
                         capture_output=True, text=True).stdout
    return [l.strip() for l in out.splitlines() if l.strip() and 'JAVA_TOOL' not in l]


def login(b, user):
    pg = b.new_page()
    pg.on('pageerror', lambda e: print('JS ERROR', str(e)[:200]))
    pg.goto(f'{HOST}/ords/r/xxcus/kyc/login')
    pg.fill('#P9999_USERNAME', user); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
    return pg, re.search(r'session=(\d+)', pg.url).group(1)


def open_case(pg, s, cnum):
    pg.goto(f'{HOST}/ords/f?p={APP}:210:{s}'); pg.wait_for_load_state('networkidle')
    pg.fill('#report_search_field', cnum); pg.keyboard.press('Enter'); pg.wait_for_timeout(2500)
    with pg.expect_navigation():
        pg.locator('#report td a', has_text=cnum).first.click()
    pg.wait_for_load_state('networkidle')
    with pg.expect_navigation():
        pg.locator('#case_sections a', has_text='Risk Assessment').first.click()
    pg.wait_for_load_state('networkidle')


def errors(pg):
    m = re.search(r'ORA-\d{5}.{0,120}|error has occurred.{0,120}', pg.inner_text('body'))
    return m.group(0) if m else None


row = db("""select case_number || '|' || case_id from (select c.case_number, c.case_id from xxcmp_cases c
             where c.case_status = 'INVESTIGATION' and upper(c.assigned_to) = 'OFFICER1' order by c.case_id desc) where rownum = 1""")
cnum, case_id = row[0].split('|')

with sync_playwright() as p:
    b = p.chromium.launch(executable_path=os.environ.get('CHROME', '/opt/pw-browsers/chromium-1194/chrome-linux/chrome'),
                          args=['--no-sandbox'])
    pg, s = login(b, 'OFFICER1')
    open_case(pg, s, cnum)
    ok(f'Risk Assessment shows Source of Funds and Wealth with Add Source, and FIU Reports ({errors(pg) or "no error"})',
       not errors(pg) and pg.locator('#case_funds').count() == 1 and pg.locator('button:has-text("Add Source")').count() == 1
       and pg.locator('#case_fiu_reports').count() == 1)
    # ---------------------------------------------------------- guided source of funds
    pg.click('button:has-text("Add Source")')
    f = pg.frame_locator('iframe').first
    f.locator('#P218_CATEGORY').wait_for()
    f.locator('#P218_CATEGORY').select_option('SALARY')
    pg.wait_for_timeout(1500)
    fr = [x for x in pg.frames if x != pg.main_frame][-1]
    ok('choosing the source shows the evidence expected', 'Payslip' in fr.inner_text('#P218_EXPECTED_CONTAINER'))
    f.locator('#P218_AMOUNT').fill('25000'); f.locator('#P218_CURRENCY_CODE').fill('AED')
    f.locator('#P218_EVIDENCE_TYPE').select_option('WILL_PROBATE')
    f.locator('button:has-text("Create")').click()
    pg.wait_for_timeout(2500)
    ok('evidence that does not fit the source is refused', 'evidence expected is' in fr.inner_text('body'))
    f.locator('#P218_EVIDENCE_TYPE').select_option('PAYSLIP')
    f.locator('#P218_BANK_NAME').fill('Emirates Test Bank'); f.locator('#P218_ACCOUNT_REFERENCE').fill('...4321')
    f.locator('button:has-text("Create")').click()
    pg.locator('.ui-dialog iframe').wait_for(state='detached', timeout=30000); pg.wait_for_timeout(1500)
    r = db(f"select category || '|' || evidence_type || '|' || source from xxcmp_case_funds where case_id = {case_id} and bank_name = 'Emirates Test Bank'")
    ok(f'source of funds saved: {r}', r and r[-1] == 'SALARY|PAYSLIP|MANUAL')
    ok('listed as To verify', 'To verify' in pg.inner_text('#case_funds'))
    # ---------------------------------------------------------- FIU report
    pg.click('button:has-text("Raise FIU Report")')
    f = pg.frame_locator('iframe').first
    f.locator('#P219_GROUNDS').wait_for()
    f.locator('#P219_REPORT_TYPE').select_option('STR')
    f.locator('#P219_GROUNDS').fill('UI test: structured cash deposits')
    f.locator('button:has-text("Create")').click()
    pg.locator('.ui-dialog iframe').wait_for(state='detached', timeout=30000); pg.wait_for_timeout(1500)
    fiu = db(f"select max(fiu_report_id) from xxcmp_fiu_reports where case_id = {case_id} and grounds like 'UI test%'")[0]
    ok(f'FIU report {fiu} saved as Draft by the officer',
       db(f"select report_status || '|' || prepared_by from xxcmp_fiu_reports where fiu_report_id = {fiu}") == ['DRAFT|OFFICER1'])
    pg.locator('#case_fiu_reports a', has_text='Suspicious transaction').first.click()
    f = pg.frame_locator('iframe').first
    f.locator('#P219_GROUNDS').wait_for()
    ok('the preparer has no Approve button', f.locator('button:has-text("Approve")').count() == 0)
    f.locator('button:has-text("Cancel")').first.click()
    pg.close()
    # ---------------------------------------------------------- MGR1 approves and records the filing
    pg, s = login(b, 'MGR1')
    open_case(pg, s, cnum)
    pg.locator('#case_fiu_reports a', has_text='Suspicious transaction').first.click()
    f = pg.frame_locator('iframe').first
    f.locator('#P219_GROUNDS').wait_for()
    f.locator('button', has_text=re.compile(r'^\s*Approve\s*$')).click()
    pg.locator('.ui-dialog iframe').wait_for(state='detached', timeout=30000); pg.wait_for_timeout(1500)
    ok('another manager approved it', db(f"select report_status || '|' || approved_by from xxcmp_fiu_reports where fiu_report_id = {fiu}") == ['APPROVED|MGR1'])
    pg.locator('#case_fiu_reports a', has_text='Suspicious transaction').first.click()
    f = pg.frame_locator('iframe').first
    f.locator('#P219_GOAML_REFERENCE').wait_for()
    f.locator('#P219_GOAML_REFERENCE').fill('GOAML-UI-1')
    fr = [x for x in pg.frames if x != pg.main_frame][-1]
    fr.evaluate("apex.item('P219_FILED_DATE').setValue(apex.date.format(new Date(), 'DD-MON-YYYY'))")
    f.locator('button:has-text("Record Filing")').click()
    pg.locator('.ui-dialog iframe').wait_for(state='detached', timeout=30000); pg.wait_for_timeout(1500)
    ok('filing recorded with its goAML reference',
       db(f"select report_status || '|' || goaml_reference from xxcmp_fiu_reports where fiu_report_id = {fiu}") == ['FILED|GOAML-UI-1'])
    ok('listed as Filed', 'Filed with the FIU' in pg.inner_text('#case_fiu_reports'))
    pg.close()
    b.close()
print(f'{sum(results)}/{len(results)} passed')
sys.exit(0 if all(results) else 1)
