#!/usr/bin/env python3
# session.py HOST PORT COUNT — one TCP session; sends "tick N" every 0.5 s and waits up to 1 s for an answer line ("ok N").
import socket, sys, time
host, port, count = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
t0 = time.monotonic(); s = socket.create_connection((host, port), timeout=2); s.settimeout(1.0)
print(f"t=0.0 s  connected {s.getsockname()[0]}:{s.getsockname()[1]} -> {host}:{port}")
buf = b""
for n in range(1, count + 1):
    t = time.monotonic() - t0
    try:
        s.sendall(f"tick {n}\n".encode())
        while b"\n" not in buf:
            d = s.recv(100)
            if not d: raise ConnectionError("closed by peer")
            buf += d
        line, buf = buf.split(b"\n", 1)
        print(f"t={t:.1f} s  tick {n}: {line.decode()}")
    except (socket.timeout, TimeoutError):
        print(f"t={t:.1f} s  tick {n}: no reply")
    except OSError as e:
        print(f"t={t:.1f} s  tick {n}: {e}"); break
    time.sleep(max(0, n * 0.5 - (time.monotonic() - t0)))
