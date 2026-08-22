# Mimics an IPTV portal whose TLS is too old to negotiate but whose plain
# HTTP works — on the same port, which is the usual arrangement.
import socket, threading, subprocess, sys, os

PORT = 8443
# fatal(2) handshake_failure(40), the alert a server sends when it cannot
# agree on a protocol version or cipher suite with the client.
ALERT = bytes([0x15, 0x03, 0x03, 0x00, 0x02, 0x02, 0x28])

sys.path.insert(0, os.path.dirname(__file__))
import mock_portal  # reuse the request handler
from http.server import BaseHTTPRequestHandler
from io import BytesIO

class Wire(BaseHTTPRequestHandler):
    def __init__(self, data, conn):
        self.rfile = BytesIO(data); self.wfile = conn.makefile('wb')
        self.client_address = ('127.0.0.1', 0); self.requestline = ''
        self.request_version = 'HTTP/1.1'; self.command = ''
        self.handle_one_request()
    def log_message(self, *a): pass
    do_GET = mock_portal.H.do_GET
    _json = mock_portal.H._json

def serve(conn):
    try:
        head = conn.recv(4096, socket.MSG_PEEK)
        if head[:2] == b'\x16\x03':          # TLS ClientHello
            conn.sendall(ALERT); conn.close(); return
        data = conn.recv(65536)
        Wire(data, conn)
    except Exception:
        pass
    finally:
        try: conn.close()
        except Exception: pass

srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(('127.0.0.1', PORT)); srv.listen(16)
while True:
    c, _ = srv.accept()
    threading.Thread(target=serve, args=(c,), daemon=True).start()
