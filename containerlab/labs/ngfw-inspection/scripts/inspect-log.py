#!/usr/bin/env python3
# Translate Suricata's eve.json into the lab's inspect.log / inspect.stats
# so the README commands stay short. Suricata is what inspects and drops.
import json, os, time

EVE = os.environ.get("NEO_EVE", "/var/log/suricata/eve.json")
LOG = "/var/log/inspect.log"
STATS = "/run/inspect.stats"
MODE_FILE = "/run/neo-policy-mode"

seen_flow = set()
passed = 0
dropped = 0
alerts = 0


def mode():
    try:
        return open(MODE_FILE, encoding="utf-8").read().strip() or "ids"
    except OSError:
        return "ids"


def append(line):
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def write_stats():
    rules = 0
    try:
        for line in open("/etc/suricata/rules/neo.rules", encoding="utf-8"):
            if line.strip() and not line.startswith("#"):
                rules += 1
    except OSError:
        pass
    with open(STATS, "w", encoding="utf-8") as f:
        f.write(
            f"mode {mode()}\nrules {rules}\nflows_logged {len(seen_flow)}\n"
            f"alerts {alerts}\ndropped_events {dropped}\n"
        )


def flow_key(ev):
    return (
        ev.get("src_ip"),
        ev.get("src_port"),
        ev.get("dest_ip"),
        ev.get("dest_port"),
        ev.get("proto"),
    )


def flow_line(ev, app, extra):
    src = ev.get("src_ip", "?")
    sp = ev.get("src_port", "?")
    dst = ev.get("dest_ip", "?")
    dp = ev.get("dest_port", "?")
    bits = extra.strip()
    suffix = f" {bits}" if bits else ""
    return f"flow {src}:{sp} -> {dst}:{dp} app={app}{suffix}"


def handle(ev):
    global passed, dropped, alerts
    typ = ev.get("event_type")
    key = flow_key(ev)
    if typ == "http":
        http = ev.get("http") or {}
        host = http.get("hostname") or http.get("http_host") or ""
        extra = f"host={host}" if host else ""
        if key not in seen_flow:
            seen_flow.add(key)
            append(flow_line(ev, "http", extra))
            passed += 1
    elif typ == "tls":
        tls = ev.get("tls") or {}
        sni = tls.get("sni") or ""
        if not sni:
            return
        extra = f"sni={sni}"
        if key not in seen_flow:
            seen_flow.add(key)
            append(flow_line(ev, "tls", extra))
            passed += 1
    elif typ == "ssh":
        if key not in seen_flow:
            seen_flow.add(key)
            append(flow_line(ev, "ssh", ""))
            passed += 1
    elif typ == "alert":
        alerts += 1
        al = ev.get("alert") or {}
        sig = al.get("signature") or "rule"
        action = (al.get("action") or "").lower()
        app = ev.get("app_proto") or "unknown"
        src = ev.get("src_ip", "?")
        tls = ev.get("tls") or {}
        sni = tls.get("sni") or ""
        if app == "tls" and sni and key not in seen_flow:
            seen_flow.add(key)
            append(flow_line(ev, "tls", f"sni={sni}"))
        if action in ("blocked", "dropped") or typ == "drop":
            dropped += 1
            append(
                f"BLOCK {src} app={app} rule \"{sig}\" "
                f"(packet from {src} dropped, flow blocked)"
            )
        elif sig.startswith("alert ") or mode() != "ids":
            append(f"ALERT {src} app={app} rule \"{sig}\": alert")
        else:
            append(
                f"ALERT {src} app={app} rule \"{sig}\": would block (mode ids)"
            )
    elif typ == "drop":
        dropped += 1


def follow():
    os.makedirs(os.path.dirname(STATS), exist_ok=True)
    open(LOG, "a", encoding="utf-8").close()
    write_stats()
    pos = 0
    while True:
        try:
            with open(EVE, encoding="utf-8") as f:
                f.seek(pos)
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        handle(json.loads(line))
                    except ValueError:
                        pass
                pos = f.tell()
        except OSError:
            pass
        write_stats()
        time.sleep(0.2)


if __name__ == "__main__":
    follow()
