#!/usr/bin/env python3
"""A tiny SNMPv2c client. No MIB files: you ask for each object by its OID (the number).

Usage:
  python3 /neo/scripts/snmp.py get  <host> <community> <oid>
  python3 /neo/scripts/snmp.py walk <host> <community> <oid>
  python3 /neo/scripts/snmp.py interfaces <host> <community>

SNMPv2c sends the community string in the clear. This tool does the same; a capture of the
poller link will show it. The usual command is snmpwalk; this image does not ship the MIB
name files, so this helper speaks OIDs only.
"""
import random, socket, struct, sys

def _len(n):
    if n < 128:
        return bytes([n])
    b = n.to_bytes((n.bit_length() + 7) // 8, "big")
    return bytes([0x80 | len(b)]) + b

def tlv(tag, data):
    return bytes([tag]) + _len(len(data)) + data

def enc_int(n):
    if n == 0:
        return tlv(0x02, b"\x00")
    length = max(1, (n.bit_length() + 8) // 8)
    return tlv(0x02, n.to_bytes(length, "big", signed=True))

def enc_oid(oid):
    parts = [int(x) for x in oid.lstrip(".").split(".")]
    body = bytes([40 * parts[0] + parts[1]])
    for p in parts[2:]:
        stack = [p & 0x7F]
        p >>= 7
        while p:
            stack.append(0x80 | (p & 0x7F))
            p >>= 7
        body += bytes(reversed(stack))
    return tlv(0x06, body)

def enc_octets(s):
    if isinstance(s, str):
        s = s.encode()
    return tlv(0x04, s)

def enc_seq(items, tag=0x30):
    return tlv(tag, b"".join(items))

def read_len(b, i):
    n = b[i]
    i += 1
    if n < 128:
        return n, i
    c = n & 0x7F
    return int.from_bytes(b[i:i + c], "big"), i + c

def read_tlv(b, i):
    tag = b[i]
    i += 1
    n, i = read_len(b, i)
    return tag, b[i:i + n], i + n

def dec_int(data):
    return int.from_bytes(data, "big", signed=True)

def dec_oid(data):
    first = data[0]
    parts = [first // 40, first % 40]
    n = 0
    for x in data[1:]:
        n = (n << 7) | (x & 0x7F)
        if not (x & 0x80):
            parts.append(n)
            n = 0
    return "." + ".".join(map(str, parts))

def dec_value(tag, data):
    if tag == 0x02:
        return dec_int(data)
    if tag == 0x04:
        if data and all(32 <= c < 127 for c in data):
            return data.decode()
        return data.hex() if data else ""
    if tag == 0x05:
        return None
    if tag == 0x06:
        return dec_oid(data)
    if tag == 0x40:
        return ".".join(str(x) for x in data)
    if tag in (0x41, 0x42, 0x43, 0x46):
        return int.from_bytes(data, "big")
    if tag == 0x80:
        return "noSuchObject"
    if tag == 0x81:
        return "noSuchInstance"
    if tag == 0x82:
        return "endOfMibView"
    return "tag:%02x:%s" % (tag, data.hex())

def request(kind, oid, community, reqid=None):
    varbind = enc_seq([enc_oid(oid), tlv(0x05, b"")])
    pdu = enc_seq([
        enc_int(reqid if reqid is not None else random.randint(1, 0x7FFFFFFF)),
        enc_int(0), enc_int(0),
        enc_seq([varbind]),
    ], tag=0xA0 + kind)
    return enc_seq([enc_int(1), enc_octets(community), pdu])

def parse_response(pkt):
    _tag, body, _ = read_tlv(pkt, 0)
    i = 0
    _t, _ver, i = read_tlv(body, i)
    _t, _comm, i = read_tlv(body, i)
    _t, pdu, i = read_tlv(body, i)
    j = 0
    _t, _reqid, j = read_tlv(pdu, j)
    _t, err, j = read_tlv(pdu, j)
    _t, _eidx, j = read_tlv(pdu, j)
    _t, vbs, j = read_tlv(pdu, j)
    k = 0
    results = []
    while k < len(vbs):
        _t, vb, k = read_tlv(vbs, k)
        u = 0
        _t, oidb, u = read_tlv(vb, u)
        tag, val, u = read_tlv(vb, u)
        results.append((dec_oid(oidb), dec_value(tag, val), tag))
    return dec_int(err), results

def query(addr, community, oid, kind=0, timeout=2.0, port=161):
    if not oid.startswith("."):
        oid = "." + oid
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(timeout)
    try:
        sock.sendto(request(kind, oid, community), (addr, port))
        data, _ = sock.recvfrom(65535)
    finally:
        sock.close()
    return parse_response(data)

def walk(addr, community, prefix, timeout=2.0):
    oid = prefix if prefix.startswith(".") else "." + prefix
    root_oid = oid
    out = []
    while True:
        err, results = query(addr, community, oid, kind=1, timeout=timeout)
        if err or not results:
            break
        next_oid, val, tag = results[0]
        if tag == 0x82 or not (next_oid == root_oid or next_oid.startswith(root_oid + ".")):
            break
        out.append((next_oid, val))
        oid = next_oid
    return out

# Useful OIDs (SNMPv2-MIB and IF-MIB). The last number of an interface OID is the ifIndex.
OID = {
    "sysDescr": ".1.3.6.1.2.1.1.1.0",
    "sysObjectID": ".1.3.6.1.2.1.1.2.0",
    "sysUpTime": ".1.3.6.1.2.1.1.3.0",
    "sysContact": ".1.3.6.1.2.1.1.4.0",
    "sysName": ".1.3.6.1.2.1.1.5.0",
    "sysLocation": ".1.3.6.1.2.1.1.6.0",
    "ifDescr": ".1.3.6.1.2.1.2.2.1.2",
    "ifAdminStatus": ".1.3.6.1.2.1.2.2.1.7",
    "ifOperStatus": ".1.3.6.1.2.1.2.2.1.8",
    "ifInOctets": ".1.3.6.1.2.1.2.2.1.10",
    "ifOutOctets": ".1.3.6.1.2.1.2.2.1.16",
}

STATUS = {1: "up", 2: "down", 3: "testing", 4: "unknown", 5: "dormant", 6: "notPresent", 7: "lowerLayerDown"}

def get(addr, community, oid):
    err, results = query(addr, community, oid, kind=0)
    if err or not results:
        raise RuntimeError("SNMP get failed (error %s)" % err)
    return results[0][1]

def interfaces(addr, community):
    rows = {}
    for key in ("ifDescr", "ifAdminStatus", "ifOperStatus", "ifInOctets", "ifOutOctets"):
        for oid, val in walk(addr, community, OID[key]):
            idx = int(oid.split(".")[-1])
            rows.setdefault(idx, {})[key] = val
    return rows

def main(argv):
    if len(argv) < 2 or argv[1] in ("-h", "--help"):
        print(__doc__.strip(), file=sys.stderr)
        return 2
    cmd = argv[1]
    if cmd == "get" and len(argv) == 5:
        host, comm, oid = argv[2], argv[3], argv[4]
        if oid in OID:
            oid = OID[oid]
        err, results = query(host, comm, oid, kind=0)
        if err or not results:
            print("error %s" % err, file=sys.stderr)
            return 1
        print("%s = %s" % results[0][:2])
        return 0
    if cmd == "walk" and len(argv) == 5:
        host, comm, oid = argv[2], argv[3], argv[4]
        if oid in OID:
            oid = OID[oid]
        for o, v in walk(host, comm, oid):
            print("%s = %s" % (o, v))
        return 0
    if cmd == "interfaces" and len(argv) == 4:
        host, comm = argv[2], argv[3]
        print("idx  name    admin  oper     in-octets  out-octets")
        rows = interfaces(host, comm)
        for idx in sorted(rows):
            r = rows[idx]
            print("%-4s %-7s %-6s %-8s %10s %11s" % (
                idx, r.get("ifDescr", "?"),
                STATUS.get(r.get("ifAdminStatus"), r.get("ifAdminStatus")),
                STATUS.get(r.get("ifOperStatus"), r.get("ifOperStatus")),
                r.get("ifInOctets", "?"), r.get("ifOutOctets", "?")))
        return 0
    print(__doc__.strip(), file=sys.stderr)
    return 2

if __name__ == "__main__":
    sys.exit(main(sys.argv))
