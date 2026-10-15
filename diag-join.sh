#!/usr/bin/env bash
# 워커 조인 실패 진단 — 전체는 join-fail.log 로, 끝에 짧은 SUMMARY 만 화면에 찍는다.
# 호스트(WSL)에서:  bash diag-join.sh
# 로그 복사 불가 환경이면, 맨 끝 ===SUMMARY=== 아래 몇 줄만 옮겨 적어 주면 된다.
W=ctf-ingress
LOG=join-fail.log; : > "$LOG"
dx(){ docker exec "$W" "$@"; }                 # 래퍼 안에서
dn(){ docker exec "$W" docker exec ctf-worker2 "$@"; }  # 래퍼 안 DinD 의 워커2 안에서

{
echo "## 0 host arch"; uname -m
echo "## 1 wrapper"; docker ps -a --filter "name=${W}" --format '{{.Status}}'
echo "## 2 kind nodes"; dx docker ps -a --format '{{.Names}} {{.Status}}'
echo "## 3 inotify"; dx sysctl fs.inotify.max_user_instances fs.inotify.max_user_watches
echo "## 4 mem (wrapper)"; dx sh -c 'free -m 2>/dev/null | awk "/Mem/{print \$2\"MB total, \"\$7\"MB avail\"}"'
echo "## 5 kubeadm.conf"; dn ls -l /kind/kubeadm.conf
echo "## 6 join rerun"; dn kubeadm join --config /kind/kubeadm.conf --v=5
echo "## 7 kubelet tail"; dn journalctl -u kubelet --no-pager -n 40
echo "## 8 cp 6443"; dn sh -c 'getent hosts ctf-control-plane; (echo >/dev/tcp/ctf-control-plane/6443) 2>&1 && echo TCP6443=OK || echo TCP6443=UNREACHABLE'
} >>"$LOG" 2>&1

# ---- 짧은 요약 추출 ----
arch=$(grep -A1 '## 0' "$LOG" | tail -1)
nodes=$(grep -c 'ctf-' "$LOG")
run=$(grep -A6 '## 2' "$LOG" | grep -c ' Up ')
ino=$(grep -A2 '## 3' "$LOG" | grep -o 'max_user_instances = [0-9]*' | grep -o '[0-9]*')
mem=$(grep -A1 '## 4' "$LOG" | tail -1)
tcp=$(grep -o 'TCP6443=[A-Z]*' "$LOG" | tail -1)
# 조인/ kubelet 에서 가장 의미있는 에러 한 줄
err=$(grep -aiE 'too many open files|timed out|connection refused|no route|cannot|not found|\[ERROR|error execution phase|failed to|permission denied|cgroup|forbidden' "$LOG" | grep -viE 'Flag --|^\s*$' | tail -1 | cut -c1-160)

echo "===SUMMARY (이 아래만 옮겨 적어 주세요)==="
echo "ARCH   : ${arch:-?}"
echo "NODES  : ${run:-0} up / name-hits ${nodes:-0}  (정상=4 up)"
echo "INOTIFY: instances=${ino:-?}  (정상 >=1024)"
echo "MEM    : ${mem:-?}"
echo "CP6443 : ${tcp:-?}"
echo "ERRLINE: ${err:-'(에러 패턴 매치 없음 -> join-fail.log 6~7번 수동 확인)'}"
echo "=========================================="
