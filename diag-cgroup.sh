#!/usr/bin/env bash
# cgroup 계층 + 노드 부팅 실패 맥락. 호스트(WSL)에서:  bash diag-cgroup.sh
W=ctf-ingress
echo "===CG (이 아래만 옮겨 적어 주세요)==="

# 1) 래퍼(docker:dind) 안의 cgroup 버전: cgroup2fs=v2, tmpfs=v1
echo -n "WRAP_CG : "; docker exec "$W" sh -c "stat -fc %T /sys/fs/cgroup 2>&1"
# 2) 래퍼 안 inner dockerd 의 cgroup 드라이버/버전
echo -n "DIND_CG : "; docker exec "$W" sh -c "docker info 2>/dev/null | grep -iE 'Cgroup (Driver|Version)' | tr '\n' ' '"; echo
# 3) 노드 컨테이너가 보는 cgroup 버전
echo -n "NODE_CG : "; docker exec "$W" docker run --rm --entrypoint stat kindest/node:v1.31.0 -fc %T /sys/fs/cgroup 2>&1 | tail -1

echo "-- worker2 부팅 로그: 실패/마운트/cgroup 맥락 (앞뒤 포함) --"
docker exec "$W" docker logs ctf-worker2 2>&1 \
  | grep -niE 'fail|cgroup|mount|undo-mount|systemd|Dependency|too many|cannot|refus' \
  | tail -n 15 | cut -c1-150
echo "====================================="
