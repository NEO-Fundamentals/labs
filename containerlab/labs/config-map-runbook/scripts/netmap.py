# NEO-29 lab mapper (our own teaching script, not a product). Reads device configs written as
# `ip -batch` lines (configs/<device>.conf) and builds a map from them alone:
#   links  : two interfaces whose addresses share a subnet are neighbours
#   path   : hop by hop from a source host to a destination address, longest prefix match
#            on each device's configured routes (connected subnets count as routes)
import ipaddress as ip, pathlib, sys
def load(d):
    devs = {}
    for f in sorted(pathlib.Path(d).glob("*.conf")):
        ifs, routes = [], []
        for ln in f.read_text().splitlines():
            w = ln.split()
            if w[:2] == ["addr", "add"]:
                ifs.append((w[4], ip.ip_interface(w[2])))
            elif w[:2] == ["route", "add"]:
                dst = ip.ip_network("0.0.0.0/0" if w[2] == "default" else w[2])
                routes.append((dst, ip.ip_address(w[4])))
        devs[f.stem] = dict(ifs=ifs, routes=routes)
    return devs
def links(devs):
    seen = []
    names = list(devs)
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            for ia, xa in devs[a]["ifs"]:
                for ib, xb in devs[b]["ifs"]:
                    if xa.network == xb.network:
                        seen.append(f"{a} {ia} {xa.ip} <-> {b} {ib} {xb.ip}   {xa.network}")
    return seen
def owner(devs, addr):
    for n, d in devs.items():
        for _, x in d["ifs"]:
            if x.ip == addr: return n
def lookup(d, addr):
    best = None
    for _, x in d["ifs"]:
        if addr in x.network and (best is None or x.network.prefixlen > best[0].prefixlen):
            best = (x.network, None)
    for net, gw in d["routes"]:
        if addr in net and (best is None or net.prefixlen > best[0].prefixlen):
            best = (net, gw)
    return best
def path(devs, src, dst):
    addr = ip.ip_address(dst); here = src; out = []
    for _ in range(8):
        if any(x.ip == addr for _, x in devs[here]["ifs"]):
            out.append(f"{here}: is {addr}  -> arrived"); return out
        b = lookup(devs[here], addr)
        if b is None:
            out.append(f"{here}: no route to {addr}  -> path breaks here"); return out
        if b[1] is None:
            nxt = owner(devs, addr)
            out.append(f"{here}: {b[0]} connected -> {nxt or 'unknown device'}")
            if nxt is None: return out
            here = nxt
        else:
            nxt = owner(devs, b[1])
            out.append(f"{here}: {b[0]} via {b[1]} -> {nxt or 'unknown device'}")
            if nxt is None: return out
            here = nxt
    return out
if __name__ == "__main__":
    cmd, d = sys.argv[1], sys.argv[2]
    devs = load(d)
    if cmd == "links":
        print("\n".join(links(devs)))
    elif cmd == "path":
        print("\n".join(path(devs, sys.argv[3], sys.argv[4])))
