#!/usr/bin/env python3
# Accepts TCP connections on a port and never sends anything: the SSH client waits for a banner
# that never comes ("Connection timed out during banner exchange"). Used by: faults.sh banner on
import socket, sys
port = int(sys.argv[1]) if len(sys.argv) > 1 else 22
s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("0.0.0.0", port)); s.listen(16)
held = []
while True:
    c, _ = s.accept(); held.append(c)   # keep the connection open, say nothing
