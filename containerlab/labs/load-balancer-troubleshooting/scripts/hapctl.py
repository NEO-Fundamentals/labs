# Send one command to HAProxy's runtime API (the admin socket /run/haproxy.sock on lb) and print the answer.
# Usage on lb: python3 /neo/scripts/hapctl.py <command ...>   e.g.  python3 /neo/scripts/hapctl.py show servers state pool_web
import socket, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect('/run/haproxy.sock')
s.sendall((' '.join(sys.argv[1:]) + '\n').encode())
out = b''
while True:
    chunk = s.recv(65536)
    if not chunk:
        break
    out += chunk
print(out.decode().rstrip() or '(done)')
