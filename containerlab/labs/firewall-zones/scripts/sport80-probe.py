# Run on host-b (outside). Opens a NEW connection to host-a (inside) port 8080, using SOURCE port 80.
# A stateless "allow anything from port 80 back in" rule cannot tell this from a reply; a stateful firewall can.
# Usage: python3 /neo/scripts/sport80-probe.py [source address, default 10.13.2.21]
import socket, sys
src = sys.argv[1] if len(sys.argv) > 1 else "10.13.2.21"
s = socket.socket(); s.settimeout(3)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind((src, 80))
try:
    s.connect(("10.13.1.10", 8080))
    s.sendall(b"GET / HTTP/1.0\r\nHost: 10.13.1.10\r\n\r\n")
    print("NEW connection from source port 80 got through; reply:", s.recv(200).split(b"\r\n")[0].decode())
except OSError as e:
    print("no connection (blocked):", e)
