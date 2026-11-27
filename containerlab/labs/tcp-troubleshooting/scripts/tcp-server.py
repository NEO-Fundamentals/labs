#!/usr/bin/env python3
"""Tiny TCP test server for the NEO tcp-troubleshooting lab (runs on host-b).
Usage: tcp-server.py <mode> <port>
  serve     accept, send 200000 bytes, then close normally
  noread    accept and never read; with a tiny receive buffer the TCP window closes to zero
  midreset  accept, send 30000 bytes, wait 1 s, then abort the connection with a reset (RST)
  sink      accept and read everything the client sends, until the client closes
"""
import socket, struct, sys, time

mode, port = sys.argv[1], int(sys.argv[2])
s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
if mode == "noread":
    s.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 4096)   # set before listen: accepted sockets inherit it
s.bind(("0.0.0.0", port))
s.listen(16)
held = []
while True:
    c, _ = s.accept()
    if mode == "serve":
        c.sendall(b"x" * 200000)
        c.close()
    elif mode == "noread":
        held.append(c)                      # keep it open, never call recv()
    elif mode == "midreset":
        c.sendall(b"x" * 30000)
        time.sleep(1)
        c.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
        c.close()                           # linger 0 makes close() send a reset instead of a FIN
    elif mode == "sink":
        while c.recv(65536):
            pass
        c.close()
