# Chunk 4 browser test (run tasks_prep.sql first): tasks in My Tasks open their details page and can be acted on.
import re, time
from playwright.sync_api import sync_playwright
ROOT = 'http://localhost:8080/ords'
out = []


def login(b, user):
    pg = b.new_page()
    pg.goto(f'{ROOT}/r/xxcus/kyc/login'); pg.fill('#P9999_USERNAME', user); pg.fill('#P9999_PASSWORD', 'KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
    return pg, re.search(r'session=(\d+)', pg.url).group(1)


def my_tasks(pg, s):
    pg.goto(f'{ROOT}/f?p=101:40:{s}'); pg.wait_for_load_state('networkidle')
    return [(a.inner_text().strip(), a.get_attribute('href')) for a in pg.query_selector_all('#t_Body_content a')
            if a.inner_text().strip()]


def frame(pg):
    for _ in range(40):
        fr = [f for f in pg.frames if f != pg.main_frame and '/r/xxcus/' in f.url]
        if fr and fr[-1].query_selector('form'):
            fr[-1].wait_for_load_state('networkidle'); return fr[-1]
        pg.wait_for_timeout(250)
    raise RuntimeError('no dialog')


with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args=['--no-sandbox'])
    # 1. REQ1 answers the request for information from My Tasks
    pg, s = login(b, 'REQ1')
    tasks = my_tasks(pg, s)
    rfi = [t for t in tasks if t[0].startswith('Information requested')]
    out.append(f'REQ1 My Tasks: {[t[0] for t in tasks]}')
    pg.click(f'#t_Body_content a:has-text("{rfi[-1][0]}")'); pg.wait_for_load_state('networkidle')
    out.append(f'  opens: {pg.url.split("/kyc/")[1].split("?")[0]}, RFI number shown: {rfi[-1][0].split(": ")[1] in pg.inner_text("body")}')
    pg.fill('#P31_RESPONSE_TEXT', 'UI test answer ' + time.strftime('%H:%M:%S'))
    pg.click('button:has-text("Send Response")'); pg.wait_for_load_state('networkidle')
    msg = pg.query_selector('.t-Alert-title, .t-Alert-content, #t_Alert_Success')
    out.append(f'  respond -> {msg.inner_text().strip()[:60] if msg else "no message"}')
    tasks = my_tasks(pg, s)
    out.append(f'  REQ1 tasks afterwards: {[t[0] for t in tasks] or "none"}')
    pg.close()
    # 2. OFFICER1 gets the review task
    pg, s = login(b, 'OFFICER1')
    tasks = my_tasks(pg, s)
    out.append(f'OFFICER1 My Tasks: {[t[0] for t in tasks]}')
    pg.close()
    # 3. MGR1 (the maker) opens the configuration change: no Approve button
    pg, s = login(b, 'MGR1')
    tasks = my_tasks(pg, s)
    out.append(f'MGR1 (maker) My Tasks: {[t[0] for t in tasks] or "none"}')
    pg.close()
    # 4. HOC1 approves it on page 172
    pg, s = login(b, 'HOC1')
    tasks = my_tasks(pg, s)
    cfg = [t for t in tasks if t[0].startswith('Mandatory document rule')]
    out.append(f'HOC1 My Tasks: {[t[0] for t in tasks]}')
    pg.click(f'#t_Body_content a:has-text("{cfg[-1][0]}")')
    f = frame(pg)
    out.append('  review dialog: ' + ' | '.join(x.strip() for x in f.inner_text('#review').split('\n') if x.strip())[:200])
    out.append(f'  buttons: {[x.inner_text().strip() for x in f.query_selector_all("button") if x.is_visible() and x.inner_text().strip()]}')
    f.click('button:has-text("Approve")'); pg.wait_for_timeout(4000)
    tasks = my_tasks(pg, s)
    out.append(f'  after approval, HOC1 tasks: {[t[0] for t in tasks]}')
    pg.close()
    b.close()
print('\n'.join(out))
