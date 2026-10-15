#!/usr/bin/env bash
# CP6443 원인 분해 (정정판). 호스트(WSL)에서:  bash diag-net.sh
# 앞 버전의 /dev/tcp 테스트는 dash 에서 항상 실패하는 버그가 있어 bash/kubectl/crictl 로 교체.
# 끝의 ===NET2=== 아래 줄만 옮겨 적으면 된다.
W=ctf-ingress
dx(){ docker exec "$W" "$@"; }
echo "===NET2 (이 아래만 옮겨 적어 주세요)==="

# 1) apiserver 건강: 래퍼의 kubectl 로 직접 조회 (가장 권위있는 신호)
echo -n "HEALTHZ : "; dx kubectl get --raw='/healthz' 2>&1 | head -1
echo -n "NODES   : "; dx kubectl get nodes --no-headers 2>&1 | awk '{printf "%s=%s ",$1,$2} END{print ""}'

# 2) control-plane 안: 정적 파드 컨테이너(apiserver/etcd) 상태
echo "CP_CTRS :"; dx docker exec ctf-control-plane crictl ps -a 2>&1 | grep -Ei 'apiserver|etcd|controller-manager|scheduler' | awk '{print "  "$NF"  "$(NF-2)}' | head -8

# 3) control-plane 안: 6443 리슨 여부 (bash 의 /dev/tcp 로, sh 아님)
echo -n "CP_6443 : "; dx docker exec ctf-control-plane bash -c '(exec 3<>/dev/tcp/127.0.0.1/6443) 2>/dev/null && echo LISTEN_OK || echo LISTEN_FAIL'

# 4) control-plane kubelet 마지막 에러 한 줄
echo -n "CP_KBLT : "; dx docker exec ctf-control-plane bash -c "journalctl -u kubelet --no-pager -n 50 2>/dev/null | grep -iE 'error|fail' | tail -1 | cut -c1-140"

# 5) 워커2 -> control-plane:6443 (bash 로 재측정)
echo -n "W2_6443 : "; dx docker exec ctf-worker2 bash -c '(exec 3<>/dev/tcp/ctf-control-plane/6443) 2>/dev/null && echo OK || echo FAIL'
echo "====================================="
