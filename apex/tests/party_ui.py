"""Party feature in the browser (release 25): Parties list (sorted by number, Excel download); the party wizard
(24 Party Information -> 25 Party Details -> 21 Review) from Edit and Create Party; read-only fields hidden while
editing; the similar-parties dialog; contact person and new owner / officer from the common Global Page regions;
field order and labels by party type; the read-only Party view with Back / Edit at the top and the bottom;
Compliance merges a duplicate into an existing party.
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


def answer_matches(pg, frame=None, none=True, wait=2500):
    """The similar-parties dialog (Global Page): click one of its two buttons when it opens."""
    pg.wait_for_timeout(wait)
    for where in ([frame] if frame else []) + [pg]:
        btn = where.locator('.ui-dialog button:has-text("%s")' % ('Confirmed' if none else 'possible match exists'))
        if btn.count() and btn.first.is_visible():
            btn.first.click()
            return True
    return False


def rows_order(pg, ids):
    return [pg.evaluate("(id) => { var e = document.getElementById(id); return e ? e.getBoundingClientRect().top : -1; }", i) for i in ids]


with sync_playwright() as p:
    b = p.chromium.launch(executable_path=os.environ.get('CHROME', '/opt/pw-browsers/chromium-1194/chrome-linux/chrome'),
                          args=['--no-sandbox'])
    pg = b.new_page(viewport={'width': 1400, 'height': 1000})
    pg.on('pageerror', lambda e: print('JS ERROR', str(e)[:200]))
    pg.goto(f'{HOST}/ords/r/xxcus/kyc/login')
    pg.fill('#P9999_USERNAME', 'OFFICER1'); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
    s = re.search(r'session=(\d+)', pg.url).group(1)

    # ---------------------------------------------------------- list
    pg.goto(f'{HOST}/ords/f?p={APP}:20:{s}'); pg.wait_for_load_state('networkidle')
    nums = [t.strip() for t in pg.locator('.a-IRR-table tr td:first-child').all_inner_texts()][:5]
    ok(f'Parties list sorted by party number: {nums}', len(nums) > 1 and nums == sorted(nums))
    pg.click('.a-IRR-actions button, button:has-text("Actions")'); pg.wait_for_timeout(500)
    pg.locator('button:has-text("Download"), a:has-text("Download")').first.click(); pg.wait_for_timeout(1000)
    ok('Excel download offered', pg.locator('.a-IRR-dialog--download, .ui-dialog').filter(has_text='Excel').count() > 0
       or 'Excel' in pg.inner_text('body'))
    pg.keyboard.press('Escape')
    pg.locator('.a-IRR-search-field').first.fill(TAG); pg.keyboard.press('Enter')
    pg.wait_for_load_state('networkidle'); pg.wait_for_timeout(1500)
    row = pg.locator(f'.a-IRR-table tr:has-text("{KEEP}")')
    ok('Parties list has an Edit link', row.locator('a:has-text("Edit")').count() == 1)

    # ---------------------------------------------------------- view: read only, Back / Edit top and bottom
    with pg.expect_navigation(): row.locator('a').first.click()
    pg.wait_for_load_state('networkidle')
    ok('view: the party details and the detail regions, read only (no Add buttons)',
       KEEP in pg.inner_text('#party_card') and pg.locator('#party_contacts').count() == 1 and pg.locator('#party_owners').count() == 1
       and all(pg.locator(f'button:has-text("{x}")').count() == 0 for x in ('Add Contact', 'Add Owner', 'Add Document')))
    ok('view: Back and Edit at the top and the bottom',
       pg.locator('button', has_text=re.compile(r'^\s*Edit\s*$')).count() == 2 and pg.locator('button:has-text("Back")').count() == 2)

    # ---------------------------------------------------------- edit: step 1 Party Information (one click)
    with pg.expect_navigation(): pg.locator('button', has_text=re.compile(r'^\s*Edit\s*$')).first.click()
    pg.wait_for_load_state('networkidle')
    ok('Edit opens step 1 editable, read-only fields hidden',
       '/party-details' in pg.url or 'p=134:24' in pg.url or pg.locator('#P0_PARTY_NAME').count() == 1)
    ok('step 1: form editable; Party Number / Status / Next KYC / Last Verified hidden',
       pg.get_attribute('#P0_PARTY_NAME', 'aria-readonly') != 'true'
       and all(pg.locator(f'#P0_PARTY_{x}').count() == 0 for x in ('STATUS', 'NEXT_KYC_DATE', 'LAST_VERIFIED_DATE', 'NUMBER'))
       and pg.locator('#P0_PARTY_MATCH_ACK_CONTAINER .a-Switch').count() == 0)
    top = rows_order(pg, ['P0_PARTY_ENTITY_TYPE', 'P0_PARTY_NAME'])
    ok(f'organisation: Entity Type before Name {top}', top[0] < top[1])
    pg.fill('#P0_PARTY_EMAIL', 'info@meridian.example'); pg.fill('#P0_PARTY_PHONE', '+971 4 222 3333')
    pg.fill('#P0_PARTY_WEBSITE', 'https://meridian.example'); pg.fill('#P0_PARTY_FAX', '+971 4 222 3334')
    pg.locator('button', has_text=re.compile(r'^\s*Next\s*$')).first.click()
    asked = answer_matches(pg)
    ok('similar parties: the dialog asks before saving', asked)
    pg.wait_for_load_state('networkidle'); pg.wait_for_timeout(1000)
    r = db(f"select email || '|' || website || '|' || fax from xxcmp_parties where party_id = {keep}")
    ok(f'step 1 saved the party: {r}', r == ['info@meridian.example|https://meridian.example|+971 4 222 3334'])

    # ---------------------------------------------------------- step 2 Party Details: contact person, new owner
    ok('step 2: Add Contact Person / Owner / Document', all(pg.locator(f'button:has-text("{x}")').count() == 1
                                                         for x in ('Add Contact Person', 'Add Owner', 'Add Document')))
    pg.click('button:has-text("Add Contact Person")')
    f = pg.frame_locator('iframe').first
    f.locator('#P22_CONTACT_NAME').wait_for()
    f.locator('#P22_CONTACT_NAME').fill('Omar Finance'); f.locator('#P22_JOB_TITLE').fill('CFO')
    f.locator('#P22_EMAIL').fill('omar@meridian.example')
    f.locator('button:has-text("Create")').click()
    pg.locator('.ui-dialog iframe').wait_for(state='detached', timeout=30000); pg.wait_for_timeout(1000)
    ok('contact person saved and listed', 'Omar Finance' in pg.inner_text('#party_contacts'))
    pg.click('button:has-text("Add Owner")')
    f = pg.frame_locator('iframe').first
    f.locator('#P23_OWNER_SELECTION').wait_for()
    f.locator('#P23_OWNER_SELECTION input[value=NEW]').check(); pg.wait_for_timeout(500)
    f.locator('#P0_PARTY_TYPE input[value=PERSON]').check(); pg.wait_for_timeout(500)
    fr = [x for x in pg.frames if x != pg.main_frame][-1]
    top = rows_order(fr, ['P0_PARTY_ENTITY_TYPE', 'P0_PARTY_REGISTRATION_NUMBER'])
    ok(f'individual: ID Type before ID Number {top}', top[0] < top[1] and fr.inner_text('#P0_PARTY_ENTITY_TYPE_LABEL') == 'ID Type')
    f.locator('#P0_PARTY_NAME').fill(f'Layla Owner {TAG}')
    f.locator('#P0_PARTY_JURISDICTION').select_option('AE')
    f.locator('#P0_PARTY_PHONE').fill('+971 50 555')
    f.locator('#P23_RELATIONSHIP_TYPE').select_option('SHAREHOLDER')
    fr.evaluate("apex.item('P23_START_DATE').setValue('01-JAN-2020')")
    f.locator('#P23_OWNERSHIP_PERCENTAGE').fill('25')
    f.locator('button:has-text("Create")').click()
    answer_matches(pg, f)
    pg.locator('.ui-dialog iframe').wait_for(state='detached', timeout=30000); pg.wait_for_timeout(1000)
    ok('new owner created as a party, linked and listed', f'Layla Owner {TAG}' in pg.inner_text('#party_owners'))

    # ---------------------------------------------------------- step 3 Review = the Party page
    with pg.expect_navigation(): pg.locator('button', has_text=re.compile(r'^\s*Next\s*$')).first.click()
    pg.wait_for_load_state('networkidle')
    ok('review: wizard progress, everything shown, Previous / Done',
       pg.locator('#wizard').count() == 1 and 'Omar Finance' in pg.inner_text('#party_contacts')
       and pg.locator('button:has-text("Done")').count() == 2)
    with pg.expect_navigation(): pg.locator('button:has-text("Done")').first.click()
    pg.wait_for_load_state('networkidle')
    ok('Done: the read-only view', pg.locator('#wizard').count() == 0 and pg.locator('button:has-text("Back")').count() == 2)

    # ---------------------------------------------------------- Create Party: labels by type
    pg.goto(f'{HOST}/ords/f?p={APP}:20:{s}'); pg.wait_for_load_state('networkidle')
    with pg.expect_navigation(): pg.click('button:has-text("Create Party")')
    pg.wait_for_load_state('networkidle')
    ok('organisation labels', pg.inner_text('#P0_PARTY_REGISTRATION_NUMBER_LABEL') == 'Registration No.')
    pg.locator('#P0_PARTY_TYPE input[value=PERSON]').check(); pg.wait_for_timeout(800)
    ok('individual labels', pg.inner_text('#P0_PARTY_REGISTRATION_NUMBER_LABEL') == 'ID Number'
       and pg.inner_text('#P0_PARTY_JURISDICTION_LABEL') == 'Nationality')
    pg.fill('#P0_PARTY_NAME', f'Created In Wizard {TAG}')
    pg.select_option('#P0_PARTY_JURISDICTION', 'AE')
    pg.fill('#P0_PARTY_EMAIL', 'new@wizard.example')
    pg.locator('button', has_text=re.compile(r'^\s*Next\s*$')).first.click()
    answer_matches(pg)
    pg.wait_for_load_state('networkidle'); pg.wait_for_timeout(1000)
    ok('Create Party: step 1 saved the party and opened step 2',
       db(f"select count(*) from xxcmp_parties where party_name = 'Created In Wizard {TAG}'") == ['1']
       and pg.locator('button:has-text("Add Contact Person")').count() == 1)

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
    ok('the page now shows the kept party', KEEP in pg.inner_text('#party_card'))
    b.close()
print(f'{sum(results)}/{len(results)} passed')
sys.exit(0 if all(results) else 1)
