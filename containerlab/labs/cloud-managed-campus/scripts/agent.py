# NEO-30 lab device agent (our own teaching script, not a product). Calls OUT to the controller
# every 2 s; it opens no listening port. Applies a newer config with ip; keeps the last config when
# the controller cannot be reached.  Usage: agent.py <serial> <controller-url>
import json, subprocess, sys, time, urllib.request, urllib.error
serial, url = sys.argv[1], sys.argv[2]; applied = 0; t0 = time.time(); last = None
def log(msg):
    global last
    if msg != last: print(f"t={time.time() - t0:5.1f}s {msg}", flush=True); last = msg
def ip(*a): subprocess.run(["ip", *a], check=False, capture_output=True)
while True:
    try:
        r = urllib.request.urlopen(f"{url}/config?serial={serial}&applied={applied}", timeout=1.5)
        c = json.loads(r.read())
        if c["version"] > applied:
            if applied == 0:
                for a in c["addrs"]: ip("addr", "add", *a.split())
                for rt in c["routes"]: ip("route", "replace", *rt.split())
            ip("link", "set", "eth2", "mtu", c["template"]["lan_mtu"])
            applied = c["version"]; log(f"applied config v{applied}")
            urllib.request.urlopen(f"{url}/config?serial={serial}&applied={applied}", timeout=1.5).read()
        else:
            log(f"in sync at v{applied}")
    except urllib.error.HTTPError as e:
        log(f"controller says {e.code}: {json.loads(e.read())['error']}")
    except Exception as e:
        log(f"controller unreachable ({type(e).__name__}); keep v{applied}")
    time.sleep(2)
