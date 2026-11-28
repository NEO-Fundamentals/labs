#!/usr/bin/env python3
# web_tls.py - the server's HTTPS site for the lab: the same files as the HTTP site (/srv/www), on port 443, with a
# self-signed certificate for *.lab.test that the server makes for itself at deploy (so clients use curl -k).
import functools, http.server, ssl
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory="/srv/www")
srv = http.server.ThreadingHTTPServer(("0.0.0.0", 443), handler)
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain("/etc/neo/web.crt", "/etc/neo/web.key")
# The TLS handshake runs in each connection's own thread, so one stalled client cannot hold up the others.
srv.socket = ctx.wrap_socket(srv.socket, server_side=True, do_handshake_on_connect=False)
srv.serve_forever()
