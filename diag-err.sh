#!/usr/bin/env bash
# 조인 실패의 '진짜 에러 문장'만 뽑는다. 호스트(WSL)에서:  bash diag-err.sh
W=ctf-ingress
echo "===ERR (이 아래만 옮겨 적어 주세요)==="
echo "-- kubeadm join 마지막 12줄 --"
docker exec "$W" docker exec ctf-worker2 kubeadm join --config /kind/kubeadm.conf --v=2 2>&1 \
  | grep -vE '^\s*$' | tail -n 12 | cut -c1-150
echo "-- worker2 kubelet 에러 2줄 --"
docker exec "$W" docker exec ctf-worker2 bash -c \
  "journalctl -u kubelet --no-pager -n 80 2>/dev/null | grep -iE 'error|fail|timed out|refused|cgroup|swap' | tail -2 | cut -c1-150"
echo "====================================="
