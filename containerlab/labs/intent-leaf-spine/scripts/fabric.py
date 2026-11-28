# NEO-31 lab fabric tool (our own teaching script, not a product).
# One intent file -> rendered per-device configs -> deploy -> validate live state against the intent.
# Usage: fabric.py render <intent> <dir> | diff <old-dir> <new-dir> | deploy <dir> [dev ...] | validate <intent>
# The lab reaches devices with docker exec; real tools push and read over an API or SSH.
import ipaddress as ip, json, os, subprocess, sys

def load(path):
    "Intent file: one 'key = value' line each: spines = ... / leaf <name> = <subnet> ... / links = <pool>."
    t = {}
    for line in open(path):
        if "=" in line:
            k, v = (x.strip() for x in line.split("=", 1)); t[k] = v.split()
    sp = t["spines"]; lv = {k[5:]: v for k, v in t.items() if k.startswith("leaf ")}
    t["links"] = t["links"][0]
    base = ip.ip_network(t["links"]).network_address
    links = {}  # (spine, leaf) -> (spine addr, leaf addr)
    for i, s in enumerate(sp):
        for j, l in enumerate(lv):
            k = i * len(lv) + j
            links[(s, l)] = (str(base + 2 * k), str(base + 2 * k + 1))
    return t, sp, lv, links

def gw(net):
    n = ip.ip_network(net); return f"{n.network_address + 1}/{n.prefixlen}"

def render(path):
    t, sp, lv, links = load(path)
    out = {}
    for s in sp:
        c = [f"# {s}.conf rendered from {os.path.basename(path)}"]
        for l in lv: c.append(f"addr replace {links[(s, l)][0]}/31 dev to-{l}")
        for l in lv:
            for net in lv[l]: c.append(f"route replace {net} via {links[(s, l)][1]}")
        out[s] = c
    for l in lv:
        c = [f"# {l}.conf rendered from {os.path.basename(path)}"]
        for s in sp: c.append(f"addr replace {links[(s, l)][1]}/31 dev to-{s}")
        for i, net in enumerate(lv[l]): c.append(f"addr replace {gw(net)} dev lan{i}")
        for o in lv:
            if o == l: continue
            for net in lv[o]:
                c.append(f"route replace {net} " + " ".join(f"nexthop via {links[(s, l)][0]}" for s in sp))
        out[l] = c
    return out

PREFIX = os.environ.get("CLAB_PREFIX", "clab-intent-leaf-spine")

def nse(dev, *cmd, stdin=None):
    argv = ["docker", "exec"]
    if stdin is not None:
        argv.append("-i")
    argv += [f"{PREFIX}-{dev}", *cmd]
    r = subprocess.run(argv, input=stdin, capture_output=True, text=True)
    return r.returncode, r.stdout, r.stderr.strip()

cmd = sys.argv[1]
if cmd == "render":
    d = sys.argv[3]; os.makedirs(d, exist_ok=True)
    for dev, c in render(sys.argv[2]).items():
        open(os.path.join(d, f"{dev}.conf"), "w").write("\n".join(c) + "\n")
        print(f"wrote {d}/{dev}.conf  ({len(c) - 1} lines)")
elif cmd == "diff":
    a, b = sys.argv[2], sys.argv[3]; n = 0
    for f in sorted(os.listdir(b)):
        old = [x for x in open(os.path.join(a, f)).read().splitlines() if not x.startswith("#")] if os.path.exists(os.path.join(a, f)) else []
        new = [x for x in open(os.path.join(b, f)).read().splitlines() if not x.startswith("#")]
        dev = f[:-5]
        for x in old:
            if x not in new: print(f"- {dev} {x}"); n += 1
        for x in new:
            if x not in old: print(f"+ {dev} {x}"); n += 1
    print(f"{n} changed lines")
elif cmd == "deploy":
    d = sys.argv[2]; devs = sys.argv[3:] or sorted(f[:-5] for f in os.listdir(d) if f.endswith(".conf"))
    for dev in devs:
        body = open(os.path.join(d, f"{dev}.conf")).read()
        rc, _, err = nse(dev, "ip", "-batch", "-", stdin=body)
        print(f"deployed {dev}" if rc == 0 else f"deploy {dev} failed: {err}")
elif cmd == "validate":
    t, sp, lv, links = load(sys.argv[2])
    owner = {}
    for (s, l), (sa, la) in links.items(): owner[sa] = s; owner[la] = l
    fails = checks = 0
    def row(dev, what, have, want):
        global fails, checks
        checks += 1; ok = have == want
        if not ok: fails += 1
        h = ", ".join(have) or "none"
        tail = "" if ok else f" (want {', '.join(want)})"
        print(f"{dev}  {what:<18} via {h}{tail}".ljust(56) + ("PASS" if ok else "FAIL"))
    down = []
    for (s, l) in links:
        for dev, ifn in ((s, f"to-{l}"), (l, f"to-{s}")):
            _, o, _ = nse(dev, "ip", "-j", "link", "show", ifn)
            st = json.loads(o or "[{}]")[0].get("operstate")
            if st != "UP": down.append(f"{dev}:{ifn}")
    checks += 1
    if down: fails += 1
    print((f"links  {len(links)} of {len(links)} up" if not down else f"links  down: {' '.join(down)}").ljust(56) + ("FAIL" if down else "PASS"))
    def live(dev):
        _, o, _ = nse(dev, "ip", "-j", "-4", "route", "show")
        m = {}
        for r in json.loads(o or "[]"):
            hops = [h["gateway"] for h in r.get("nexthops", [])] or ([r["gateway"]] if "gateway" in r else [])
            m[r["dst"]] = sorted(owner.get(h, h) for h in hops)
        return m
    for l in lv:
        m = live(l)
        for o in lv:
            if o == l: continue
            for net in lv[o]: row(l, net, m.get(net, []), sorted(sp))
    for s in sp:
        m = live(s)
        for l in lv:
            for net in lv[l]: row(s, net, m.get(net, []), [l])
    print(f"result: {checks} checks, {fails} FAIL")
