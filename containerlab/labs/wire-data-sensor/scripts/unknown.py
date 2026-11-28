#!/usr/bin/env python3
"""The unknown host's traffic: a GET /admin to the web server, every two seconds.

It is started by scripts/fault.sh 1 and stopped by scripts/fault.sh 2 (or by resetting the lab).
The server answers 404; the point is that a new device is talking, and asking for a path the
known client does not use.
"""
import sys, time, urllib.error, urllib.request

URL = sys.argv[1] if len(sys.argv) > 1 else "http://10.28.1.20/admin"
while True:
    try:
        urllib.request.urlopen(URL, timeout=2)
    except Exception:
        pass
    time.sleep(2)
