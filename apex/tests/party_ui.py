"""Party feature in the browser (pages 20-24 and the common party region on the Global Page): Edit link on Parties;
the party opens read only (common region, no Add buttons) and Edit makes the common form editable in one click (Save);
a contact person in the drawer; a new owner / officer entered in the common region, with the ownership % rule;
Create Party with labels that follow the party type; Compliance merges a duplicate into an existing party.
Usage: party_ui.py [app-id]   (SQLCL env var: the SQLcl command, default 'sql'; connection name kyc_local)"""
import os, random, re, string, subprocess, sys
from playwright.sync_api import sync_playwright

APP = sys.argv[1] if len(sys.argv) > 1 else '134'
HOST = 'http://localhost:8080'
SQLCL = os.environ.get('SQLCL', 'sql')
TAG = ''.join(random.choice(string.ascii_uppercase) for _ in range(8))
KEEP = f'Meridian Trading {TAG} LLC'
DUP = f'Meridian Tradng {TAG} LLC'
results = []


def ok(label, cond):
    results.append(bool(cond))
    print(('PASS ' if cond else 'FAIL ') + label)


def db(sql):
    out = subprocess.run([SQLCL, '-S', '-name', 'kyc_local'], input=f'set heading off feedback off pages 0\n{sql};\nexit\n',
                         capture_output=True, text=True).stdout
    return [l.strip() for l in out.splitlines() if l.strip() and 'JAVA_TOOL' not in l]


db(f"""begin
  insert into xxcmp_parties (party_type, party_name, registration_number, jurisdiction, entity_type)
  values ('ORGANIZATION', '{KEEP}', 'MT-{TAG}', 'AE', 'LLC');
  insert into xxcmp_parties (party_type, party_name, registration_number, jurisdiction, entity_type)
  values ('ORGANIZATION', '{DUP}', 'MT2-{TAG}', 'AE', 'LLC');
  commit;
end;
/
select 1 from dual""")
keep = db(f"select party_id from xxcmp_parties where party_name = '{KEEP}'")[0]
dup = db(f"select party_id from xxcmp_parties where party_name = '{DUP}'")[0]

with sync_playwright() as p:
    b = p.chromium.launch(executable_path=os.environ.get('CHROME', '/opt/pw-browsers/chromium-1194/chrome-linux/chrome'),
                          args=['--no-sandbox'])
    pg = b.new_page(viewport={'width': 1400, 'height': 1000})
    pg.on('pageerror', lambda e: print('JS ERROR', str(e)[:200]))
    pg.goto(f'{HOST}/ords/r/xxcus/kyc/login')
    pg.fill('#P9999_USERNAME', 'OFFICER1'); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
    s = re.search(r'session=(\d+)', pg.url).group(1)

    # ---------------------------------------------------------- list: Edit link
    pg.goto(f'{HOST}/ords/f?p={APP}:20:{s}'); pg.wait_for_load_state('networkidle')
    pg.locator('.a-IRR-search-field').first.fill(TAG); pg.keyboard.press('Enter')
    pg.wait_for_load_state('networkidle'); pg.wait_for_timeout(1500)
    row = pg.locator(f'.a-IRR-table tr:has-text("{KEEP}")')
    ok('Parties list has an Edit link', row.locator('a:has-text("Edit")').count() == 1)

    # ---------------------------------------------------------- view is read only
    with pg.expect_navigation(): row.locator('a').first.click()
    pg.wait_for_load_state('networkidle')
    body = pg.inner_text('body')
    ok('view: no Save, no Raise RFI', pg.locator('button:has-text("Save")').count() == 0 and 'Raise RFI' not in body)
    ok('view: no Add Contact / Owner / Attachment buttons',
       all(pg.locator(f'button:has-text("{x}")').count() == 0 for x in ('Add Contact', 'Add Owner', 'Add Attachment')))
    ok('view: the common party region is read only', pg.locator('#P0_PARTY_ENABLED_FLAG_CONTAINER .a-Switch').count() == 0
       and pg.get_attribute('#P0_PARTY_NAME', 'aria-readonly') == 'true')
    ok('view: Edit button at the top and the bottom; read-only fields shown',
       pg.locator('button', has_text=re.compile(r'^\s*Edit\s*$')).count() == 2 and pg.locator('#P0_PARTY_STATUS').count() == 1)

    # ---------------------------------------------------------- edit: one click, the form is editable
    with pg.expect_navigation(): pg.locator('button', has_text=re.compile(r'^\s*Edit\s*$')).first.click()
    pg.wait_for_load_state('networkidle')
    ok('edit: editable form, Save top and bottom, no Edit Details, read-only fields hidden, Add buttons',
       pg.get_attribute('#P0_PARTY_NAME', 'aria-readonly') != 'true'
       and pg.locator('button', has_text=re.compile(r'^\s*Save\s*$')).count() == 2
       and pg.locator('button:has-text("Edit Details")').count() == 0
       and all(pg.locator(f'#P0_PARTY_{x}').count() == 0 for x in ('STATUS', 'NEXT_KYC_DATE', 'LAST_VERIFIED_DATE', 'NUMBER'))
       and pg.locator('button:has-text("Add Contact Person")').count() == 1)
    pg.fill('#P0_PARTY_EMAIL', 'info@meridian.example'); pg.fill('#P0_PARTY_PHONE', '+971 4 222 3333')
    pg.fill('#P0_PARTY_WEBSITE', 'https://meridian.example'); pg.fill('#P0_PARTY_FAX', '+971 4 222 3334')
    pg.locator('button', has_text=re.compile(r'^\s*Save\s*$')).first.click()
    pg.wait_for_load_state('networkidle'); pg.wait_for_timeout(1500)
    if 'Similar parties exist' in pg.inner_text('body'):
        ok('similar parties: the save asks to confirm none of the Possible Matches is this party',
           pg.locator('#possible_matches').count() == 1)
        pg.evaluate("apex.item('P0_PARTY_MATCH_ACK').setValue('Y')")
        pg.locator('button', has_text=re.compile(r'^\s*Save\s*$')).first.click()
        pg.wait_for_load_state('networkidle'); pg.wait_for_timeout(1500)
    r = db(f"select email || '|' || website || '|' || fax from xxcmp_parties where party_id = {keep}")
    ok(f'main contact details saved on the party: {r}', r == ['info@meridian.example|https://meridian.example|+971 4 222 3334'])
    ok('the Party page shows the saved details', pg.evaluate("apex.item('P0_PARTY_EMAIL').getValue()") == 'info@meridian.example')

    # ---------------------------------------------------------- contact person drawer (still in edit mode)
    pg.click('button:has-text("Add Contact Person")')
    f = pg.frame_locator('iframe').first
    f.locator('#P22_CONTACT_NAME').wait_for()
    f.locator('#P22_CONTACT_NAME').fill('Omar Finance'); f.locator('#P22_JOB_TITLE').fill('CFO')
    f.locator('#P22_EMAIL').fill('omar@meridian.example')
    f.locator('button:has-text("Create")').click()
    pg.locator('.ui-dialog iframe').wait_for(state='detached', timeout=30000)
    r = db(f"select contact_name || '|' || job_title || '|' || email from xxcmp_party_contacts where party_id = {keep}")
    ok(f'contact person saved: {r}', r == ['Omar Finance|CFO|omar@meridian.example'])

    # ---------------------------------------------------------- new owner / officer
    pg.click('button:has-text("Add Owner")')
    f = pg.frame_locator('iframe').first
    f.locator('#P23_OWNER_SELECTION').wait_for()
    f.locator('#P23_OWNER_SELECTION input[value=NEW]').check(); pg.wait_for_timeout(500)
    ok('new owner: the common party form appears, the party search hides',
       f.locator('#P0_PARTY_NAME').is_visible() and not f.locator('#P23_SUBJECT_PARTY_ID').is_visible())
    f.locator('#P0_PARTY_TYPE input[value=PERSON]').check(); pg.wait_for_timeout(500)
    f.locator('#P0_PARTY_NAME').fill(f'Layla Owner {TAG}')
    f.locator('#P0_PARTY_JURISDICTION').select_option('AE')
    f.locator('#P0_PARTY_PHONE').fill('+971 50 555')
    f.locator('#P23_RELATIONSHIP_TYPE').select_option('SHAREHOLDER')
    fr = [x for x in pg.frames if x != pg.main_frame][-1]
    fr.evaluate("apex.item('P23_START_DATE').setValue('01-JAN-2020')")
    f.locator('button:has-text("Create")').click(); pg.wait_for_timeout(2500)
    ok('a shareholder without ownership % is refused', 'ownership %' in fr.inner_text('body'))
    f.locator('#P23_OWNERSHIP_PERCENTAGE').fill('25')
    if 'Similar parties exist' in fr.inner_text('body'):     # earlier runs left similar owners: confirm none is this party
        fr.evaluate("apex.item('P0_PARTY_MATCH_ACK').setValue('Y')")
    f.locator('button:has-text("Create")').click()
    pg.locator('.ui-dialog iframe').wait_for(state='detached', timeout=30000)
    r = db(f"""select count(*) from xxcmp_party_relationships r join xxcmp_parties o on o.party_id = r.subject_party_id
                where r.object_party_id = {keep} and o.party_name = 'Layla Owner {TAG}' and o.party_type = 'PERSON'""")
    ok('a new owner is created as a party and linked', r == ['1'])

    # ---------------------------------------------------------- create a party in the common dialog
    pg.goto(f'{HOST}/ords/f?p={APP}:20:{s}'); pg.wait_for_load_state('networkidle')
    pg.click('button:has-text("Create Party")')
    f = pg.frame_locator('iframe').first
    f.locator('#P0_PARTY_NAME').wait_for()
    fr = [x for x in pg.frames if x != pg.main_frame][-1]
    ok('organisation labels', fr.inner_text('#P0_PARTY_REGISTRATION_NUMBER_LABEL') == 'Registration No.')
    f.locator('#P0_PARTY_TYPE input[value=PERSON]').check(); pg.wait_for_timeout(800)
    ok('individual labels', fr.inner_text('#P0_PARTY_REGISTRATION_NUMBER_LABEL') == 'ID Number'
       and fr.inner_text('#P0_PARTY_JURISDICTION_LABEL') == 'Nationality')
    f.locator('#P0_PARTY_NAME').fill(f'Created In Dialog {TAG}')
    f.locator('#P0_PARTY_JURISDICTION').select_option('AE')
    f.locator('#P0_PARTY_EMAIL').fill('new@dialog.example')
    fr.evaluate("apex.item('P0_PARTY_MATCH_ACK').setValue('Y')")   # earlier runs left similar parties
    with pg.expect_navigation(timeout=60000):
        f.locator('button:has-text("Create")').click()
    pg.wait_for_load_state('networkidle')
    ok('Create Party (common dialog) opens the new party',
       pg.evaluate("apex.item('P0_PARTY_NAME').getValue()") == f'Created In Dialog {TAG}')

    # ---------------------------------------------------------- merge a duplicate
    pg.goto(f'{HOST}/ords/f?p={APP}:20:{s}'); pg.wait_for_load_state('networkidle')
    pg.locator('.a-IRR-search-field').first.fill(TAG); pg.keyboard.press('Enter')
    pg.wait_for_load_state('networkidle'); pg.wait_for_timeout(1500)
    with pg.expect_navigation(): pg.locator(f'.a-IRR-table tr:has-text("{DUP}") a').first.click()
    pg.wait_for_load_state('networkidle')
    link = pg.locator(f'#matches tr:has-text("{KEEP}") a.kyc-merge-into')
    ok('the duplicate lists the similar party with Merge into this party', link.count() == 1)
    link.click()
    with pg.expect_navigation():
        pg.locator('.ui-dialog .js-confirmBtn, .ui-dialog button:has-text("OK")').first.click()
    pg.wait_for_load_state('networkidle')
    r = db(f"select enabled_flag || '|' || merged_into_party_id from xxcmp_parties where party_id = {dup}")
    ok(f'merged: duplicate disabled and linked to the kept party {r}', r == [f'N|{keep}'])
    ok('the page now shows the kept party', pg.evaluate("apex.item('P0_PARTY_NAME').getValue()") == KEEP)
    b.close()
print(f'{sum(results)}/{len(results)} passed')
sys.exit(0 if all(results) else 1)
