#!/usr/bin/env python3
"""db 서버 — ns db. API 엔드포인트 /user, /flag 를 가진다.
개발 중 디버그용으로 응답에 자신의 Pod IP 를 X-Pod-IP 헤더로 실어 보낸다(제거 누락).
이 헤더가 app 을 거쳐 외부로 새어 나가 CTF 유출 경로가 된다."""
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
        # [개발 잔재] 자신의 Pod IP 를 디버그 헤더로 노출 — 운영 전 제거했어야 함
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
