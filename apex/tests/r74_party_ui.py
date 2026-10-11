"""Release 74 party component in the browser: the party card from the party package as a standard report (no HTML
from PL/SQL), the company registry (KYB) check of an organisation and the identity document check of an individual,
recorded by hand in their drawers from the Party page (Compliance), and the requester's view of their request's party.
Usage: r74_party_ui.py [app-id]   (SQLCL env var: the SQLcl command; connection name kyc_local)"""
import os, random, re, string, subprocess, sys
from playwright.sync_api import sync_playwright

APP = sys.argv[1] if len(sys.argv) > 1 else '134'
HOST = 'http://localhost:8080'
SQLCL = os.environ.get('SQLCL', 'sql')
TAG = ''.join(random.choice(string.ascii_uppercase) for _ in range(8))
ORG = f'Registry Check {TAG} LLC'
PER = f'Identity Check {TAG}'
results = []


def ok(label, cond):
    results.append(bool(cond))
    print(('PASS ' if cond else 'FAIL ') + label)


def db(sql):
    out = subprocess.run([SQLCL, '-S', '-name', 'kyc_local'], input=f'set heading off feedback off pages 0\n{sql};\nexit\n',
                         capture_output=True, text=True).stdout
    return [l.strip() for l in out.splitlines() if l.strip() and 'JAVA_TOOL' not in l]


db(f"""begin
  insert into xxcmp_parties (party_type, party_name, registration_number, registration_type, jurisdiction, entity_type, party_status)
  values ('ORGANIZATION', '{ORG}', 'RC-{TAG}', 'COMMERCIAL_REGISTRATION', 'AE', 'LLC', 'APPROVED');
  insert into xxcmp_parties (party_type, party_name, registration_number, registration_type, jurisdiction, party_status)
  values ('PERSON', '{PER}', 'ID-{TAG}', 'PASSPORT', 'AE', 'APPROVED');
  commit;
end;
/
select 1 from dual""")
org = db(f"select party_id from xxcmp_parties where party_name = '{ORG}'")[0]
per = db(f"select party_id from xxcmp_parties where party_name = '{PER}'")[0]


def login(b, user):
    pg = b.new_page()
    pg.on('pageerror', lambda e: print('JS ERROR', str(e)[:200]))
    pg.goto(f'{HOST}/ords/r/xxcus/kyc/login')
    pg.fill('#P9999_USERNAME', user); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
    return pg, re.search(r'session=(\d+)', pg.url).group(1)


def open_party(pg, s, name):
    pg.goto(f'{HOST}/ords/f?p={APP}:20:{s}'); pg.wait_for_load_state('networkidle')
    # both test parties carry TAG: the same search finds either (the list keeps earlier searches)
    pg.locator('.a-IRR-search-field').first.fill(TAG); pg.keyboard.press('Enter')
    pg.wait_for_timeout(2500)
    row = pg.locator('.a-IRR-table tr', has_text=name).first
    with pg.expect_navigation():
        row.locator('a').first.click()
    pg.wait_for_load_state('networkidle')


def errors(pg):
    m = re.search(r'ORA-\d{5}.{0,120}|error has occurred.{0,120}', pg.inner_text('body'))
    return m.group(0) if m else None


with sync_playwright() as p:
    b = p.chromium.launch(executable_path=os.environ.get('CHROME', '/opt/pw-browsers/chromium-1194/chrome-linux/chrome'),
                          args=['--no-sandbox'])
    pg, s = login(b, 'OFFICER1')
    # ---------------------------------------------------------- organisation: party card, registry check
    open_party(pg, s, ORG)
    card = pg.inner_text('#party_card')
    ok(f'party card from data: name, status badge, identity and contact fields ({errors(pg) or "no error"})',
       not errors(pg) and ORG in card and 'Approved' in card and 'Registration No.' in card
       and pg.locator('#party_card .kyc-badge').count() >= 1)
    ok('organisation: Registry Checks with Add, no ID Verifications',
       pg.locator('#party_registry_checks').count() == 1 and pg.locator('#party_id_verifications').count() == 0
       and pg.locator('button:has-text("Add Registry Check")').count() == 1)
    pg.click('button:has-text("Add Registry Check")')
    f = pg.frame_locator('iframe').first
    f.locator('#P27_REGISTRY_NAME').wait_for()
    ok('drawer: a new check is entered by hand',
       'MANUAL' in f.locator('#P27_SOURCE_CONTAINER').inner_text())
    f.locator('#P27_REGISTRY_NAME').fill('Ministry of Economy - Commercial Register')
    f.locator('#P27_EXTERNAL_REFERENCE').fill(f'CR-{TAG}')
    f.locator('#P27_REGISTRATION_STATUS').select_option('ACTIVE')
    f.locator('#P27_CHECK_RESULT').select_option('MATCH')
    f.locator('button:has-text("Create")').click()
    pg.locator('.ui-dialog iframe').wait_for(state='detached', timeout=30000); pg.wait_for_timeout(1500)
    r = db(f"select source || '|' || check_result || '|' || checked_by from xxcmp_party_registry_checks where party_id = {org}")
    ok(f'registry check saved: {r}', r == ['MANUAL|MATCH|OFFICER1'])
    ok('and listed with its result', 'Matches the party record' in pg.inner_text('#party_registry_checks'))

    # ---------------------------------------------------------- individual: identity document check
    open_party(pg, s, PER)
    ok('individual: ID Verifications with Add, no Registry Checks',
       pg.locator('#party_id_verifications').count() == 1 and pg.locator('#party_registry_checks').count() == 0)
    pg.click('button:has-text("Add ID Verification")')
    f = pg.frame_locator('iframe').first
    f.locator('#P26_DOCUMENT_NUMBER').wait_for()
    opts = f.locator('#P26_DOCUMENT_TYPE option').all_inner_texts()
    f.locator('#P26_DOCUMENT_TYPE').select_option(index=1)
    f.locator('#P26_DOCUMENT_NUMBER').fill(f'P-{TAG}')
    f.locator('#P26_VERIFICATION_METHOD').select_option('ORIGINAL_SEEN')
    f.locator('#P26_VERIFICATION_RESULT').select_option('VERIFIED')
    fr = [x for x in pg.frames if x != pg.main_frame][-1]
    fr.evaluate("apex.item('P26_EXPIRY_DATE').setValue('01-JAN-2020')")
    f.locator('button:has-text("Create")').click()
    pg.wait_for_timeout(2500)
    ok('an expired document cannot be recorded as verified (inline error)',
       'expired document' in fr.inner_text('body'))
    fr.evaluate("apex.item('P26_EXPIRY_DATE').setValue('')")
    f.locator('button:has-text("Create")').click()
    pg.locator('.ui-dialog iframe').wait_for(state='detached', timeout=30000); pg.wait_for_timeout(1500)
    r = db(f"select verification_method || '|' || verification_result || '|' || verified_by from xxcmp_party_id_verifications where party_id = {per}")
    ok(f'identity check saved: {r}', r == ['ORIGINAL_SEEN|VERIFIED|OFFICER1'])
    ok('and listed', f'P-{TAG}' in pg.inner_text('#party_id_verifications'))
    pg.close()

    # ---------------------------------------------------------- requester: their request's party, no status
    pg, s = login(b, 'REQ1')
    pg.goto(f'{HOST}/ords/f?p={APP}:200:{s}'); pg.wait_for_load_state('networkidle')
    link = pg.locator('.a-IRR-table td a', has_text=re.compile(r'^REQ-')).first
    if link.count():
        with pg.expect_navigation():
            link.click()
        pg.wait_for_load_state('networkidle')
        card = pg.inner_text('#party_card') if pg.locator('#party_card').count() else ''
        ok(f'requester: the request shows the party card without status, no checks ({errors(pg) or "no error"})',
           not errors(pg) and card and 'Status' not in card and pg.locator('#party_registry_checks').count() == 0
           and pg.locator('#party_id_verifications').count() == 0)
    else:
        ok('requester: a request to open', False)
    pg.close()
    b.close()
print(f'{sum(results)}/{len(results)} passed')
sys.exit(0 if all(results) else 1)
