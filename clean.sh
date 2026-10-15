#!/usr/bin/env bash
# ctf-ingress 의 컨테이너 / 볼륨 / 이미지를 전부 제거한다 — 맥 호스트에서 실행.
# 이름을 ctf-ingress 로만 한정하므로 다른 클러스터(gw-lab 등)는 건드리지 않는다.
# 주의: 볼륨(ctf-docker)에는 내부 kind 노드·이미지가 통째로 들어 있어 함께 사라진다.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
NAME=ctf-ingress
IMAGE=ctf-ingress:latest
VOLUME=ctf-ingress_ctf-docker

echo ">>> 1. 컨테이너 중지·삭제: $NAME"
docker rm -f "$NAME" >/dev/null 2>&1 && echo "   컨테이너 삭제됨" || echo "   컨테이너 없음"

echo ">>> 2. compose 리소스 정리(볼륨·로컬 이미지 포함)"
# 사용자 셸의 compose 가 플래그를 받으면 이 한 줄로 끝난다. 실패해도 아래 단계가 보완한다.
docker compose -f "$HERE/docker-compose.yml" down -v --rmi local >/dev/null 2>&1 \
  && echo "   compose down 완료" || echo "   compose down 생략(아래 개별 삭제로 보완)"

echo ">>> 3. 볼륨 삭제: $VOLUME"
docker volume rm "$VOLUME" >/dev/null 2>&1 && echo "   볼륨 삭제됨" || echo "   볼륨 없음"

echo ">>> 4. 이미지 삭제: $IMAGE"
docker rmi "$IMAGE" >/dev/null 2>&1 && echo "   이미지 삭제됨" || echo "   이미지 없음"

echo ">>> 5. 남은 흔적 확인(아무것도 안 나오면 깨끗)"
docker ps -a  --filter name="^/${NAME}$"  --format '   남은 컨테이너: {{.Names}} ({{.Status}})'
docker volume ls --filter name="^${VOLUME}$" --format '   남은 볼륨: {{.Name}}'
docker images "$IMAGE" --format '   남은 이미지: {{.Repository}}:{{.Tag}}'
echo ">>> 완료 (gw-lab 등 다른 클러스터는 그대로)"
