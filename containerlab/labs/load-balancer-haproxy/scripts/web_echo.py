# A small web server for the pool members. GET /health answers "ok" (the load balancer's health monitor). Any other
# page answers with the server's name, the address the connection came from, and the X-Forwarded-For header.
# Each page request (not the health checks) is logged to standard output. Usage: python3 web_echo.py <name> [port]
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
NAME = sys.argv[1]
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 80

class Handler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def do_GET(self):
        if self.path == '/health':
            body = 'ok\n'
        else:
            xff = self.headers.get('X-Forwarded-For', '-')
            body = f'served by {NAME}; connection from {self.client_address[0]}; X-Forwarded-For: {xff}\n'
            print(f'{self.log_date_time_string()} {NAME} GET {self.path} from {self.client_address[0]} X-Forwarded-For {xff}', flush=True)
        data = body.encode()
        head = f'HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: {len(data)}\r\nConnection: close\r\n\r\n'.encode()
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
