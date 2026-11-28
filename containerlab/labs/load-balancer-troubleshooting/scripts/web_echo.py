# A small web server for the pool members (the NEO-22 one, plus a 404 page and a "broken application" mode).
# GET /health answers "ok" (the load balancer's health monitor). GET / answers with the server's name, the address the
# connection came from and the X-Forwarded-For header. Any other page answers 404 Not Found.
# With --broken, GET / answers 500 (the application fails) while /health still answers "ok" (the process runs).
# Each request for / is logged to standard output. Usage: python3 web_echo.py <name> [port] [--broken]
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
args = [a for a in sys.argv[1:] if not a.startswith('--')]
NAME = args[0]
PORT = int(args[1]) if len(args) > 1 else 80
BROKEN = '--broken' in sys.argv

class Handler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def do_GET(self):
        xff = self.headers.get('X-Forwarded-For', '-')
        if self.path == '/health':
            status, body = '200 OK', 'ok\n'
        elif self.path == '/' and BROKEN:
            status, body = '500 Internal Server Error', f'application error on {NAME}: database unavailable\n'
        elif self.path == '/':
            status, body = '200 OK', f'served by {NAME}; connection from {self.client_address[0]}; X-Forwarded-For: {xff}\n'
        else:
            status, body = '404 Not Found', f'not found: {self.path}\n'
        if self.path == '/':
            print(f'{self.log_date_time_string()} {NAME} GET / from {self.client_address[0]} X-Forwarded-For {xff} -> {status[:3]}', flush=True)
        data = body.encode()
        head = f'HTTP/1.1 {status}\r\nContent-Type: text/plain\r\nContent-Length: {len(data)}\r\nConnection: close\r\n\r\n'.encode()
        try:  # one write for the whole answer; a health check may close the connection as soon as it has read it
            self.wfile.write(head + data)
        except (ConnectionResetError, BrokenPipeError):
            pass
        self.close_connection = True

    def log_message(self, *args):
        pass

class Server(ThreadingHTTPServer):
    def handle_error(self, request, client_address):  # a peer that resets the connection is not an error worth a traceback
        if not isinstance(sys.exc_info()[1], (ConnectionResetError, BrokenPipeError)):
            super().handle_error(request, client_address)

Server(('0.0.0.0', PORT), Handler).serve_forever()
