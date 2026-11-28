#!/usr/bin/env python3
"""neo_lint.py - check NEO lab folders against the lab rules and the Containerlab JSON schema.
Usage: neo_lint.py <schema.json> <labs-dir | lab-dir | file.clab.yml> [...]
  <schema.json> is the Containerlab schema for the version the labs target:
  https://raw.githubusercontent.com/srl-labs/containerlab/v0.83.0/schemas/clab.schema.json
Checks per lab: the lab file is valid against the schema; folder name, lab file name and `name:` agree (a `<lab>-lite.clab.yml` file keeps `name: <lab>`); every node has a
graph-icon label; node kinds are SR Linux (nokia_srlinux), FRR (frr) or plain Linux containers (linux), at most 2 SR Linux
nodes; the mgmt IPv6 subnet is inside fd00::/8; every IPv4 address in the lab file, configs, scripts and README is inside
10.0.0.0/8, 172.16.0.0/12 or 192.168.0.0/16 (documentation ranges 192.0.2.0/24, 198.51.100.0/24, 203.0.113.0/24 and the
benchmark range 198.18.0.0/15 are named and rejected; netmasks, 0.0.0.0, 255.255.255.255 and the routing multicast groups
224.0.0.5 (OSPF) and 224.0.0.9 (RIP) are allowed); every IPv6 address in text is inside fd00::/8 (link-local fe80::/10 and
multicast ff00::/8 are allowed, documentation prefixes 2001:db8::/32 and 3fff::/20 are rejected); every AS number in BGP configuration statements (after autonomous-system, remote-as, peer-as, router bgp, local-as or prepend) is private
(64512-65534 or 4200000000-4294967294); AS numbers written in prose are not checked; README.md exists; a banned assistant brand name does not appear.
Not checked: addresses inside binary files (captures, images), and anything the regular expressions below do not recognise.
Exit code 1 if any lab fails. Needs pyyaml and jsonschema."""
import sys, os, re, json, ipaddress
import yaml, jsonschema

NOS_OK = {"nokia_srlinux", "frr", "linux"}
IP4 = re.compile(r"(?<![\d.])(\d{1,3}(?:\.\d{1,3}){3})(?:/\d{1,2})?(?![\d.])")
ASN = re.compile(r"(?:autonomous-system|remote-as|peer-as|router bgp|local-as|prepend)((?:\s+\d+)+)")
ALLOWED_NON_PRIVATE = {"0.0.0.0", "255.255.255.255", "255.255.255.252", "255.255.255.0", "255.255.255.192", "255.255.255.128", "224.0.0.5", "224.0.0.9"}
PRIVATE_V4 = [ipaddress.ip_network(n) for n in ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16")]
DOC_V4 = {ipaddress.ip_network(n): n for n in ("192.0.2.0/24", "198.51.100.0/24", "203.0.113.0/24", "198.18.0.0/15")}
IP6 = re.compile(r"(?<![0-9A-Za-z:.])[0-9A-Fa-f]{0,4}(?::[0-9A-Fa-f]{0,4}){2,7}(?:/\d{1,3})?(?![0-9A-Za-z:])")
ULA = ipaddress.ip_network("fd00::/8"); LL6 = ipaddress.ip_network("fe80::/10"); MC6 = ipaddress.ip_network("ff00::/8")
DOC_V6 = (ipaddress.ip_network("2001:db8::/32"), ipaddress.ip_network("3fff::/20"))

def asn_ok(n): return 64512 <= n <= 65534 or 4200000000 <= n <= 4294967294

def check_v4(a):
    try: ip = ipaddress.ip_address(a)
    except ValueError: return None
    for net, label in DOC_V4.items():
        if ip in net: return f"documentation/benchmark address {a} (in {label})"
    if not any(ip in net for net in PRIVATE_V4): return f"non-RFC1918 address {a}"
    return None

def check_v6(a):
    try: ip = ipaddress.ip_address(a)
    except ValueError: return None
    if any(ip in net for net in DOC_V6): return f"documentation IPv6 address {a}"
    if ip in ULA or ip in LL6 or ip in MC6: return None
    return f"IPv6 address {a} is outside fd00::/8"

def lint(schema, d):
    """d is a lab folder (<d>/<d>.clab.yml, README.md and everything under it are checked) or a single .clab.yml file
    (only that file is checked; name must equal the file name without .clab.yml, except a lighter file named
    <lab>-lite.clab.yml keeps name: <lab> so container names stay clab-<lab>-*)."""
    errs = []; single = d.endswith(".clab.yml")
    if single:
        f = d
        fname = os.path.basename(d)[:-len(".clab.yml")]
        d = os.path.dirname(os.path.abspath(f))
        folder = os.path.basename(d.rstrip("/"))
        if fname.endswith("-lite"):
            name = fname[:-len("-lite")]
            if folder and folder != name:
                errs.append(f"lite file {fname}.clab.yml is not in folder {name}")
        else:
            name = fname
    else:
        name = os.path.basename(d.rstrip("/")); f = os.path.join(d, name + ".clab.yml")
    if not os.path.exists(f): return [f"missing {name}.clab.yml"]
    topo = yaml.safe_load(open(f))
    for e in jsonschema.Draft7Validator(schema).iter_errors(topo): errs.append("schema: " + e.message[:160])
    if topo.get("name") != name: errs.append(f"name {topo.get('name')!r} != folder {name!r}")
    nodes = topo["topology"]["nodes"]; srl = 0
    for n, nd in nodes.items():
        if nd.get("kind") not in NOS_OK: errs.append(f"node {n}: kind {nd.get('kind')} not allowed")
        if nd.get("kind") == "nokia_srlinux": srl += 1
        if "graph-icon" not in (nd.get("labels") or {}): errs.append(f"node {n}: no graph-icon label")
    if srl > 2: errs.append(f"{srl} SR Linux nodes (max 2)")
    v6 = (topo.get("mgmt") or {}).get("ipv6-subnet", "")
    try: v6ok = ipaddress.ip_network(v6, strict=False).subnet_of(ULA)
    except ValueError: v6ok = False
    if not v6ok: errs.append(f"mgmt ipv6-subnet {v6!r} is not inside fd00::/8")
    for root, _, files in ([(d, [], [os.path.basename(f)])] if single else os.walk(d)):
        for fn in files:
            if fn.endswith((".png", ".drawio", ".pcap", ".pcapng")): continue
            p = os.path.join(root, fn); txt = open(p, errors="replace").read()
            if re.search("chat" + "gpt", txt, re.I): errs.append(f"{fn}: contains a banned name")
            for m in IP4.finditer(txt):
                a = m.group(1)
                if a in ALLOWED_NON_PRIVATE: continue
                msg = check_v4(a)
                if msg: errs.append(f"{fn}: {msg}")
            for m in IP6.finditer(txt):
                msg = check_v6(m.group(0).split('/')[0])
                if msg: errs.append(f"{fn}: {msg}")
            for m in ASN.finditer(txt):
                for asn in m.group(1).split():
                    if not asn_ok(int(asn)): errs.append(f"{fn}: AS {asn} not private")
    if not single and not os.path.exists(os.path.join(d, "README.md")): errs.append("no README.md")
    return errs

def main():
    schema = json.load(open(sys.argv[1])); bad = 0
    dirs = []
    for a in sys.argv[2:]:
        if a.endswith(".clab.yml") or os.path.exists(os.path.join(a, os.path.basename(a.rstrip('/')) + ".clab.yml")): dirs.append(a)
        else: dirs += [os.path.join(a, x) for x in sorted(os.listdir(a)) if os.path.isdir(os.path.join(a, x))]
    for d in dirs:
        e = lint(schema, d); bad += bool(e)
        print(("PASS " if not e else "FAIL ") + os.path.basename(d.rstrip("/")).replace(".clab.yml", ""), *(["\n   - " + x for x in e]), sep="")
    sys.exit(1 if bad else 0)
main()
