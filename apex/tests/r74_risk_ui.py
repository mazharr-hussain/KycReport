"""Release 74 R16 / R24 in the browser: the Risk Model page (167) shows the factors, the FATF country lists and the
tiers; a manager changes a factor in the grid - it waits for approval, the impact on open cases is shown, and Submit
Changes for Approval creates the approval task; the case's Risk Assessment shows the score and how it is made up.
The change is put back at the end. Usage: r74_risk_ui.py [app-id]   (SQLCL env var: the SQLcl command)"""
import os, re, subprocess, sys
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
    pg = b.new_page(viewport={'width': 1400, 'height': 1000})
    pg.on('pageerror', lambda e: print('JS ERROR', str(e)[:200]))
    pg.goto(f'{HOST}/ords/r/xxcus/kyc/login')
    pg.fill('#P9999_USERNAME', user); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
    return pg, re.search(r'session=(\d+)', pg.url).group(1)


def errors(pg):
    m = re.search(r'ORA-\d{5}.{0,120}|error has occurred.{0,120}', pg.inner_text('body'))
    return m.group(0) if m else None


try:
    with sync_playwright() as p:
        b = p.chromium.launch(executable_path=os.environ.get('CHROME', '/opt/pw-browsers/chromium-1194/chrome-linux/chrome'),
                              args=['--no-sandbox'])
        pg, s = login(b, 'MGR1')
        pg.goto(f'{HOST}/ords/f?p={APP}:167:{s}'); pg.wait_for_load_state('networkidle')
        ok(f'Risk Model page: factors, country lists, tiers ({errors(pg) or "no error"})',
           not errors(pg) and pg.locator('#factors').count() == 1 and pg.locator('#countries').count() == 1
           and pg.locator('#tiers').count() == 1 and pg.locator('#countries .a-GV-row').count() >= 10)
        ok('no pending change: no impact region, no submit button',
           pg.locator('#impact').count() == 0 and pg.locator('button:has-text("Submit Changes for Approval")').count() == 0)
        # change the PEP factor points in the grid and save
        cell = pg.locator('#factors .a-GV-row', has_text='Politically exposed person').locator('td').nth(3)
        cell.dblclick(); pg.wait_for_timeout(500)
        pg.keyboard.press('Control+A'); pg.keyboard.type('45'); pg.keyboard.press('Tab'); pg.wait_for_timeout(500)
        pg.locator('#factors button.a-Button:has-text("Save"), #factors button:has-text("Save")').first.click()
        pg.wait_for_timeout(3000)
        r = db("select approval_status || '|' || points || '|' || approved_points from xxcmp_risk_factors where factor_code = 'PEP'")
        ok(f'the change waits for approval, the approved points stay: {r}', r == ['PENDING_APPROVAL|45|30'])
        pg.reload(); pg.wait_for_load_state('networkidle')
        ok('the impact of the change on open cases is shown, with Submit Changes for Approval',
           pg.locator('#impact').count() == 1 and pg.locator('button:has-text("Submit Changes for Approval")').count() == 1)
        with pg.expect_navigation():
            pg.click('button:has-text("Submit Changes for Approval")')
        pg.wait_for_load_state('networkidle')
        n = db("select count(*) from apex_tasks where task_def_static_id = 'CONFIG_CHANGE' and detail_pk = 'XXCMP_RISK_FACTOR_SET:KYC' and state_code in ('UNASSIGNED','ASSIGNED')")
        ok(f'submitted: approval task created ({errors(pg) or "no error"})', not errors(pg) and n == ['1'])
        pg.close()
        # the case shows its score and how it is made up
        pg, s = login(b, 'OFFICER1')
        cnum = db("select max(case_number) keep (dense_rank last order by case_id) from xxcmp_cases where case_status = 'INVESTIGATION' and upper(assigned_to) = 'OFFICER1'")[0]
        pg.goto(f'{HOST}/ords/f?p={APP}:210:{s}'); pg.wait_for_load_state('networkidle')
        pg.fill('#report_search_field', cnum); pg.keyboard.press('Enter'); pg.wait_for_timeout(2500)
        with pg.expect_navigation():
            pg.locator('#report td a', has_text=cnum).first.click()
        with pg.expect_navigation():
            pg.locator('#case_sections a', has_text='Risk Assessment').first.click()
        pg.wait_for_load_state('networkidle')
        title = pg.inner_text('#risk_score .t-Region-title') if pg.locator('#risk_score .t-Region-title').count() else ''
        ok(f'Risk Assessment shows the risk score and the suggested tier: "{title}"',
           pg.locator('#risk_score').count() == 1 and 'suggested tier' in title)
        b.close()
finally:
    # put the model back (the test change must not stay)
    db(f"""begin
      for t in (select task_id, initiator from apex_tasks where task_def_static_id = 'CONFIG_CHANGE'
                  and detail_pk = 'XXCMP_RISK_FACTOR_SET:KYC' and state_code in ('UNASSIGNED','ASSIGNED')) loop
        begin   -- the initiator cancels it
          apex_session.create_session({APP}, 1, t.initiator);
          apex_human_task.cancel_task(t.task_id);
        exception when others then null; end;
      end loop;
      if apex_application.g_instance is not null then apex_session.delete_session; end if;
      xxfnd_util_pkg.set_install_mode(true);
      update xxcmp_risk_factors set points = approved_points, approval_status = 'APPROVED'
       where factor_code = 'PEP' and (approval_status <> 'APPROVED' or points <> approved_points);
      xxfnd_util_pkg.set_install_mode(false);
      commit;
    end;
    /
    select 1 from dual""")
print(f'{sum(results)}/{len(results)} passed')
sys.exit(0 if all(results) else 1)
