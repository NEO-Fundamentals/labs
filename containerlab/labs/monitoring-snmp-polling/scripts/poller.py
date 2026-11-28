#!/usr/bin/env python3
"""Poll r1's interfaces over SNMPv2c and write a line every interval.

Usage (inside the poller container):
  python3 /neo/scripts/poller.py [--host 10.27.1.1] [--community neo] [--interval 5] [--threshold 20000] [--iface eth2]

Each line is one interface that was asked for (default: eth2, the link toward the host).
A status change to down, or traffic in the interval above the threshold (bytes, in plus out),
prints ALERT. The community string is sent in the clear (SNMPv2c).
"""
import argparse, os, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import snmp

def log(msg, fp):
    line = msg if msg.endswith("\n") else msg + "\n"
    sys.stdout.write(line)
    sys.stdout.flush()
    fp.write(line)
    fp.flush()

def main():
    p = argparse.ArgumentParser(add_help=True)
    p.add_argument("--host", default="10.27.1.1")
    p.add_argument("--community", default="neo")
    p.add_argument("--interval", type=int, default=5)
    p.add_argument("--threshold", type=int, default=20000)
    p.add_argument("--iface", default="eth2")
    p.add_argument("--once", action="store_true", help="print one reading and exit")
    args = p.parse_args()
    fp = open("/var/log/poller.log", "a")
    prev = None
    while True:
        rows = snmp.interfaces(args.host, args.community)
        row = None
        idx = None
        for i, r in rows.items():
            if r.get("ifDescr") == args.iface:
                row, idx = r, i
                break
        ts = time.strftime("%H:%M:%S")
        if row is None:
            log("%s ALERT %s not in the interface list" % (ts, args.iface), fp)
        else:
            oper = snmp.STATUS.get(row.get("ifOperStatus"), row.get("ifOperStatus"))
            inn, out = int(row.get("ifInOctets") or 0), int(row.get("ifOutOctets") or 0)
            first = prev is None
            traffic = 0
            if not first:
                # 32-bit counters may wrap
                din = (inn - prev[0]) % 2**32
                dout = (out - prev[1]) % 2**32
                traffic = din + dout
            if oper != "up":
                log("%s ALERT %s ifOperStatus is %s (ifIndex %s)" % (ts, args.iface, oper, idx), fp)
            elif not first and traffic >= args.threshold:
                log("%s ALERT %s traffic %s bytes in %s s (threshold %s)" % (
                    ts, args.iface, traffic, args.interval, args.threshold), fp)
            elif first:
                log("%s ok    %s %s (first reading, in=%s out=%s)" % (ts, args.iface, oper, inn, out), fp)
            else:
                log("%s ok    %s %s, %s bytes in %s s" % (ts, args.iface, oper, traffic, args.interval), fp)
            prev = (inn, out)
        if args.once:
            return 0
        time.sleep(args.interval)

if __name__ == "__main__":
    sys.exit(main() or 0)
