# NEO-30 lab cloud controller (our own teaching script, not a product). Plain HTTP on the lab net
# (a real cloud uses TLS with device certificates). Holds claims, one template, and device status.
#   serve                     run the controller on :8080
#   claim <serial> <name>     claim a device serial for this network
#   devices                   list devices: name, serial, config version, last seen, state
#   template <key> <value>    change the campus template (new version for every device)
import http.server, json, sys, time, threading, urllib.request
PORT = 8080
OFFLINE_S = 6
SITE = {  # per-device part of the config; the template part is shared
    "east": {"addrs": ["10.30.10.1/25 dev eth2"], "routes": ["10.30.10.128/25 via 10.30.1.12"]},
    "west": {"addrs": ["10.30.10.129/25 dev eth2"], "routes": ["10.30.10.0/25 via 10.30.1.11"]}}
st = dict(version=1, template={"lan_mtu": "1500"}, claims={}, seen={})
lock = threading.Lock()
def config_for(name):
    c = dict(SITE[name]); c["version"] = st["version"]; c["template"] = st["template"]; return c
class H(http.server.BaseHTTPRequestHandler):
    def reply(self, code, obj):
        b = json.dumps(obj).encode(); self.send_response(code)
        self.send_header("Content-Type", "application/json"); self.send_header("Content-Length", str(len(b)))
        self.end_headers(); self.wfile.write(b)
    def do_GET(self):
        q = dict(p.split("=", 1) for p in self.path.split("?", 1)[1].split("&")) if "?" in self.path else {}
        with lock:
            if self.path.startswith("/config"):
                s = q.get("serial", ""); a = q.get("applied", "0")
                if s not in st["claims"]: return self.reply(403, {"error": "serial not claimed"})
                st["seen"][s] = (time.time(), int(a)); return self.reply(200, config_for(st["claims"][s]))
            if self.path == "/devices":
                now = time.time(); rows = []
                for s, n in st["claims"].items():
                    t, v = st["seen"].get(s, (None, 0))
                    age = None if t is None else round(now - t)
                    state = "never seen" if t is None else ("online" if age <= OFFLINE_S else "offline")
                    rows.append(dict(name=n, serial=s, applied=v, latest=st["version"], age=age, state=state))
                return self.reply(200, rows)
        self.reply(404, {})
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])) or b"{}")
        with lock:
            if self.path == "/claim": st["claims"][body["serial"]] = body["name"]
            elif self.path == "/template": st["template"][body["key"]] = body["value"]; st["version"] += 1
            else: return self.reply(404, {})
            return self.reply(200, {"ok": True, "version": st["version"]})
    def log_message(self, *a): pass
def call(path, obj=None):
    req = urllib.request.Request(f"http://localhost:{PORT}{path}", data=None if obj is None else json.dumps(obj).encode(),
                                 headers={"Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(req, timeout=2).read())
if __name__ == "__main__":
    c = sys.argv[1]
    if c == "serve":
        class S(http.server.ThreadingHTTPServer): pass
        srv = S(("0.0.0.0", PORT), H); srv.serve_forever()
    elif c == "claim":
        call("/claim", dict(serial=sys.argv[2], name=sys.argv[3])); print(f"claimed {sys.argv[2]} as {sys.argv[3]}")
    elif c == "template":
        r = call("/template", dict(key=sys.argv[2], value=sys.argv[3])); print(f"template {sys.argv[2]}={sys.argv[3]}: now version {r['version']}")
    elif c == "devices":
        print(f"{'name':6} {'serial':10} {'config':8} {'last seen':10} state")
        for r in call("/devices"):
            seen = "-" if r["age"] is None else f"{r['age']} s ago"
            print(f"{r['name']:6} {r['serial']:10} {'v%d/v%d' % (r['applied'], r['latest']):8} {seen:10} {r['state']}")
