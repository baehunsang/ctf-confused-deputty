#!/usr/bin/env python3
import os
import json
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

DB_URL = os.environ.get("DB_URL", "http://db.db.svc.cluster.local:8080")
DB_PORT = os.environ.get("DB_PORT", "8080")
PORT = int(os.environ.get("PORT", "8080"))


class Handler(BaseHTTPRequestHandler):
    def _json(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/healthz":
            self._json(200, {"ok": True})
            return
        if self.path != "/user":
            self._json(404, {"error": "not found", "path": self.path})
            return
        try:
            req = urllib.request.Request(DB_URL + "/user")
            with urllib.request.urlopen(req, timeout=5) as r:
                body = r.read()
                db_ip = r.headers.get("X-Pod-IP", "")
        except Exception as e:
            self._json(502, {"error": "db unreachable", "detail": str(e)})
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        if db_ip:
            self.send_header("X-Debug-Upstream", "%s:%s" % (db_ip, DB_PORT))
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        return


if __name__ == "__main__":
    print("app listening on :%d (db=%s)" % (PORT, DB_URL), flush=True)
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
