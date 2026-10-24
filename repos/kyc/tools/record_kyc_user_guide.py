"""User-guide videos of the KYC application (release 92): one screen recording per KYC component (Playwright), with a title
card, captions from each page's own help text and an end card. Videos 3-5 follow one new request from the requester's
wizard to the approved case, each step done by the user whose role does it (REQ1, OFFICER1, MGR1).
Shared functions (My Tasks, documents, e-mail, information requests, users and roles) are COMMON's: their videos are
apex/docs/user-guide/videos (record_user_guide.py).
Usage (KYC and COMMON installed with the test users of apex/tests/test_users.sql, password KycTest#2026;
pip install playwright imageio-ffmpeg):
    python3 apex/tools/record_kyc_user_guide.py [out dir] [component ...]   (default: apex/docs/user-guide/kyc/videos, all)
The flow videos (create-request, request-approval, cases) depend on each other: record them together and in this order.
"""
import glob, os, random, re, string, subprocess, sys, time
from playwright.sync_api import sync_playwright
import imageio_ffmpeg

HERE = os.path.dirname(os.path.abspath(__file__))
PAGES = os.path.join(HERE, '..', 'src', 'database', 'xxcus', 'apex_apps', 'f134', 'pages') + '/'
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'docs', 'user-guide', 'kyc', 'videos')
ONLY = sys.argv[2:]
HOST = 'http://localhost:8080'
SQLCL = os.environ.get('SQLCL', 'sql')
PASSWORD = 'KycTest#2026'
os.makedirs(OUT, exist_ok=True)
# a counterparty unlike any earlier one (else the wizard first asks whether it is a possible match)
FLOW = {'name': random.choice(['Aldenmoor', 'Brightwater', 'Cedarline', 'Dunmore', 'Eastvale', 'Fairhaven', 'Glenrock', 'Harborview'])
        + ' ' + random.choice(['Logistics', 'Foods', 'Textiles', 'Engineering', 'Shipping', 'Medical']) + ' '
        + ''.join(random.choice(string.ascii_uppercase) for _ in range(3)) + ' LLC'}


def db(sql):
    out = subprocess.run([SQLCL, '-S', '-name', 'kyc_local'], input=f'set heading off feedback off pages 0\n{sql};\nexit\n',
                         capture_output=True, text=True).stdout
    return [l.strip() for l in out.splitlines() if l.strip() and 'JAVA_TOOL' not in l]


def wait_db(sql, secs=90):
    for _ in range(secs // 2):
        r = db(sql)
        if r and r[0] not in ('', '0'):
            return r[0]
        time.sleep(2)
    return None


def page_help(pid):
    f = glob.glob(PAGES + f'p{pid:05d}-*.apx')
    if not f:
        return ''
    s = open(f[0]).read()
    m = re.search(r'^    help \{\n        helpText:\n            ```\n(.*?)\n            ```', s, re.S | re.M) \
        or re.search(r'^    help \{\n        helpText: (.*)$', s, re.M)
    return re.sub(r'\s+', ' ', m.group(1)).strip() if m else ''


CSS = """
#guide-cap{position:fixed;left:50%;bottom:28px;transform:translateX(-50%);max-width:1100px;width:calc(100% - 80px);
 background:rgba(20,28,38,.92);color:#fff;font:500 19px/1.45 'Segoe UI',system-ui,sans-serif;padding:14px 22px;border-radius:10px;
 z-index:99999;box-shadow:0 6px 24px rgba(0,0,0,.25);pointer-events:none}
#guide-cap b{color:#7fd6dd;font-weight:600}
#guide-card{position:fixed;inset:0;z-index:100000;background:#10202a;color:#fff;display:flex;flex-direction:column;
 justify-content:center;padding:0 110px;font-family:'Segoe UI',system-ui,sans-serif}
#guide-card .k{font:600 15px/1 monospace;letter-spacing:.14em;color:#7fd6dd;text-transform:uppercase;margin-bottom:18px}
#guide-card h1{font-size:46px;margin:0 0 22px;font-weight:600}
#guide-card p{font-size:21px;line-height:1.5;max-width:1000px;margin:0 0 14px;color:#dbe6ee}
"""


def esc(t):
    return t.replace('&', '&amp;').replace('<', '&lt;')


def read_time(t):
    return min(14, max(4, len(t) / 16))


def show_cap(pg, html):
    pg.evaluate("""([css, html]) => { let s=document.getElementById('guide-css'); if(!s){s=document.createElement('style');
        s.id='guide-css'; s.textContent=css; document.head.appendChild(s);} let d=document.getElementById('guide-cap');
        if(!d){d=document.createElement('div'); d.id='guide-cap'; document.body.appendChild(d);} d.innerHTML=html; }""", [CSS, html])


def card(pg, kicker, title, paras, secs):
    pg.evaluate("""([css,k,t,ps]) => { let s=document.getElementById('guide-css'); if(!s){s=document.createElement('style');
        s.id='guide-css'; s.textContent=css; document.head.appendChild(s);} let d=document.createElement('div'); d.id='guide-card';
        d.innerHTML='<div class="k"></div><h1></h1>'; d.querySelector('.k').textContent=k; d.querySelector('h1').textContent=t;
        for (const p of ps){const e=document.createElement('p'); e.textContent=p; d.appendChild(e);} document.body.appendChild(d); }""",
                [CSS, kicker, title, paras])
    pg.wait_for_timeout(int(secs * 1000))
    pg.evaluate("() => { const d=document.getElementById('guide-card'); if(d) d.remove(); }")


def title(pg):
    return re.sub(r'^.*? - ', '', pg.title())


def say(pg, head, text, secs=None):
    """A caption for an action on the current page."""
    show_cap(pg, f'<b>{esc(head)}</b> — {esc(text)}' if text else f'<b>{esc(head)}</b>')
    pg.wait_for_timeout(int((secs or read_time(text)) * 750))


def tour(pg, text, head=None):
    pg.wait_for_load_state('networkidle'); pg.wait_for_timeout(600)
    say(pg, head or title(pg), text, 0.01)
    t = read_time(text)
    pg.wait_for_timeout(int(t * 600))
    pg.mouse.wheel(0, 450); pg.wait_for_timeout(int(t * 250))
    pg.mouse.wheel(0, -450); pg.wait_for_timeout(int(t * 150))


class Ctx:
    """The recording of one video: a browser context with its own video file, signed in as one user."""
    def __init__(self, browser, user):
        self.ctx = browser.new_context(viewport={'width': 1280, 'height': 720}, record_video_dir=f'{OUT}/raw',
                                       record_video_size={'width': 1280, 'height': 720})
        self.pg = self.ctx.new_page()
        self.login(user)

    def login(self, user):
        pg = self.pg
        pg.goto(f'{HOST}/ords/r/xxcus/kyc/login', timeout=120000)
        pg.fill('#P9999_USERNAME', user); pg.fill('#P9999_PASSWORD', PASSWORD)
        pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
        self.s = re.search(r'session=(\d+)', pg.url).group(1)
        self.user = user

    def switch(self, user, why):
        say(self.pg, f'Signed in as {user}', why, 5)
        self.ctx.clear_cookies()
        self.login(user)

    def page(self, pid, help_extra=''):
        self.pg.goto(f'{HOST}/ords/f?p=134:{pid}:{self.s}', timeout=120000)
        tour(self.pg, (help_extra + ' ' + page_help(pid)).strip())

    def row(self, pid, selector='.a-IRR-table td a, .t-Report-report td a, #report td a, .t-Cards a, .a-CardView a'):
        pg = self.pg
        link = pg.locator(selector).first
        if link.count() == 0:
            return
        say(pg, 'Open a row', 'the first row opens its detail page.', 3)
        link.hover(); pg.wait_for_timeout(800); link.click()
        pg.wait_for_load_state('networkidle'); pg.wait_for_timeout(800)
        if pg.locator('.ui-dialog iframe').count():
            show_cap(pg, f'<b>Detail</b> — {esc(page_help(pid))}')
            pg.wait_for_timeout(int(read_time(page_help(pid)) * 900))
            pg.keyboard.press('Escape'); pg.wait_for_timeout(600)
        else:
            tour(pg, page_help(pid))
            pg.go_back(); pg.wait_for_load_state('networkidle')

    def click(self, label, confirm=False):
        pg = self.pg
        with pg.expect_navigation(timeout=120000):
            pg.locator('button', has_text=re.compile(r'^\s*%s\s*$' % re.escape(label))).locator('visible=true').first.click()
            if confirm:
                pg.locator('.ui-dialog .js-confirmBtn, .ui-dialog button:has-text("OK"), .ui-dialog button:has-text("Confirm")').first.click(timeout=10000)
        pg.wait_for_load_state('networkidle')

    def open_task(self, page_item, task):
        """The task from the My Tasks region of the KYC home page. (COMMON's My Tasks page opens KYC task pages without
        a checksum, refused by KYC's page protection: listed as an open issue in the KYC guide.)"""
        pg = self.pg
        subject = db(f"select subject from apex_tasks where task_id = {task}")
        for _ in range(6):
            pg.goto(f'{HOST}/ords/f?p=134:1:{self.s}', timeout=120000); pg.wait_for_load_state('networkidle')
            link = pg.locator('a', has_text=subject[0][:40]).first if subject else pg.locator('#none')
            if link.count():
                link.scroll_into_view_if_needed()
                say(pg, 'My Tasks', 'the task waits on the home page (and in COMMON My Tasks with the tasks of every application).', 5)
                with pg.expect_navigation(timeout=120000):
                    link.click()
                pg.wait_for_load_state('networkidle')
                return True
            pg.wait_for_timeout(4000)
        return False

    def finish(self, slug, end_title, end_text):
        card(self.pg, 'Good to know', end_title, end_text, max(6, sum(read_time(t) for t in end_text) * 0.6))
        video = self.pg.video.path()
        self.ctx.close()
        ff = imageio_ffmpeg.get_ffmpeg_exe()
        subprocess.run([ff, '-y', '-loglevel', 'error', '-i', video, '-c:v', 'libx264', '-preset', 'medium', '-crf', '30',
                        '-pix_fmt', 'yuv420p', '-movflags', '+faststart', f'{OUT}/{slug}.mp4'], check=True)
        os.remove(video)


def decide(pg, label, comment=None):
    """The decision bar of the approval screen (206): a decision opens the Decision dialog; Confirm submits."""
    pg.locator('#decision_buttons button', has_text=re.compile(r'^\s*%s\s*$' % label)).first.click()
    pg.locator('#decision_dialog').wait_for(state='visible')
    if comment is not None:
        pg.fill('#P206_COMMENT', comment)
    pg.wait_for_timeout(1500)
    with pg.expect_navigation(timeout=120000):
        pg.locator('#decision_dialog button.kyc-decide-confirm').click()
    pg.wait_for_load_state('networkidle')


# ------------------------------------------------------------------------------------------------ the components
def v_home(c):
    c.page(1)
    say(c.pg, 'Tiles', 'each tile counts what waits for you and opens the list behind it.', 5)
    c.switch('OFFICER1', 'the same home page for a Compliance Officer shows their cases and tasks.')
    c.page(1)


def v_parties(c):
    c.page(20)
    c.row(21)
    c.pg.goto(f'{HOST}/ords/f?p=134:24:{c.s}', timeout=120000)
    tour(c.pg, 'Create Party opens the party wizard. ' + page_help(24))


def v_create_request(c):
    pg = c.pg
    c.page(200)
    pg.goto(f'{HOST}/ords/f?p=134:201:{c.s}', timeout=120000); pg.wait_for_load_state('networkidle')
    tour(pg, page_help(201))
    say(pg, 'New counterparty', 'the requester enters the company in the common party form, with the department and the reason.', 5)
    pg.evaluate('''(n) => {
        apex.item("P0_PARTY_NAME").setValue(n);
        apex.item("P0_PARTY_REGISTRATION_NUMBER").setValue("REG-" + Date.now());
        apex.item("P0_PARTY_JURISDICTION").setValue("AE");
        apex.item("P0_PARTY_EMAIL").setValue("contact@example.com");
        apex.item("P0_PARTY_PHONE").setValue("+971 4 000 0000");
        apex.item("P201_REQUESTING_DEPARTMENT").setValue("PROCUREMENT");
        apex.item("P201_JUSTIFICATION").setValue("New supplier of office equipment");
    }''', FLOW['name'])
    pg.wait_for_timeout(1200)
    pg.evaluate('apex.item("P0_PARTY_ENTITY_TYPE").setValue("LLC"); apex.item("P0_PARTY_REGISTRATION_TYPE").setValue("COMMERCIAL_REGISTRATION"); apex.item("P201_BUSINESS_RELATIONSHIP").setValue("VENDOR")')
    pg.wait_for_timeout(2500)
    c.click('Next')
    tour(pg, page_help(204))
    c.click('Next')
    FLOW['req'] = db(f"select request_id from xxcmp_requests where party_name = '{FLOW['name']}'")[0]
    tour(pg, page_help(202))
    answers = {'regulated stock exchange': 'No', 'country of incorporation': 'Medium-risk jurisdiction',
               'transaction volume': 'Above 10 million', 'politically exposed': 'No', 'cash-intensive': 'Yes'}
    for frag, label in answers.items():
        fs = pg.locator('fieldset.kyc-q', has_text=frag)
        if fs.count():
            fs.first.scroll_into_view_if_needed()
            fs.first.locator('label.kyc-q-option', has_text=label).first.click()
            pg.wait_for_timeout(700)
    c.click('Next')
    tour(pg, page_help(203))
    say(pg, 'Submit Request', 'the request goes to its approvers; the requester follows it on the request page.', 4)
    c.click('Submit Request')
    tour(pg, page_help(205))


def flow_ids():
    # the demo request of an earlier run when create-request is not recorded in this run
    if 'req' not in FLOW:
        r = db("select max(request_id) from xxcmp_requests")
        FLOW['req'] = r[0] if r else None
    if 'case' not in FLOW and FLOW.get('req'):
        r = db(f"select max(case_id) from xxcmp_cases where request_id = {FLOW['req']}")
        FLOW['case'] = r[0] if r and r[0] else None


def v_request_approval(c):
    pg = c.pg
    flow_ids()
    task = wait_db(f"select max(task_id) from apex_tasks where task_def_static_id = 'DOC_CHECKLIST_REVIEW' and detail_pk = '{FLOW['req']}'")
    if not task or not c.open_task('P206_TASK_ID', task):
        raise RuntimeError('the approval task of the demo request was not found')
    tour(pg, page_help(206))
    say(pg, 'Approve', 'the approver approves with a comment; Reject and Request Information need one.', 4)
    decide(pg, 'Approve', 'Documents complete.')
    pg.wait_for_timeout(1500)
    tour(pg, 'This was the last approval step and the score routes the request to Compliance: the case is open. '
             'The approver assigns the Compliance Officer here (Assign Case).', 'Case opened')
    if pg.locator('.ui-dialog:visible').count():
        pg.wait_for_timeout(2500)
        pg.keyboard.press('Escape'); pg.wait_for_timeout(800)
    FLOW['case'] = wait_db(f"select max(case_id) from xxcmp_cases where request_id = {FLOW['req']}")


def v_cases(c):
    pg = c.pg
    flow_ids()
    c.page(210)
    itask = wait_db(f"select max(task_id) from apex_tasks where task_def_static_id = 'CASE_INVESTIGATION' and detail_pk = '{FLOW['case']}'")
    if not itask or not c.open_task('P211_TASK_ID', itask):
        raise RuntimeError('the investigation task of the demo case was not found')
    tour(pg, page_help(211))

    def section(label, text):
        with pg.expect_navigation(timeout=120000):
            pg.locator('#case_sections a', has_text=label).first.click()
        pg.wait_for_load_state('networkidle')
        tour(pg, text, label)
    section('Party', 'the party, its contacts and owners: the common party regions, the same as on the Party page.')
    section('Screening', page_help(213))
    try:
        pg.click('button:has-text("Add Screening")')
        frame = pg.frame_locator('iframe').first
        frame.locator('#P213_SCREENING_TYPE').wait_for(timeout=30000)
        say(pg, 'Add Screening', 'a sanctions check with no match.', 3)
        frame.locator('#P213_SCREENING_TYPE').select_option('SANCTIONS')
        frame.locator('#P213_MATCH_STATUS').select_option('NO_MATCH')
        pg.wait_for_timeout(1500)
        frame.locator('button:has-text("Create")').click()
        pg.locator('.ui-dialog iframe').wait_for(state='detached', timeout=30000)
        pg.reload(); pg.wait_for_load_state('networkidle')
    except Exception as e:
        print('  screening skipped', str(e)[:120])
    section('Risk Assessment', 'the officer sets the risk tier (the risk model suggests one) and writes the conclusion.')
    pg.evaluate('apex.item("P211_RISK_TIER").setValue("MEDIUM")')
    pg.fill('#P211_REPORT_CONCLUSION', 'No red flags found in the screening.')
    pg.fill('#P211_NEXT_STEPS', 'On-going monitoring applied.')
    pg.wait_for_timeout(1500)
    with pg.expect_navigation(timeout=120000):
        pg.click('#buttons button:has-text("Save")')
    pg.wait_for_load_state('networkidle')
    section('Notes and RFIs', 'notes for the file, and requests for information to a colleague or the counterparty (COMMON information requests).')
    section('Review and Submit', 'everything at a glance, with the approval path. Submit for Approval sends the case to its approvers.')
    c.click('Submit for Approval', confirm=True)
    atask = wait_db(f"select max(task_id) from apex_tasks where task_def_static_id = 'CASE_APPROVAL' and detail_pk = '{FLOW['case']}'")
    c.switch('MGR1', 'the Compliance Manager decides the case from the approval task.')
    if atask and c.open_task('P211_TASK_ID', atask):
        tour(pg, 'Review mode: the same case read only, with the decision bar (Approve, Reject, Request Information, Add Approver).', 'Case approval')
        pg.fill('#P211_DEC_COMMENT', 'Approved.')
        pg.wait_for_timeout(1200)
        c.click('Approve')
        pg.wait_for_timeout(1500)
    if wait_db(f"select count(*) from xxcmp_cases where case_id = {FLOW['case']} and case_status = 'APPROVED'"):
        pg.goto(f'{HOST}/ords/f?p=134:217:{c.s}::::P217_CASE_ID:{FLOW["case"]}', timeout=120000)
        tour(pg, page_help(217))


def v_rules(c):
    c.page(160)
    c.row(161)
    c.page(163)
    c.page(165)
    c.page(167)
    c.page(138)


def v_monitoring(c):
    c.page(220)
    c.page(221)


def v_alert_rules(c):
    c.page(225)
    c.row(226)


def v_dashboard(c):
    c.page(230)


# slug, name, user, purpose, why, steps, end card
COMPONENTS = [
    ('home', 'Home', 'REQ1',
     'Where every user starts: what waits for them, as tiles that open the lists behind them.',
     'Each role sees its own work first.', v_home,
     ['Tasks of every application are in My Tasks (COMMON); notifications in Notifications (COMMON).']),
    ('parties', 'Parties', 'OFFICER1',
     'Every company and person the organisation deals with: the party, its contacts, owners and officers, documents, identity and registry checks.',
     'One record per counterparty, reused by every request and case; duplicates are merged by Compliance.', v_parties,
     ['A requester can also create a party inside a KYC request: it stays Pending until the request is approved.']),
    ('create-request', 'KYC Requests: create a request', 'REQ1',
     'A business user asks Compliance to clear a counterparty: the request and counterparty, the party details, the questionnaire, then review and submit.',
     'The questionnaire score decides whether a KYC case is needed at all.', v_create_request,
     ['Save as Draft keeps the request to finish later; Withdraw is on the KYC Requests list.',
      'Documents are added with COMMON\'s attachment dialog.']),
    ('request-approval', 'KYC Requests: approval', 'OFFICER1',
     'The approvers of the request (set in COMMON Approval Setup) check the request and its documents from their task.',
     'Nothing becomes a case until the documents are complete.', v_request_approval,
     ['Request Information sends the question back to the requester (Pending Information); Merge resolves a duplicate party.']),
    ('cases', 'Cases', 'OFFICER1',
     'The Compliance investigation: screening, documents, ownership, risk assessment, source of funds, notes and RFIs; then a second person approves.',
     'Every decision is recorded with its evidence and ends in a printable Compliance Report.', v_cases,
     ['High-risk cases and SAR decisions go to the Head of Compliance.',
      'Requests for information and e-mails use COMMON (Information Request, Communications).']),
    ('kyc-rules', 'KYC Rules', 'MGR1',
     'The setup that drives KYC: questionnaires and scoring, conclusion templates, approval matrix, risk model and mandatory document rules.',
     'Business users change the rules; a second person approves every change before it applies.', v_rules,
     ['Configuration changes wait in My Tasks (COMMON Configuration Change) for the second person.']),
    ('monitoring', 'Monitoring', 'MGR1',
     'Approved parties under review: when each review is due, running reviews, and alerts from the monitoring rules.',
     'Reviews start on time by themselves; an alert can start an early review.', v_monitoring,
     ['Reassess starts an early review now; the review is a new request through the same flow.']),
    ('alert-rules', 'Alert Rules', 'HOC1',
     'What the daily monitoring run watches: reviews coming due or overdue, investigations past their SLA, expiring documents, adverse screenings.',
     'The thresholds are business settings, not code.', v_alert_rules,
     ['The System Administrator maintains the alert rules; the Head of Compliance can view them.']),
    ('dashboard', 'Executive Dashboard', 'MGR1',
     'Where KYC stands: open requests and cases, SLA and review backlog, decisions and the risk profile of approved parties.',
     'One page for management, from live data.', v_dashboard,
     ['Visible to the Compliance Manager and the Head of Compliance.']),
]


if __name__ == '__main__':
    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path='/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args=['--no-sandbox'])
        for slug, name, user, purpose, why, fn, end in COMPONENTS:
            if ONLY and slug not in ONLY:
                continue
            t0 = time.time()
            print('recording', slug)
            c = Ctx(browser, user)
            card(c.pg, 'KYC user guide', name, [purpose, 'Why: ' + why], 7)
            try:
                fn(c)
            except Exception as e:
                print('  step failed', slug, str(e)[:200])
            c.finish(slug, 'Good to know', end)
            print(f'  {slug}.mp4 {time.time() - t0:.0f}s')
        browser.close()
    print('flow:', FLOW)
