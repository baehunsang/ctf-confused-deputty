#!/usr/bin/env python3
import os
import json
from http.server import BaseHTTPRequestHandler, HTTPServer

POD_IP = os.environ.get("POD_IP", "0.0.0.0")
FLAG = os.environ.get("FLAG", "flag{placeholder}")
PORT = int(os.environ.get("PORT", "8080"))

USERS = [
    {"id": 1, "name": "alice", "role": "user"},
    {"id": 2, "name": "bob", "role": "admin"},
]


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("X-Pod-IP", POD_IP)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/user":
            self._send(200, {"source": "db", "users": USERS})
        elif self.path == "/flag":
            self._send(200, {"flag": FLAG})
        elif self.path == "/healthz":
            self._send(200, {"ok": True})
        else:
            self._send(404, {"error": "not found", "path": self.path})

    def log_message(self, *args):
        return


if __name__ == "__main__":
    print("db listening on :%d (pod_ip=%s)" % (PORT, POD_IP), flush=True)
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
