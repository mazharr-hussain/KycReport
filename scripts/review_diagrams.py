#!/usr/bin/env python3
"""Geometric quality reviewer for draw.io flow diagrams.
Since the JS viewer can't render in this sandbox (CDN blocked), this parses
mxGraph XML coordinates directly and flags real layout defects:
  - overlapping node bounding boxes (excluding intentional container nesting)
  - edges whose routed path crosses through an unrelated node
  - poor canvas utilization / off-center content (wasted space)
  - back-and-forth loop edges that visually tangle
"""
import re, sys, json

def parse_page(body):
    raw = {}
    for m in re.finditer(
        r'<mxCell id="([^"]+)" value="([^"]*)" style="([^"]*)"[^>]*vertex="1"[^>]*parent="([^"]+)">\s*'
        r'<mxGeometry x="(-?\d+)" y="(-?\d+)" width="(\d+)" height="(\d+)"',
        body):
        nid, val, style, parent, x, y, w, h = m.groups()
        is_container = ('dashed=1' in style and 'rounded=1' in style) or 'swimlane' in style
        raw[nid] = dict(x=int(x), y=int(y), w=int(w), h=int(h), val=val,
                         style=style, parent=parent, is_container=is_container)
    # resolve absolute coordinates by walking up parent chain (parent="1" = root/absolute)
    nodes = {}
    for nid, n in raw.items():
        x, y = n['x'], n['y']
        p = n['parent']
        depth = 0
        while p != "1" and p in raw and depth < 10:
            x += raw[p]['x']
            y += raw[p]['y']
            p = raw[p]['parent']
            depth += 1
        nodes[nid] = dict(x=x, y=y, w=n['w'], h=n['h'], val=n['val'],
                           style=n['style'], is_container=n['is_container'])
    edges = []
    for m in re.finditer(
        r'<mxCell id="([^"]+)"(?: value="([^"]*)")?[^>]*edge="1"[^>]*source="([^"]+)" target="([^"]+)"[^>]*style="([^"]*)"?',
        body):
        pass
    # more robust: separate style/source/target regardless of attr order
    for m in re.finditer(r'<mxCell id="([^"]+)"([^>]*)edge="1"([^>]*)>(.*?)</mxCell>', body, re.S):
        eid, pre, post, inner = m.groups()
        attrs = pre + post
        sm = re.search(r'source="([^"]+)"', attrs)
        tm = re.search(r'target="([^"]+)"', attrs)
        stym = re.search(r'style="([^"]*)"', attrs)
        valm = re.search(r'value="([^"]*)"', attrs)
        waypoints = [(int(x), int(y)) for x, y in re.findall(r'<mxPoint x="(-?\d+)" y="(-?\d+)"\s*/>', inner)]
        if sm and tm:
            edges.append(dict(id=eid, source=sm.group(1), target=tm.group(1),
                               style=stym.group(1) if stym else "",
                               val=valm.group(1) if valm else "",
                               waypoints=waypoints))
    m = re.search(r'pageWidth="(\d+)" pageHeight="(\d+)"', body)
    pw, ph = (int(m.group(1)), int(m.group(2))) if m else (0, 0)
    return nodes, edges, pw, ph

def overlap(a, b):
    ax1, ay1, ax2, ay2 = a['x'], a['y'], a['x']+a['w'], a['y']+a['h']
    bx1, by1, bx2, by2 = b['x'], b['y'], b['x']+b['w'], b['y']+b['h']
    ix1, iy1 = max(ax1, bx1), max(ay1, by1)
    ix2, iy2 = min(ax2, bx2), min(ay2, by2)
    if ix1 < ix2 and iy1 < iy2:
        return (ix2-ix1) * (iy2-iy1)
    return 0

def contains(outer, inner, margin=5):
    return (outer['x']-margin <= inner['x'] and outer['y']-margin <= inner['y']
            and outer['x']+outer['w']+margin >= inner['x']+inner['w']
            and outer['y']+outer['h']+margin >= inner['y']+inner['h'])

def edge_exit_entry(edge, src, tgt):
    """Approximate exit/entry point from style hints, default to box center."""
    def pt(style, node, prefix):
        xm = re.search(prefix+r'X=([\d.]+)', style)
        ym = re.search(prefix+r'Y=([\d.]+)', style)
        fx = float(xm.group(1)) if xm else 0.5
        fy = float(ym.group(1)) if ym else 0.5
        return (node['x'] + fx*node['w'], node['y'] + fy*node['h'])
    p1 = pt(edge['style'], src, 'exit')
    p2 = pt(edge['style'], tgt, 'entry')
    return p1, p2

def segment_crosses_box(p1, p2, box, margin=2):
    """Treat orthogonal edge as L-shaped: horizontal then vertical (mid-point elbow)."""
    x1, y1 = p1
    x2, y2 = p2
    # two possible elbow paths; check both, if either avoids the box we call it clear-ish,
    # but mxgraph typically picks shortest/cleanest so check the "natural" H-then-V and V-then-H
    def seg_hits(sx1, sy1, sx2, sy2):
        bx1, by1, bx2, by2 = box['x']-margin, box['y']-margin, box['x']+box['w']+margin, box['y']+box['h']+margin
        # sample the segment
        steps = 20
        for i in range(steps+1):
            t = i/steps
            sx = sx1 + (sx2-sx1)*t
            sy = sy1 + (sy2-sy1)*t
            if bx1 < sx < bx2 and by1 < sy < by2:
                return True
        return False
    elbow1 = (x2, y1)  # H then V
    elbow2 = (x1, y2)  # V then H
    hit1 = seg_hits(x1,y1,elbow1[0],elbow1[1]) or seg_hits(elbow1[0],elbow1[1],x2,y2)
    hit2 = seg_hits(x1,y1,elbow2[0],elbow2[1]) or seg_hits(elbow2[0],elbow2[1],x2,y2)
    return hit1 and hit2  # only flag if BOTH natural routings would hit (conservative)

def review_page(name, nodes, edges, pw, ph):
    issues = []
    ids = list(nodes.keys())

    # 1. overlap check (skip container/child legit nesting)
    for i in range(len(ids)):
        for j in range(i+1, len(ids)):
            a, b = nodes[ids[i]], nodes[ids[j]]
            ov = overlap(a, b)
            if ov <= 0:
                continue
            if a['is_container'] and contains(a, b):
                continue
            if b['is_container'] and contains(b, a):
                continue
            issues.append(f"OVERLAP: '{a['val'][:30]}' ({ids[i]}) overlaps '{b['val'][:30]}' ({ids[j]}) by {ov}px2")

    # 2. edge routing collision with unrelated nodes
    real_nodes = {k: v for k, v in nodes.items() if not v['is_container']}
    for e in edges:
        src, tgt = nodes.get(e['source']), nodes.get(e['target'])
        if not src or not tgt:
            issues.append(f"DANGLING EDGE: {e['id']} {e['source']}->{e['target']}")
            continue
        p1, p2 = edge_exit_entry(e, src, tgt)
        route = [p1] + e.get('waypoints', []) + [p2]
        for nid, n in real_nodes.items():
            if nid in (e['source'], e['target']):
                continue
            hit = False
            if len(route) > 2:
                # explicit waypoints given: check each straight segment directly (no elbow ambiguity)
                bx1, by1, bx2, by2 = n['x']-2, n['y']-2, n['x']+n['w']+2, n['y']+n['h']+2
                for k in range(len(route)-1):
                    sx1, sy1 = route[k]
                    sx2, sy2 = route[k+1]
                    steps = 20
                    for i in range(steps+1):
                        t = i/steps
                        sx = sx1 + (sx2-sx1)*t
                        sy = sy1 + (sy2-sy1)*t
                        if bx1 < sx < bx2 and by1 < sy < by2:
                            hit = True
                            break
                    if hit:
                        break
            else:
                hit = segment_crosses_box(p1, p2, n)
            if hit:
                issues.append(f"EDGE COLLISION: edge {e['id']} ({e['source']}->{e['target']}) passes through node '{n['val'][:30]}' ({nid})")

    # 0. out-of-bounds check: does every node actually fit inside the declared canvas?
    for nid, n in nodes.items():
        x2, y2 = n['x'] + n['w'], n['y'] + n['h']
        if n['x'] < 0 or n['y'] < 0 or x2 > pw or y2 > ph:
            issues.append(f"OUT OF BOUNDS: '{n['val'][:30]}' ({nid}) at x={n['x']},y={n['y']},x2={x2},y2={y2} exceeds canvas {pw}x{ph}")

    # 3. canvas utilization / centering
    real = [n for n in nodes.values()]
    if real:
        minx = min(n['x'] for n in real)
        miny = min(n['y'] for n in real if n['y'] > 55)  # exclude title
        maxx = max(n['x']+n['w'] for n in real)
        maxy = max(n['y']+n['h'] for n in real)
        content_w = maxx - minx
        content_h = maxy - miny
        util_w = content_w / pw if pw else 0
        left_margin = minx
        right_margin = pw - maxx
        if util_w < 0.55:
            issues.append(f"WASTED SPACE: content uses only {util_w*100:.0f}% of canvas width ({content_w}/{pw}px)")
        if left_margin > 0 and right_margin > 0:
            imbalance = abs(left_margin - right_margin) / pw
            if imbalance > 0.15:
                issues.append(f"NOT CENTERED (horiz): left margin {left_margin}px vs right margin {right_margin}px (imbalance {imbalance*100:.0f}%)")
        bottom_margin = ph - maxy
        if bottom_margin < 0:
            issues.append(f"BOTTOM OVERFLOW: content bottom at {maxy}px exceeds canvas height {ph}px")
        elif bottom_margin > 0 and bottom_margin < 15:
            issues.append(f"CRAMPED BOTTOM: only {bottom_margin}px margin below lowest node — too tight, risk of clipping")
        elif ph > 0 and bottom_margin / ph > 0.35:
            issues.append(f"EXCESS BOTTOM SPACE: {bottom_margin}px ({bottom_margin/ph*100:.0f}% of canvas height) empty below content")

    # 4. cycle detection of any length (DFS) -- these render as tangled loops
    #    unless the source/target IDs are identical node reused deliberately (self-loop skip)
    graph = {}
    for e in edges:
        graph.setdefault(e['source'], []).append(e['target'])
    seen_cycles = set()
    def dfs(start, node, path, visited):
        for nxt in graph.get(node, []):
            if nxt == start and len(path) >= 2:
                cyc = tuple(sorted(path))
                if cyc not in seen_cycles:
                    seen_cycles.add(cyc)
                    issues.append(f"CYCLE: {' -> '.join(path)} -> {start} — renders as a tangled loop, needs explicit loop-back visual treatment")
            elif nxt not in visited and len(path) < 5:
                dfs(start, nxt, path + [nxt], visited | {nxt})
    for nid in real_nodes:
        dfs(nid, nid, [nid], {nid})

    return issues

def main(path):
    content = open(path).read()
    diagrams = re.findall(r'<diagram id="([^"]*)" name="([^"]*)">(.*?)</diagram>', content, re.S)
    total_issues = 0
    for did, name, body in diagrams:
        nodes, edges, pw, ph = parse_page(body)
        issues = review_page(name, nodes, edges, pw, ph)
        status = "FAIL" if issues else "PASS"
        print(f"\n=== [{status}] {path.split('/')[-1]} :: {name} ({len(nodes)} nodes, {len(edges)} edges, {pw}x{ph}) ===")
        for iss in issues:
            print("  -", iss)
        total_issues += len(issues)
    return total_issues

if __name__ == "__main__":
    total = 0
    for f in sys.argv[1:]:
        total += main(f)
    print(f"\nTOTAL ISSUES: {total}")
    sys.exit(1 if total else 0)
