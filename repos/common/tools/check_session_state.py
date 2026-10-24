"""Release 74 (A-05): a form item that is not kept in session state reads empty in a partial refresh, an Ajax call or
a link built later in the session (release 73: P211_CASE_ID - the screenings list did not refresh, the breadcrumb
gave ORA-01403). This check lists every hidden form-region item without `sessionState { storage: ... }` that a region
refreshed over Ajax uses: a protected hidden item is not sent with the refresh, so only session state carries it.

Usage: python3 apex/tools/check_session_state.py            # both applications; exit code 1 when something is found
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APPS = [os.path.join(ROOT, 'src', 'database', 'xxcus', 'apex_apps', 'f134'),
        os.path.join(ROOT, 'src', 'database', 'xxfusion', 'apex_apps', 'f135')]


def blocks(text, keyword):
    """(name, body) of every top-level `keyword NAME ( ... )` block (balanced parentheses)."""
    for m in re.finditer(r'(?m)^    %s ([\w\-]+) \(' % keyword, text):
        depth, i = 0, m.end() - 1
        while i < len(text):
            if text[i] == '(':
                depth += 1
            elif text[i] == ')':
                depth -= 1
                if depth == 0:
                    break
            i += 1
        yield m.group(1), text[m.start():i + 1]


def check(path):
    text = open(path).read()
    # regions refreshed over Ajax: a refresh action targets them, or they submit page items when refreshed
    refreshed = set(re.findall(r'action: refresh\s+affectedElements \{\s+selectionType: region\s+region: @([\w\-]+)', text))
    regions = dict(blocks(text, 'region'))
    for rname, rbody in regions.items():
        if 'pageItemsToSubmit:' in rbody:
            refreshed.add(rname)
    found = []
    for name, body in blocks(text, 'pageItem'):
        # a hidden form item: protected, so an Ajax refresh does not send it; only session state carries it
        if 'formRegion:' not in body or 'storage:' in body or not re.search(r'(?m)^        type: hidden', body):
            continue
        for rname in refreshed:
            rbody = regions.get(rname, '')
            if re.search(r':%s\b|\b%s\b' % (name, name), rbody):
                found.append(f'{name} (region {rname})')
                break
    return found


def main():
    problems = 0
    for app in APPS:
        pages = os.path.join(app, 'pages')
        for f in sorted(os.listdir(pages)):
            for item in check(os.path.join(pages, f)):
                problems += 1
                print(f'{os.path.basename(app)}/{f}: {item} is used by a refreshed region but not kept in session state '
                      '(add sessionState { storage: session })')
    print('session state check:', 'OK' if not problems else f'{problems} item(s) to fix')
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
