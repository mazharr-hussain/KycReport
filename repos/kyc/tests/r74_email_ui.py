"""Release 74 R27 in the browser: on the case's Notes and RFIs section the officer sends an e-mail to a contact person
of the party and records the reply received; both are listed with the case.
Release 89: KYC's E-mail page (34) is gone - the case's buttons open COMMON's E-mail page (46), which goes back to
COMMON's Communications page (45) of the case.
Usage: r74_email_ui.py [app-id]   (SQLCL env var: the SQLcl command; connection name kyc_local)"""
import os, random, re, string, subprocess, sys
from playwright.sync_api import sync_playwright

APP = sys.argv[1] if len(sys.argv) > 1 else '134'
HOST = 'http://localhost:8080'
SQLCL = os.environ.get('SQLCL', 'sql')
TAG = ''.join(random.choice(string.ascii_uppercase) for _ in range(6))
results = []


def ok(label, cond):
    results.append(bool(cond))
    print(('PASS ' if cond else 'FAIL ') + label)


def db(sql):
    out = subprocess.run([SQLCL, '-S', '-name', 'kyc_local'], input=f'set heading off feedback off pages 0\n{sql};\nexit\n',
                         capture_output=True, text=True).stdout
    return [l.strip() for l in out.splitlines() if l.strip() and 'JAVA_TOOL' not in l]


row = db("""select case_number || '|' || case_id || '|' || party_id from (select c.case_number, c.case_id, c.party_id from xxcmp_cases c
             where c.case_status = 'INVESTIGATION' and upper(c.assigned_to) = 'OFFICER1' order by c.case_id desc) where rownum = 1""")
cnum, case_id, party_id = row[0].split('|')
db(f"""begin
  xxfnd_util_pkg.set_install_mode(true);
  insert into xxcmp_party_contacts (party_id, contact_name, email, enabled_flag, primary_flag)
  values ({party_id}, 'Mail Contact {TAG}', 'mail.{TAG.lower()}@example.com', 'Y', 'N');
  xxfnd_util_pkg.set_install_mode(false);
  commit;
end;
/
select 1 from dual""")

with sync_playwright() as p:
    b = p.chromium.launch(executable_path=os.environ.get('CHROME', '/opt/pw-browsers/chromium-1194/chrome-linux/chrome'),
                          args=['--no-sandbox'])
    pg = b.new_page()
    pg.on('pageerror', lambda e: print('JS ERROR', str(e)[:200]))
    pg.goto(f'{HOST}/ords/r/xxcus/kyc/login')
    pg.fill('#P9999_USERNAME', 'OFFICER1'); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
    s = re.search(r'session=(\d+)', pg.url).group(1)
    pg.goto(f'{HOST}/ords/f?p={APP}:210:{s}'); pg.wait_for_load_state('networkidle')
    pg.fill('#report_search_field', cnum); pg.keyboard.press('Enter'); pg.wait_for_timeout(2500)
    with pg.expect_navigation():
        pg.locator('#report td a', has_text=cnum).first.click()
    pg.wait_for_load_state('networkidle')
    with pg.expect_navigation():
        pg.locator('#case_sections a', has_text='Notes').first.click()
    pg.wait_for_load_state('networkidle')
    ok('Notes and RFIs shows E-mails with Send E-mail and Record Received E-mail',
       pg.locator('#emails').count() == 1 and pg.locator('button:has-text("Send E-mail")').count() == 1
       and pg.locator('button:has-text("Record Received E-mail")').count() == 1)
    case_url = pg.url
    # send (COMMON page 46)
    with pg.expect_navigation():
        pg.click('button:has-text("Send E-mail")')
    pg.wait_for_load_state('networkidle')
    ok(f'Send E-mail opens COMMON\'s E-mail page in the same session: {pg.url.split("?")[0][-40:]}',
       '/common/' in pg.url.lower() and pg.locator('#P46_TO').count() == 1)
    pg.fill('#P46_TO', f'mail.{TAG.lower()}@example.com')
    pg.fill('#P46_SUBJECT', f'Documents needed {TAG}')
    pg.fill('#P46_BODY', 'Please send the renewed trade licence.')
    with pg.expect_navigation():
        pg.click('button:has-text("Send")')
    pg.wait_for_load_state('networkidle')
    r = db(f"select direction || '|' || application_code || '|' || entity_name || '|' || pk1_value || '|' || to_address "
           f"from xxfnd_communications where subject = 'Documents needed {TAG}'")
    ok(f'e-mail sent and kept with the case: {r}',
       r and r[0].startswith(f'OUT|KYC|XXCMP_CASES|{case_id}|') and r[0].endswith(f'mail.{TAG.lower()}@example.com'))
    ok('COMMON goes back to the Communications page of the case', pg.locator('body', has_text=f'Documents needed {TAG}').count() == 1)
    # record the reply
    pg.goto(case_url); pg.wait_for_load_state('networkidle')
    with pg.expect_navigation():
        pg.click('button:has-text("Record Received E-mail")')
    pg.wait_for_load_state('networkidle')
    pg.fill('#P46_FROM', f'mail.{TAG.lower()}@example.com')
    pg.fill('#P46_SUBJECT', f'RE: Documents needed {TAG}')
    pg.fill('#P46_BODY', 'Attached, regards.')
    with pg.expect_navigation():
        pg.click('button:has-text("Save")')
    pg.wait_for_load_state('networkidle')
    r = db(f"select direction || '|' || status || '|' || source from xxfnd_communications where subject = 'RE: Documents needed {TAG}'")
    ok(f'reply recorded: {r}', r == ['IN|RECEIVED|MANUAL'])
    pg.goto(case_url); pg.wait_for_load_state('networkidle')
    txt = pg.inner_text('#emails')
    ok('both listed with the case', f'Documents needed {TAG}' in txt and 'Received' in txt)
    b.close()
print(f'{sum(results)}/{len(results)} passed')
sys.exit(0 if all(results) else 1)
