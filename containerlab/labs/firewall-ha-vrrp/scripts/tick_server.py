#!/usr/bin/env python3
# tick_server.py ADDR PORT — answers each line "tick N" with "ok N"; logs each connection.
import socket, sys, threading
def serve(c, a):
    print(f"session from {a[0]}:{a[1]}", flush=True); f = c.makefile("rb")
    try:
        for line in f:
            c.sendall(b"ok " + line.split()[-1] + b"\n")
        print(f"session from {a[0]}:{a[1]} closed", flush=True)
    except OSError as e:
        print(f"session from {a[0]}:{a[1]} ended: {e}", flush=True)
s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1); s.bind((sys.argv[1], int(sys.argv[2]))); s.listen()
while True:
    c, a = s.accept(); threading.Thread(target=serve, args=(c, a), daemon=True).start()
