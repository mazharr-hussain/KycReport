"""User-guide videos of the COMMON components (release 89): one screen recording per component (Playwright), with a title card,
captions from each page's own help text and an end card on how another application uses the component.
Usage (a COMMON database with sample data, ADMIN / KycTest#2026, pip install playwright imageio-ffmpeg):
    python3 apex/tools/record_user_guide.py [out dir] [component ...]   (default: apex/docs/user-guide/videos, all)
"""
import glob, os, re, shutil, subprocess, sys, time
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'repos', 'tools'))
from common_components import C
from playwright.sync_api import sync_playwright
import imageio_ffmpeg

APP = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'src', 'database', 'xxfusion', 'apex_apps', 'f135', 'pages') + '/'
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'docs', 'user-guide', 'videos')
ONLY = sys.argv[2:]   # component slugs (default: all)
R = 'http://localhost:8080/ords/r/xxcus/common'
os.makedirs(OUT, exist_ok=True)

def page_help(pid):
    f = glob.glob(APP + f'p{pid:05d}-*.apx')
    if not f: return ''
    m = re.search(r'^    help \{\n        helpText:\n            ```\n(.*?)\n            ```', open(f[0]).read(), re.S | re.M)
    if not m:
        m = re.search(r'^    help \{\n        helpText: (.*)$', open(f[0]).read(), re.M)
    return re.sub(r'\s+', ' ', m.group(1)).strip() if m else ''

# component: (slug in common_components, steps). A step: ('page', alias, page_id) opens a list page; ('row', page_id)
# opens the first row of its report; ('url', path, page_id, caption) opens a page with its arguments.
COMPONENTS = [
 ('home', [('page', 'home', 1)]),
 ('applications', [('page', 'applications', 160), ('row', 166), ('page', 'setup-types', 162), ('page', 'subscriptions', 164)]),
 ('app-settings', [('page', 'application-settings', 10022), ('row', 10023)]),
 ('optional-features', [('page', 'optional-features', 10020)]),
 ('platform-activity', [('page', 'platform-activity', 170)]),
 ('usage-feedback', [('page', 'feedback', 171), ('row', 172)]),
 ('give-feedback', [('nav', 'Feedback', 173)]),
 ('data-model', [('page', 'data-model', 175), ('row', 176), ('page', 'data-model-diagram', 177)]),
 ('users-access', [('page', 'users', 103), ('row', 104)]),
 ('roles-privileges', [('page', 'roles', 105), ('row', 106), ('page', 'privileges', 182), ('page', 'segregation-of-duties', 107)]),
 ('data-security', [('page', 'data-security', 180), ('row', 181)]),
 ('audit-log', [('page', 'audit-log', 111)]),
 ('lookups', [('page', 'lookups', 101), ('row', 102)]),
 ('flexfields', [('page', 'descriptive-flexfields', 152), ('row', 153), ('page', 'value-sets', 150)]),
 ('attachments', [('page', 'document-categories', 132), ('page', 'document-entities', 130), ('page', 'attachment-pages', 134), ('page', 'document-storage', 136)]),
 ('documents', [('url', 'communications?p45_application_code=COMMON&p45_entity_name=R85_TEST&p45_pk1_value=20261017195145', 45,
                 'Applications open the documents of one of their records in COMMON (here from the e-mails of a record).'), ('row', 47)]),
 ('retention', [('page', 'retention-policies', 112)]),
 ('workflow-setup', [('page', 'process-catalogue', 147), ('page', 'deadlines-and-escalation', 145), ('page', 'delegations', 114)]),
 ('approval-setup', [('page', 'approval-setup', 148), ('row', 149)]),
 ('change-approvals', [('page', 'my-tasks', 40)]),
 ('my-tasks', [('page', 'my-tasks', 40), ('page', 'notifications', 43)]),
 ('workflow-monitor', [('page', 'workflow-monitor', 141)]),
 ('information-requests', [('page', 'my-tasks', 40)]),
 ('notifications', [('page', 'notification-templates', 109), ('row', 110), ('page', 'notification-delivery', 116), ('page', 'notification-log', 117)]),
 ('communications', [('url', 'communications?p45_application_code=COMMON&p45_entity_name=R85_TEST&p45_pk1_value=20261017195145', 45,
                      'An application opens the e-mails of one of its records here; Send E-mail opens the e-mail page.')]),
 ('integrations', [('page', 'servers', 120), ('page', 'integration-purposes', 122), ('page', 'transmission-log', 124)]),
]

CSS = """
#guide-cap{position:fixed;left:50%;bottom:28px;transform:translateX(-50%);max-width:1100px;width:calc(100% - 80px);
 background:rgba(20,28,38,.92);color:#fff;font:500 19px/1.45 'Segoe UI',system-ui,sans-serif;padding:14px 22px;border-radius:10px;
 z-index:99999;box-shadow:0 6px 24px rgba(0,0,0,.25)}
#guide-cap b{color:#7fd6dd;font-weight:600}
#guide-card{position:fixed;inset:0;z-index:100000;background:#10202a;color:#fff;display:flex;flex-direction:column;
 justify-content:center;padding:0 110px;font-family:'Segoe UI',system-ui,sans-serif}
#guide-card .k{font:600 15px/1 monospace;letter-spacing:.14em;color:#7fd6dd;text-transform:uppercase;margin-bottom:18px}
#guide-card h1{font-size:46px;margin:0 0 22px;font-weight:600}
#guide-card p{font-size:21px;line-height:1.5;max-width:1000px;margin:0 0 14px;color:#dbe6ee}
"""
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
def esc(t): return t.replace('&', '&amp;').replace('<', '&lt;')
def read_time(t): return min(14, max(4, len(t) / 16))
def tour(pg, title, text):
    pg.wait_for_load_state('networkidle'); pg.wait_for_timeout(600)
    cap = f'<b>{esc(title)}</b> — {esc(text)}' if text else f'<b>{esc(title)}</b>'
    show_cap(pg, cap)
    t = read_time(text)
    pg.wait_for_timeout(int(t * 600))
    pg.mouse.wheel(0, 450); pg.wait_for_timeout(int(t * 250))
    pg.mouse.wheel(0, -450); pg.wait_for_timeout(int(t * 150))

def record(slug, steps, browser):
    c = C[slug]
    ctx = browser.new_context(viewport={'width': 1280, 'height': 720}, record_video_dir=f'{OUT}/raw',
                              record_video_size={'width': 1280, 'height': 720})
    pg = ctx.new_page()
    pg.goto(f'{R}/login', timeout=120000)
    pg.fill('#P9999_USERNAME', 'ADMIN'); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
    sess = pg.url.split('session=')[1].split('&')[0]
    card(pg, f"COMMON user guide · {c['module']}", c['name'],
         [c['purpose'], 'Why: ' + c['benefit']], 7)
    for st in steps:
        try:
            if st[0] == 'page':
                pg.goto(f"{R}/{st[1]}?session={sess}", timeout=120000)
                tour(pg, pg.title().replace('Common - ', ''), page_help(st[2]))
            elif st[0] == 'url':
                pg.goto(f"{R}/{st[1]}&session={sess}", timeout=120000)
                tour(pg, pg.title().replace('Common - ', ''), st[3] + ' ' + page_help(st[2]))
            elif st[0] == 'nav':
                pg.locator('.t-NavigationBar a', has_text=st[1]).first.click()
                tour(pg, pg.title().replace('Common - ', ''), page_help(st[2]))
            elif st[0] == 'row':
                link = pg.locator('.a-IRR-table td a, .t-Report-report td a, .a-GV-table td a, .t-Cards a').first
                if link.count() == 0:
                    continue
                show_cap(pg, '<b>Open a row</b> — the first row opens its detail page.')
                link.hover(); pg.wait_for_timeout(1200); link.click()
                pg.wait_for_load_state('networkidle'); pg.wait_for_timeout(800)
                if pg.locator('.ui-dialog iframe').count():          # a dialog page
                    fr = pg.frame_locator('.ui-dialog iframe').first
                    show_cap(pg, f'<b>Detail</b> — {esc(page_help(st[1]))}')
                    pg.wait_for_timeout(int(read_time(page_help(st[1])) * 900))
                    pg.keyboard.press('Escape'); pg.wait_for_timeout(600)
                else:
                    tour(pg, pg.title().replace('Common - ', ''), page_help(st[1]))
                    pg.go_back(); pg.wait_for_load_state('networkidle')
        except Exception as e:
            print('  step skipped', st[:2], str(e)[:120])
    card(pg, 'For developers of other applications', 'Use it from your application',
         [re.sub(r'`', '', c['other'])], max(6, read_time(c['other'])))
    video = pg.video.path()
    ctx.close()
    ff = imageio_ffmpeg.get_ffmpeg_exe()
    target = f"{OUT}/{slug}.mp4"
    subprocess.run([ff, '-y', '-loglevel', 'error', '-i', video, '-c:v', 'libx264', '-preset', 'medium', '-crf', '30',
                    '-pix_fmt', 'yuv420p', '-movflags', '+faststart', target], check=True)
    os.remove(video)
    return target

with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args=['--no-sandbox'])
    for slug, steps in COMPONENTS:
        if ONLY and slug not in ONLY: continue
        t0 = time.time()
        f = record(slug, steps, b)
        print(f'{slug}: {os.path.getsize(f)//1024} KB, {time.time()-t0:.0f}s')
    b.close()
shutil.rmtree(f'{OUT}/raw', ignore_errors=True)
