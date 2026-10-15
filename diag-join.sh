#!/usr/bin/env bash
# 워커 조인 실패 진단 캡처. 호스트(다른 컴퓨터)에서 실행:  bash diag-join.sh
# 래퍼 컨테이너 이름
W=ctf-ingress
echo "===== 0. 호스트 아키텍처 ====="; uname -m
echo "===== 1. 래퍼 컨테이너 상태 ====="; docker ps -a --filter "name=${W}" --format '{{.Names}}\t{{.Status}}'
echo "===== 2. 래퍼 안 DinD 의 kind 노드 목록 ====="
docker exec "$W" docker ps -a --format '{{.Names}}\t{{.Status}}' 2>&1
echo "===== 3. inotify 현재값 (래퍼 공유 커널) ====="
docker exec "$W" sysctl fs.inotify.max_user_instances fs.inotify.max_user_watches 2>&1
echo "===== 4. control-plane kubeadm.conf 존재 확인 ====="
docker exec "$W" docker exec ctf-worker2 ls -l /kind/ 2>&1 | grep -i kubeadm
echo "===== 5. 워커2에서 kubeadm join 재실행 (실제 에러 전문) ====="
docker exec "$W" docker exec ctf-worker2 kubeadm join --config /kind/kubeadm.conf --v=6 2>&1 | tail -n 60
echo "===== 6. 워커2 kubelet 상태/로그 말미 ====="
docker exec "$W" docker exec ctf-worker2 systemctl status kubelet --no-pager 2>&1 | tail -n 15
docker exec "$W" docker exec ctf-worker2 journalctl -u kubelet --no-pager 2>&1 | tail -n 40
echo "===== 7. 워커2 -> control-plane(6443) 접근성 ====="
docker exec "$W" docker exec ctf-worker2 sh -c 'getent hosts ctf-control-plane; (echo > /dev/tcp/ctf-control-plane/6443) 2>&1 && echo "6443 OK" || echo "6443 UNREACHABLE"' 2>&1
echo "===== 8. 래퍼 dockerd 로그 말미 ====="
docker exec "$W" tail -n 30 /var/log/dockerd.log 2>&1
