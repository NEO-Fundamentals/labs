#!/usr/bin/env python3
"""neo_diagram.py - make the prepared draw.io diagram and PNG for one NEO lab.

Author tool (viewers do not need it). For a lab file it:
  1. exports the topology with clab2drawio (the same exporter behind `containerlab graph --drawio`),
  2. restyles nodes that carry a `neo-role` label (firewall, load-balancer, server, sensor) and adds a
     second label line from `neo-note`,
  3. draws one oval across the member links of each LAG (link label `neo-lag: "LAG lag1"`),
  4. writes each link's subnet (link label `neo-net: "10.0.12.0/30"`) and a capture badge
     (link label `neo-capture: "edge-b:eth1"`) on the link,
  5. saves <lab>.drawio and renders <lab>.png with draw.io desktop (the real renderer).

Usage:  neo_diagram.py <lab>.clab.yml [--out-dir DIR] [--no-png] [--export EXISTING.drawio]
Needs:  pyyaml, clab-io-draw (clab2drawio). For the PNG: draw.io desktop and (headless) xvfb-run;
        point NEO_DRAWIO_BIN at the draw.io executable if it is not on PATH.
Lab-file labels used (all schema-valid):
  node labels : graph-icon (router|switch|host|network), graph-level, graph-posX, graph-posY,
                neo-role (firewall|load-balancer|server|sensor), neo-note (second label line, e.g. "SR Linux, AS 65201")
  link labels : neo-lag, neo-net, neo-capture
"""
import argparse, collections, math, os, re, shutil, subprocess, sys, tempfile
import xml.etree.ElementTree as ET
import yaml

OVAL = "ellipse;whiteSpace=wrap;html=1;fillColor=none;strokeColor=#D97706;strokeWidth=3;"
LAG_TEXT = "text;html=1;align=left;verticalAlign=middle;fontSize=14;fontStyle=1;fontColor=#B45309;"
NET_TEXT = "text;html=1;align=center;verticalAlign=middle;fontSize=11;fontColor=#475569;"
BADGE = ("rounded=1;whiteSpace=wrap;html=1;fillColor=#FFF7ED;strokeColor=#EA580C;strokeWidth=2;"
         "fontSize=11;fontStyle=1;fontColor=#9A3412;arcSize=40;")
SHAPE = ("html=1;aspect=fixed;verticalLabelPosition=bottom;verticalAlign=top;labelPosition=center;align=center;"
         "fontFamily=Helvetica;fontSize=12;fontColor=#111827;outlineConnect=0;strokeWidth=2;")
ROLES = {  # neo-role -> draw.io Networking-library shape and colours (outline red/green; others grey)
    "firewall":      "shape=mxgraph.networks.firewall;fillColor=#FEE2E2;strokeColor=#B91C1C;gradientColor=none;",
    "load-balancer": "shape=mxgraph.networks.load_balancer;fillColor=#DCFCE7;strokeColor=#15803D;gradientColor=none;",
    "server":        "shape=mxgraph.networks.server;fillColor=#E2E8F0;strokeColor=#475569;gradientColor=none;",
    "sensor":        "shape=mxgraph.networks.monitor;fillColor=#E2E8F0;strokeColor=#475569;gradientColor=none;",
}

def endpoints(link):
    out = []
    for e in link["endpoints"]:
        out.append((e["node"], e["interface"]) if isinstance(e, dict) else tuple(e.split(":", 1)))
    return out


CHIP_FS = 11          # port-chip font size in px (readability rule: 11 px or more)
CHIP_H = 19
def text_w(s, fs): return len(s) * fs * 0.58 + 8     # rough Helvetica width, slightly generous

def set_style(style, **kv):
    """Return style with the given keys replaced (draw.io: the last occurrence of a key wins, so drop old ones)."""
    parts = [p for p in style.split(";") if p and p.split("=")[0] not in kv]
    return ";".join(parts + [f"{k}={v}" for k, v in kv.items()]) + ";"

def rect_hit(a, b, m=0): return not (a[2] + m <= b[0] or b[2] + m <= a[0] or a[3] + m <= b[1] or b[3] + m <= a[1])
def seg_hit(p, q, r, m=1.5):
    n = max(2, int(math.hypot(q[0] - p[0], q[1] - p[1]) / 3))
    return any(r[0] - m <= p[0] + (q[0] - p[0]) * i / n <= r[2] + m and r[1] - m <= p[1] + (q[1] - p[1]) * i / n <= r[3] + m
               for i in range(n + 1))

LABEL_SIDES = {   # where the node name/note text goes: first side that touches no link, chip or other box wins
    "bottom": dict(labelPosition="center", align="center", verticalLabelPosition="bottom", verticalAlign="top", spacingTop=5, spacingLeft=0, spacingRight=0, spacingBottom=0),
    "top":    dict(labelPosition="center", align="center", verticalLabelPosition="top", verticalAlign="bottom", spacingTop=0, spacingLeft=0, spacingRight=0, spacingBottom=5),
    "right":  dict(labelPosition="right", align="left", verticalLabelPosition="middle", verticalAlign="middle", spacingTop=0, spacingLeft=7, spacingRight=0, spacingBottom=0),
    "left":   dict(labelPosition="left", align="right", verticalLabelPosition="middle", verticalAlign="middle", spacingTop=0, spacingLeft=0, spacingRight=7, spacingBottom=0),
}
def label_rect(side, g, w, h):
    x, y, gw, gh = g
    return {"bottom": (x + gw / 2 - w / 2, y + gh + 3, x + gw / 2 + w / 2, y + gh + 3 + h),
            "top": (x + gw / 2 - w / 2, y - 3 - h, x + gw / 2 + w / 2, y - 3),
            "right": (x + gw + 3, y + gh / 2 - h / 2, x + gw + 3 + w, y + gh / 2 + h / 2),
            "left": (x - 3 - w, y + gh / 2 - h / 2, x - 3, y + gh / 2 + h / 2)}[side]

class Layout:
    """Collision bookkeeping: boxes (rectangles that hold text or icons) and segments (links)."""
    def __init__(self, segs): self.segs = segs; self.boxes = []
    def hits(self, r, skip_links=(), margin=3):
        n = sum(rect_hit(r, b, margin) for b in self.boxes)
        n += sum(seg_hit(p, q, r) for lid, (p, q) in self.segs.items() if lid not in skip_links)
        return n
    def place(self, w, h, candidates, skip_links=()):
        best = None
        for cx, cy in candidates:
            r = (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2); k = self.hits(r, skip_links)
            if best is None or k < best[0]: best = (k, r)
            if k == 0: break
        self.boxes.append(best[1]); return best

def render_png(drawio, png):
    exe = os.environ.get("NEO_DRAWIO_BIN") or shutil.which("drawio") or shutil.which("draw.io")
    if not exe and os.path.exists("/opt/drawio/drawio"): exe = "/opt/drawio/drawio"
    if not exe:
        print("png: draw.io desktop not found (set NEO_DRAWIO_BIN); skipped"); return False
    cmd = [exe, "--no-sandbox", "-x", "-f", "png", "-s", "1.5", "-b", "24", "-o", png, drawio]
    if shutil.which("xvfb-run"): cmd = ["xvfb-run", "-a"] + cmd
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
    ok = os.path.exists(png) and os.path.getsize(png) > 0
    print("png:", png if ok else "FAILED " + r.stderr[-300:]); return ok

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("lab"); ap.add_argument("--out-dir"); ap.add_argument("--no-png", action="store_true")
    ap.add_argument("--export", help="use this existing clab2drawio export instead of running clab2drawio")
    a = ap.parse_args()
    topo = yaml.safe_load(open(a.lab)); name = topo["name"]; t = topo["topology"]
    out_dir = a.out_dir or os.path.dirname(os.path.abspath(a.lab)); os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, f"{name}.drawio"); png = os.path.join(out_dir, f"{name}.png")
    src = a.export
    if not src:
        src = os.path.join(tempfile.mkdtemp(), "export.drawio")
        exe = shutil.which("clab2drawio") or os.path.join(os.path.dirname(sys.executable), "clab2drawio")
        subprocess.run([exe, "-i", a.lab, "-o", src, "--theme", "nokia_modern", "--log-level", "error"], check=True)
    tree = ET.parse(src); root = tree.getroot(); model = root.find(".//root")
    geo, objs = {}, {}
    for o in root.iter("object"):
        c = o.find("mxCell"); g = c.find("mxGeometry") if c is not None else None
        if o.get("id", "").startswith("clab-") and c.get("vertex") and c.get("parent") == "1" and g is not None:
            geo[o.get("id")] = tuple(float(g.get(k)) for k in ("x", "y", "width", "height")); objs[o.get("id")] = (o, c)
    links = {o.get("id"): o.find("mxCell").get("style", "") for o in root.iter("object") if o.get("id", "").startswith("link_id")}
    nid = lambda n: f"clab-{name}-{n}"

    def link_pts(eps):
        (na, ia), (nb, ib) = eps
        lid = next((k for k in links if k.endswith(f"{nid(na)}:{ia}:{nid(nb)}:{ib}") or k.endswith(f"{nid(nb)}:{ib}:{nid(na)}:{ia}")), None)
        if lid is None: raise SystemExit(f"link not found in export: {eps}")
        s = dict(kv.split("=") for kv in links[lid].split(";") if "=" in kv)
        an = lid.split(":")[2]; bn = lid.split(":")[4]
        def pt(node, fx, fy):
            x, y, w, h = geo[node]; return x + w * float(fx), y + h * float(fy)
        return pt(an, s.get("exitX", .5), s.get("exitY", .5)), pt(bn, s.get("entryX", .5), s.get("entryY", .5))

    n = [100]
    def add(style, x, y, w, h, val):
        n[0] += 1
        cell = ET.SubElement(model, "mxCell", id=f"neo-{n[0]}", value=val, style=style, vertex="1", parent="1")
        ET.SubElement(cell, "mxGeometry", {"x": f"{x:.0f}", "y": f"{y:.0f}", "width": f"{w:.0f}", "height": f"{h:.0f}", "as": "geometry"})

    # 2. roles
    for node, nd in (t.get("nodes") or {}).items():
        nl = (nd or {}).get("labels") or {}
        if nl.get("neo-note"):
            o = objs[nid(node)][0]
            c0 = objs[nid(node)][1]
            if "html=1" not in c0.get("style", ""): c0.set("style", "html=1;" + c0.get("style", ""))
            o.set("label", f'{node}<br><font style="font-size:11px" color="#64748B">{nl["neo-note"]}</font>')
        role = nl.get("neo-role")
        if not role: continue
        if role not in ROLES: raise SystemExit(f"unknown neo-role {role!r} on {node}; use one of {sorted(ROLES)}")
        objs[nid(node)][1].set("style", SHAPE + ROLES[role])
    # 2b. layout. Everything below is computed from the link geometry so that no link, port chip, subnet text, badge
    #     or node text sits on top of another one (see Layout). Order: chips, node text, LAG ovals, badges, subnet text.
    segs = {}
    for lid in links:
        an, bn = lid.split(":")[2], lid.split(":")[4]; s = dict(kv.split("=") for kv in links[lid].split(";") if "=" in kv)
        def pt(node, fx, fy):
            x, y, w, h = geo[node]; return x + w * float(fx), y + h * float(fy)
        segs[lid] = (pt(an, s.get("exitX", .5), s.get("exitY", .5)), pt(bn, s.get("entryX", .5), s.get("entryY", .5)))
    L = Layout(segs)
    for g in geo.values(): L.boxes.append((g[0], g[1], g[0] + g[2], g[1] + g[3]))
    # 2c. port chips: full interface name (what a viewer types), 11 px, centred on the link just outside the node box
    for o in root.iter("object"):
        oid = o.get("id", "")
        if not oid.startswith("label:link:") or not oid.endswith((":src", ":trgt")): continue
        pr = oid.split(":"); lid = "link_id:" + oid[len("label:"):oid.rindex(":")]
        node, ifname = (pr[2], pr[3]) if pr[-1] == "src" else (pr[4], pr[5])
        c = o.find("mxCell"); g = c.find("mxGeometry")
        P, Q = (segs[lid][0], segs[lid][1]) if pr[-1] == "src" else (segs[lid][1], segs[lid][0])
        ln = math.hypot(Q[0] - P[0], Q[1] - P[1]) or 1; u = ((Q[0] - P[0]) / ln, (Q[1] - P[1]) / ln)
        w = text_w(ifname, CHIP_FS) + 6; h = CHIP_H; nx, ny, nw, nh = geo[node]; nr = (nx - 5, ny - 5, nx + nw + 5, ny + nh + 5)
        d = 0
        while d < ln and rect_hit((P[0] + u[0] * d - w / 2, P[1] + u[1] * d - h / 2, P[0] + u[0] * d + w / 2, P[1] + u[1] * d + h / 2), nr): d += 1
        # on the link just outside the node box; if that touches another chip or link (parallel links), slide along the
        # link or sit beside it, on the side with nothing in the way
        cn = (-u[1], u[0]); half = w / 2 * abs(cn[0]) + h / 2 * abs(cn[1]) + 3
        cands = [(P[0] + u[0] * (d + dd), P[1] + u[1] * (d + dd)) for dd in range(0, 28, 4)]
        for dd in range(0, 44, 4):
            for sd in (1, -1): cands.append((P[0] + u[0] * (d + dd) + sd * cn[0] * half, P[1] + u[1] * (d + dd) + sd * cn[1] * half))
        k, r = L.place(w, h, cands, skip_links={lid})
        if k: print(f"layout: chip {ifname} on {node.split('-')[-1]} still touches {k} item(s)")
        cx, cy = (r[0] + r[2]) / 2, (r[1] + r[3]) / 2
        o.set("label", ifname)
        c.set("style", set_style(c.get("style", ""), fontSize=CHIP_FS))
        g.set("x", f"{cx - w / 2 - nx:.1f}"); g.set("y", f"{cy - h / 2 - ny:.1f}"); g.set("width", f"{w:.1f}"); g.set("height", f"{h}")
    # 2d. node name/note text: bottom, top, right or left of the icon, whichever is free
    for node, g in geo.items():
        o, c = objs[node]; txt = re.sub(r"<[^>]+>", "\n", (o.get("label") or "").replace("<br>", "\n")).split("\n")
        txt = [x for x in txt if x.strip()]
        w = max(text_w(txt[0], 12) if txt else 20, *(text_w(x, 11) for x in txt[1:]), 20) + 6; h = 17 * max(1, len(txt)) + 4
        own = set(); L.boxes.remove((g[0], g[1], g[0] + g[2], g[1] + g[3]))
        best = None
        for side in ("bottom", "top", "right", "left"):
            r = label_rect(side, g, w, h); k = L.hits(r, margin=2)
            if best is None or k < best[0]: best = (k, side, r)
            if k == 0: break
        L.boxes.append((g[0], g[1], g[0] + g[2], g[1] + g[3])); L.boxes.append(best[2])
        c.set("style", set_style(c.get("style", ""), **LABEL_SIDES[best[1]]))
        if best[0]: print(f"layout: text of {node.split('-')[-1]} still touches {best[0]} item(s)")
    # 3-4. LAG ovals, capture badges, subnet text
    lags = collections.defaultdict(list); todo = []
    for l in t.get("links") or []:
        lab = l.get("labels") or {}; eps = endpoints(l)
        if len(eps) != 2: continue
        (an, ia), (bn, ib) = eps
        lid = next((k for k in links if k.endswith(f"{nid(an)}:{ia}:{nid(bn)}:{ib}") or k.endswith(f"{nid(bn)}:{ib}:{nid(an)}:{ia}")), None)
        if lid is None: raise SystemExit(f"link not found in export: {eps}")
        a_pt, b_pt = segs[lid]; mid = ((a_pt[0] + b_pt[0]) / 2, (a_pt[1] + b_pt[1]) / 2)
        if lab.get("neo-lag"): lags[(lab["neo-lag"], tuple(sorted(x for x, _ in eps)))].append(mid)
        todo.append((lid, a_pt, b_pt, lab))
    for (tag, _), mids in lags.items():
        xs = [m[0] for m in mids]; ys = [m[1] for m in mids]
        cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
        w = (max(xs) - min(xs)) + 84; h = (max(ys) - min(ys)) + 64
        add(OVAL, cx - w / 2, cy - h / 2, w, h, "")
        tw_, th_ = text_w(tag, 14) + 8, 24
        _, r = L.place(tw_, th_, [(cx + w / 2 + tw_ / 2 + 4, cy), (cx - w / 2 - tw_ / 2 - 4, cy), (cx, cy - h / 2 - th_ / 2 - 2), (cx, cy + h / 2 + th_ / 2 + 2)], skip_links=set(l for l, *_ in todo))
        add(LAG_TEXT, r[0], r[1], r[2] - r[0], r[3] - r[1], tag)
    def along(a, b, tt): return a[0] + (b[0] - a[0]) * tt, a[1] + (b[1] - a[1]) * tt
    TS = (.5, .42, .58, .34, .66, .26, .74, .18, .82)
    for lid, a_pt, b_pt, lab in todo:
        if lab.get("neo-capture"):
            ln = math.hypot(b_pt[0] - a_pt[0], b_pt[1] - a_pt[1]) or 1; ux, uy = (b_pt[0] - a_pt[0]) / ln, (b_pt[1] - a_pt[1]) / ln
            nx, ny = -uy, ux
            if ny < -1e-6 or (abs(ny) <= 1e-6 and nx < 0): nx, ny = -nx, -ny      # prefer below / left of the link
            half = 38 * abs(nx) + 11 * abs(ny)
            cands = [along(a_pt, b_pt, tt) for tt in TS]                           # on the link first, then beside it
            for extra in (6, 16):
                cands += [(along(a_pt, b_pt, tt)[0] + sd * nx * (half + extra), along(a_pt, b_pt, tt)[1] + sd * ny * (half + extra)) for tt in TS for sd in (1, -1)]
            _, r = L.place(76, 22, cands, skip_links={lid})
            add(BADGE, r[0], r[1], 76, 22, "capture")
    for lid, a_pt, b_pt, lab in todo:
        if lab.get("neo-net") and not lab.get("neo-lag"):
            val = lab["neo-net"]; w, h = text_w(val, 11) + 6, 18
            ln = math.hypot(b_pt[0] - a_pt[0], b_pt[1] - a_pt[1]) or 1; ux, uy = (b_pt[0] - a_pt[0]) / ln, (b_pt[1] - a_pt[1]) / ln
            nx, ny = -uy, ux
            if ny > 1e-6 or (abs(ny) <= 1e-6 and nx < 0): nx, ny = -nx, -ny      # prefer above / right of the link
            half = w / 2 * abs(nx) + h / 2 * abs(ny)
            cands = []
            for extra in (4, 12, 22):
                for tt in TS:
                    for sd in (1, -1):
                        px, py = along(a_pt, b_pt, tt); cands.append((px + sd * nx * (half + extra), py + sd * ny * (half + extra)))
            _, r = L.place(w, h, cands)
            add(NET_TEXT, r[0], r[1], r[2] - r[0], r[3] - r[1], val)
    tree.write(out, encoding="utf-8", xml_declaration=True); print("drawio:", out)
    if not a.no_png: render_png(out, png)

if __name__ == "__main__":
    main()
