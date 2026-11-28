# NEO-29 lab runbook (our own teaching script, not a product). Read-only: it runs checks, it changes nothing.
# Usage: runbook.py <src-host> <dst-addr> <port>   or   runbook.py drift
# The lab reaches each device with docker exec; real tools use SSH or an API with a read-only account.
import ipaddress as ip, json, os, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import netmap
CONF = os.environ.get("CONF", "configs")
PREFIX = os.environ.get("CLAB_PREFIX", "clab-config-map-runbook")
devs = netmap.load(CONF)
def run(dev, *cmd):
    r = subprocess.run(["docker", "exec", f"{PREFIX}-{dev}", *cmd], capture_output=True, text=True)
    return r.returncode, r.stdout, r.stderr.strip()
def live_routes(dev):
    _, out, _ = run(dev, "ip", "-j", "-4", "route", "show", "proto", "boot")
    return {(r["dst"] if r["dst"] != "default" else "0.0.0.0/0", r.get("gateway")) for r in json.loads(out or "[]")}
def conf_routes(dev):
    return {(str(n), str(g)) for n, g in devs[dev]["routes"]}
def owner_live(addr):
    for d in devs:
        _, out, _ = run(d, "ip", "-j", "-4", "addr")
        for i in json.loads(out or "[]"):
            for a in i.get("addr_info", []):
                if a["local"] == addr: return d
def walk(src, dst):
    here, lines = src, []
    for _ in range(8):
        if owner_live(dst) == here:
            lines.append(f"  {here}: is {dst}, arrived"); return lines, True
        rc, out, err = run(here, "ip", "-j", "route", "get", dst)
        if rc:
            lines.append(f"  {here}: {err}"); return lines, False
        r = json.loads(out)[0]; gw = r.get("gateway")
        nxt = owner_live(gw or dst)
        lines.append(f"  {here}: out {r['dev']}" + (f" via {gw}" if gw else "") + f" -> {nxt}")
        here = nxt
    return lines, False
def step(n, name, ok, detail=()):
    print(f"{n} {'PASS' if ok else 'FAIL'}  {name}")
    for d in detail: print(d)
    return ok
if sys.argv[1] == "drift":
    bad = []
    for d in sorted(devs):
        for r in sorted(live_routes(d) - conf_routes(d)): bad.append(f"  {d}: live route {r[0]} via {r[1]} is not in {d}.conf")
        for r in sorted(conf_routes(d) - live_routes(d)): bad.append(f"  {d}: {d}.conf route {r[0]} via {r[1]} is not live")
    step(1, "running routes match the configs", not bad, bad)
    sys.exit(0)
src, dst, port = sys.argv[1], sys.argv[2], int(sys.argv[3])
down = []
for d in sorted(devs):
    _, out, _ = run(d, "ip", "-j", "link")
    st = {l["ifname"]: l["operstate"] for l in json.loads(out or "[]")}
    down += [f"  {d} {i}: {st.get(i, 'missing')}" for i, _ in devs[d]["ifs"] if st.get(i) != "UP"]
step(1, "configured interfaces are up", not down, down)
fw, ok_f = walk(src, dst); step(2, f"forward path {src} -> {dst}", ok_f, fw)
srcaddr = str(devs[src]["ifs"][0][1].ip); back = owner_live(dst)
rv, ok_r = walk(back, srcaddr); step(3, f"return path {back} -> {srcaddr}", ok_r, rv)
code = ("import socket,sys\ns=socket.socket(); s.settimeout(2)\n"
        "try: s.connect((sys.argv[1], int(sys.argv[2]))); print('connected')\n"
        "except Exception as e: print(type(e).__name__)")
_, out, _ = run(src, "python3", "-c", code, dst, str(port))
step(4, f"TCP {src} -> {dst}:{port} (2 s timeout)", out.strip() == "connected", [f"  {out.strip()}"])
