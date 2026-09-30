"""Party feature in the browser (pages 20-23): Edit link on Parties; the party opens read only (no Save, no Raise RFI,
no Add buttons, no Enabled switch) and Edit changes it (main email / phone / website / fax); a contact person in
the drawer; a new owner / officer created as a party; Compliance merges a duplicate into an existing party.
Usage: party_ui.py [app-id]   (SQLCL env var: the SQLcl command, default 'sql'; connection name kyc_local)"""
import os, random, re, string, subprocess, sys
from playwright.sync_api import sync_playwright

APP = sys.argv[1] if len(sys.argv) > 1 else '101'
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
    ok('view: Enabled is read only (no switch)', pg.locator('#P21_ENABLED_FLAG_CONTAINER .a-Switch').count() == 0
       and pg.get_attribute('#P21_ENABLED_FLAG', 'aria-readonly') == 'true')
    ok('view: Edit button', pg.locator('button:has-text("Edit")').count() == 1)

    # ---------------------------------------------------------- edit: main contact details
    with pg.expect_navigation(): pg.click('button:has-text("Edit")')
    pg.wait_for_load_state('networkidle')
    ok('edit: Save and the Add buttons', pg.locator('button:has-text("Save")').count() == 1
       and pg.locator('button:has-text("Add Contact Person")').count() == 1)
    pg.fill('#P21_EMAIL', 'info@meridian.example'); pg.fill('#P21_PHONE', '+971 4 222 3333')
    pg.fill('#P21_WEBSITE', 'https://meridian.example'); pg.fill('#P21_FAX', '+971 4 222 3334')
    with pg.expect_navigation(): pg.click('button:has-text("Save")')
    pg.wait_for_load_state('networkidle')
    r = db(f"select email || '|' || website || '|' || fax from xxcmp_parties where party_id = {keep}")
    ok(f'main contact details saved on the party: {r}', r == ['info@meridian.example|https://meridian.example|+971 4 222 3334'])
    ok('after Save the party is shown read only again', pg.locator('button:has-text("Save")').count() == 0)

    # ---------------------------------------------------------- contact person drawer
    with pg.expect_navigation(): pg.click('button:has-text("Edit")')
    pg.wait_for_load_state('networkidle')
    pg.click('button:has-text("Add Contact Person")')
    f = pg.frame_locator('iframe').first
    f.locator('#P22_CONTACT_NAME').wait_for()
    f.locator('#P22_CONTACT_NAME').fill('Omar Finance'); f.locator('#P22_JOB_TITLE').fill('CFO')
    f.locator('#P22_EMAIL').fill('omar@meridian.example')
    f.locator('button:has-text("Create")').click()
    pg.locator('.ui-dialog iframe').wait_for(state='detached', timeout=30000)
    r = db(f"select contact_type || '|' || contact_name || '|' || job_title || '|' || email from xxcmp_party_contacts where party_id = {keep}")
    ok(f'contact person saved: {r}', r == ['PERSON|Omar Finance|CFO|omar@meridian.example'])

    # ---------------------------------------------------------- new owner / officer
    pg.click('button:has-text("Add Owner")')
    f = pg.frame_locator('iframe').first
    f.locator('#P23_OWNER_SELECTION').wait_for()
    f.locator('#P23_OWNER_SELECTION input[value=NEW]').check(); pg.wait_for_timeout(500)
    ok('new owner: the party fields appear, the party search hides',
       f.locator('#P23_NEW_PARTY_NAME').is_visible() and not f.locator('#P23_SUBJECT_PARTY_ID').is_visible())
    f.locator('#P23_NEW_PARTY_NAME').fill(f'Layla Owner {TAG}')
    f.locator('#P23_RELATIONSHIP_TYPE').select_option(index=1)
    f.locator('#P23_OWNERSHIP_PERCENTAGE').fill('25')
    [x for x in pg.frames if x != pg.main_frame][-1].evaluate("apex.item('P23_START_DATE').setValue('01-JAN-2020')")
    f.locator('button:has-text("Create")').click()
    pg.locator('.ui-dialog iframe').wait_for(state='detached', timeout=30000)
    r = db(f"""select count(*) from xxcmp_party_relationships r join xxcmp_parties o on o.party_id = r.subject_party_id
                where r.object_party_id = {keep} and o.party_name = 'Layla Owner {TAG}' and o.party_type = 'PERSON'""")
    ok('a new owner is created as a party and linked', r == ['1'])

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
    ok('the page now shows the kept party', pg.evaluate("apex.item('P21_PARTY_NAME').getValue()") == KEEP)
    b.close()
print(f'{sum(results)}/{len(results)} passed')
sys.exit(0 if all(results) else 1)
