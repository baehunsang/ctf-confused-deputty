#!/usr/bin/env bash
# 워커 노드 컨테이너가 왜 죽는지. 호스트(WSL)에서:  bash diag-node.sh
W=ctf-ingress
echo "===NODE (이 아래만 옮겨 적어 주세요)==="
echo "-- 노드별 상태/종료코드/재시작횟수 --"
docker exec "$W" docker ps -a --format '{{.Names}} {{.Status}}' 2>&1 | grep '^ctf-'
for N in ctf-control-plane ctf-worker ctf-worker2 ctf-worker3; do
  S=$(docker exec "$W" docker inspect -f '{{.State.Status}} exit={{.State.ExitCode}} restarts={{.RestartCount}} oom={{.State.OOMKilled}}' "$N" 2>&1)
  echo "  $N : $S"
done
echo "-- worker2 컨테이너 로그 마지막 15줄 (종료 사유) --"
docker exec "$W" docker logs --tail 15 ctf-worker2 2>&1 | cut -c1-150
echo "-- 래퍼 안 dmesg 의 OOM/kill 흔적 --"
docker exec "$W" sh -c "dmesg 2>/dev/null | grep -iE 'oom|killed process|memory' | tail -3 | cut -c1-150"
echo "====================================="
