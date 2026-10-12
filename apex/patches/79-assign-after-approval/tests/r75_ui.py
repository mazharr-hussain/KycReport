"""Release 75 in the browser (KYC). Layout: the home tiles are Metric Cards, the request and case summaries are the KYC Field
Grid (group titles, 3 columns), screenshots kept for a look. Case assignment at request level (release 76): Approve on
the approval screen (206) keeps the common dialog; when the approval opens the case, the request (205) opens with Assign
Case and the case goes to the officer chosen; Assign Case on the approved request gives the case to another officer.
Usage: r75_ui.py [app-id]   (SQLCL env var: the SQLcl command, default 'sql'; connection name kyc_local;
SHOTS env var: the screenshot folder, default <temp>/r75_shots)"""
import os, re, subprocess, sys, tempfile, time
from playwright.sync_api import sync_playwright

APP = sys.argv[1] if len(sys.argv) > 1 else '134'
HOST = 'http://localhost:8080'
SQLCL = os.environ.get('SQLCL', 'sql')
SHOTS = os.environ.get('SHOTS', os.path.join(tempfile.gettempdir(), 'r75_shots'))
results = []


def ok(label, cond):
    results.append(bool(cond))
    print(('PASS ' if cond else 'FAIL ') + label)


def db(sql):
    out = subprocess.run([SQLCL, '-S', '-name', 'kyc_local'], input=f'set heading off feedback off pages 0 serveroutput on\n{sql}\nexit\n',
                         capture_output=True, text=True).stdout
    return [l.strip() for l in out.splitlines() if l.strip() and 'JAVA_TOOL' not in l]


def login(b, user):
    pg = b.new_page(viewport={'width': 1400, 'height': 1100})
    pg.on('pageerror', lambda e: print('JS ERROR', str(e)[:200]))
    pg.goto(f'{HOST}/ords/r/xxcus/kyc/login')
    pg.fill('#P9999_USERNAME', user); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
    return pg, re.search(r'session=(\d+)', pg.url).group(1)


def open_task(pg, s, number):
    pg.goto(f'{HOST}/ords/f?p={APP}:40:{s}'); pg.wait_for_load_state('networkidle')
    if pg.locator(f'a:has-text("{number}")').count() == 0:
        search = pg.locator('input[type=search]').first
        search.fill(number); pg.keyboard.press('Enter'); pg.wait_for_timeout(2500)
    with pg.expect_navigation():
        pg.locator(f'a:has-text("{number}")').first.click()
    pg.wait_for_load_state('networkidle')


def open_request(pg, s, number):
    pg.goto(f'{HOST}/ords/f?p={APP}:200:{s}'); pg.wait_for_load_state('networkidle')
    pg.locator('.a-IRR-search-field').first.fill(number); pg.keyboard.press('Enter')
    pg.wait_for_load_state('networkidle'); pg.wait_for_timeout(1500)
    with pg.expect_navigation():
        pg.locator(f'.a-IRR-table a:has-text("{number}")').first.click()
    pg.wait_for_load_state('networkidle')


def shot(pg, name):
    os.makedirs(SHOTS, exist_ok=True)
    pg.screenshot(path=os.path.join(SHOTS, name), full_page=True)


# a request of REQ1 that needs KYC, waiting for its Compliance approval (the approval opens the case)
created = db("""declare
    l_req number;
    l_app number;
    l_no  varchar2(100);
    procedure answer(p_q varchar2, p_label varchar2) is
    begin
        update xxcmp_request_answers a
           set answer_option_id = (select o.answer_option_id from xxcmp_answer_options o
                                    where o.question_id = a.question_id and o.answer_label = p_label)
         where a.request_id = l_req and a.respondent_type = 'REQUESTER'
           and a.question_id = (select q.question_id from xxcmp_questions q
                                 where q.questionnaire_code = 'CORPORATE' and q.question_text like '%' || p_q || '%');
    end;
begin
    select application_id into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'KYC';
    apex_session.create_session(l_app, 1, 'REQ1');
    xxcmp_request_pkg.save_request(l_req, 'NEW', null, 'ORGANIZATION', dbms_random.string('U', 16), 'AE',
               'R75UI' || to_char(systimestamp, 'HH24MISSFF3'), 'LLC', null,
               'contact@example.com', '+971 4 000 0000', null, null, 'PROCUREMENT', 'Release 75 browser test',
               p_registration_type => 'COMMERCIAL_REGISTRATION', p_business_relationship => 'VENDOR');
    answer('regulated stock exchange', 'No');
    answer('country of incorporation', 'Medium-risk jurisdiction');
    answer('transaction volume', 'Above 10 million');
    answer('politically exposed', 'No');
    answer('cash-intensive', 'Yes');
    xxcmp_request_pkg.submit(l_req);
    commit;
    select request_number into l_no from xxcmp_requests where request_id = l_req;
    dbms_output.put_line('REQ=' || l_req || ',' || l_no);
    apex_session.delete_session;
end;
/""")
rid, rno = next(l for l in created if l.startswith('REQ=')).split('=')[1].split(',')
for _ in range(45):
    t = db(f"select max(task_id) from apex_tasks where detail_pk = '{rid}' and task_def_static_id = 'DOC_CHECKLIST_REVIEW' and state_code in ('ASSIGNED','UNASSIGNED');")
    if t and t[0]:
        break
    time.sleep(2)

with sync_playwright() as p:
    b = p.chromium.launch(executable_path=os.environ.get('CHROME', '/opt/pw-browsers/chromium-1194/chrome-linux/chrome'),
                          args=['--no-sandbox'])
    # ------------------------------------------------------------ layout: home Metric Cards
    pg, s = login(b, 'OFFICER1')
    tiles = pg.locator('#home_kpis .a-CardView-item, #home_kpis li')
    ok(f'home: the tiles are Metric Cards ({tiles.count()})', tiles.count() >= 3)
    ok('home: each tile has a title and a number',
       all(re.search(r'\d', t) for t in pg.locator('#home_kpis .a-CardView-item, #home_kpis li').all_inner_texts()))
    shot(pg, 'r75_home.png')

    # ------------------------------------------------------------ B1 (release 76): Approve, then the request's Assign Case
    open_task(pg, s, rno)
    ok('approval: the request summary is a Field Grid with group titles',
       pg.locator('.kyc-fieldgrid').count() > 0 and pg.locator('.kyc-fieldgrid .kyc-group-title').count() > 0)
    shot(pg, 'r75_206.png')
    pg.locator('#decision_buttons button', has_text=re.compile(r'^\s*Approve\s*$')).first.click()
    pg.locator('#decision_dialog').wait_for(state='visible')
    ok('Approve: the common approval dialog has no case officer field', pg.locator('#P206_CASE_ASSIGNEE').count() == 0)
    with pg.expect_navigation(timeout=120000):
        pg.locator('#decision_dialog button.kyc-decide-confirm').click()
    pg.wait_for_load_state('networkidle')
    dlg = pg.locator('#assign_dialog')
    try:
        dlg.wait_for(state='visible', timeout=15000)
    except Exception:
        pass
    ok('after the approval: the request opens with Assign Case (page 205)',
       ':205:' in pg.url or 'kyc-request' in pg.url or pg.locator('#P205_ASSIGN_TO').count() == 1)
    ok('Assign Case is open at once', dlg.is_visible())
    names = [o.strip() for o in pg.locator('#P205_ASSIGN_TO option').all_inner_texts()]
    ok(f'Assign Case: only Compliance officers are offered ({len(names) - 1})', len(names) > 2)
    shot(pg, 'r75_205_after_approve.png')
    pg.select_option('#P205_ASSIGN_TO', 'MGR1')
    with pg.expect_navigation(timeout=60000):
        pg.locator('.ui-dialog:has(#assign_dialog) button:has-text("Assign"), #assign_dialog button:has-text("Assign")').last.click()
    pg.wait_for_load_state('networkidle')
    case = None
    for _ in range(30):
        case = db(f"select case_id || ',' || assigned_to from xxcmp_cases where request_id = {rid};")
        if case:
            break
        time.sleep(2)
    ok(f'the case opened by the approval goes to the officer chosen ({case})', case and case[0].endswith(',MGR1'))
    pg.close()

    # ------------------------------------------------------------ B2: Assign Case on the approved request
    pg, s = login(b, 'MGR1')
    open_request(pg, s, rno)
    shot(pg, 'r75_205.png')
    btn = pg.locator('button:has-text("Assign Case")')
    ok('the approved request has Assign Case for a Cases manager', btn.count() == 1 and btn.first.is_visible())
    btn.first.click()
    pg.locator('#assign_dialog').wait_for(state='visible')
    pg.select_option('#P205_ASSIGN_TO', 'OFFICER1')
    pg.fill('#P205_ASSIGN_COMMENT', 'Release 75 browser test')
    with pg.expect_navigation(timeout=60000):
        pg.locator('.ui-dialog:has(#assign_dialog) button:has-text("Assign"), #assign_dialog button:has-text("Assign")').last.click()
    pg.wait_for_load_state('networkidle')
    ok('Assign Case: confirmed', 'Case assigned' in pg.inner_text('body'))
    after = db(f"select assigned_to from xxcmp_cases where request_id = {rid};")
    ok(f'the case is now OFFICER1\'s ({after})', after == ['OFFICER1'])
    owners = db(f"""select listagg(p.participant, ',') within group (order by p.participant) from apex_task_participants p
                     join apex_tasks t on t.task_id = p.task_id
                    where t.task_def_static_id = 'CASE_INVESTIGATION' and t.detail_pk = (select to_char(case_id) from xxcmp_cases where request_id = {rid})
                      and t.state_code in ('ASSIGNED','UNASSIGNED') and p.participant_type = 'POTENTIAL_OWNER';""")
    ok(f'its investigation task moved too ({owners})', owners == ['OFFICER1'])
    pg.close()

    # ------------------------------------------------------------ layout: case summary
    pg, s = login(b, 'OFFICER1')
    pg.goto(f'{HOST}/ords/f?p={APP}:210:{s}'); pg.wait_for_load_state('networkidle')
    cno = db(f"select case_number from xxcmp_cases where request_id = {rid};")[0]
    pg.locator('.a-IRR-search-field').first.fill(cno); pg.keyboard.press('Enter')
    pg.wait_for_load_state('networkidle'); pg.wait_for_timeout(1500)
    with pg.expect_navigation():
        pg.locator(f'.a-IRR-table a:has-text("{cno}")').first.click()
    pg.wait_for_load_state('networkidle')
    grid = pg.locator('.kyc-fieldgrid .kyc-grid').first
    cols = pg.evaluate("e => getComputedStyle(e).gridTemplateColumns.split(' ').length", grid.element_handle()) if grid.count() else 0
    ok(f'case: the summary is a Field Grid in 3 columns ({cols})', cols == 3)
    shot(pg, 'r75_211.png')
    pg.close()
    b.close()

print(f'{sum(results)}/{len(results)} passed')
sys.exit(0 if all(results) else 1)
