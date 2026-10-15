#!/usr/bin/env bash
# bastion player ServiceAccount 용 kubeconfig 를 생성한다 — 래퍼 컨테이너 내부에서 실행.
set -euo pipefail
OUT=/ctf/bastion/kubeconfig
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CADATA=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
TOKEN=$(kubectl -n bastion create token player --duration=24h)
cat > "$OUT" <<EOF
apiVersion: v1
kind: Config
clusters:
- name: ctf
  cluster:
    server: ${SERVER}
    certificate-authority-data: ${CADATA}
contexts:
- name: player
  context:
    cluster: ctf
    namespace: bastion
    user: player
current-context: player
users:
- name: player
  user:
    token: ${TOKEN}
EOF
chmod 644 "$OUT"
echo "kubeconfig written: $OUT (server=$SERVER)"
