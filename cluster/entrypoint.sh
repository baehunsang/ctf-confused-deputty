#!/usr/bin/env bash
# 래퍼 컨테이너 부트스트랩: dockerd -> kind -> ingress-nginx -> app/db/bastion -> 쉘 리스너
set -euo pipefail
log(){ echo "[entrypoint] $*"; }

# 0) inotify 한도 상향 (중첩 kind 필수)
#    중첩된 kindest/node 의 systemd·kubelet·cAdvisor 가 inotify instance 를 대량 사용한다.
#    VM 기본값(fs.inotify.max_user_instances=128)으로는 노드가
#    "inotify_init: too many open files" 로 부팅을 못 끝내 kind 생성이 타임아웃한다.
#    privileged 컨테이너에서 쓰면 공유 커널(Colima VM)에 반영된다.
log "inotify 한도 상향 (max_user_instances=1024)"
sysctl -w fs.inotify.max_user_instances=1024 fs.inotify.max_user_watches=1048576 || \
  log "경고: inotify sysctl 적용 실패(privileged 아님?) — kind 생성이 실패할 수 있음"

# 1) dockerd (DinD)
log "dockerd 기동..."
dockerd-entrypoint.sh dockerd >/var/log/dockerd.log 2>&1 &
for i in $(seq 1 90); do docker info >/dev/null 2>&1 && break; sleep 1; done
docker info >/dev/null 2>&1 || { log "dockerd 기동 실패"; tail -n 50 /var/log/dockerd.log; exit 1; }
log "dockerd ready"

# 멱등: 기존 클러스터 있으면 재사용
if kind get clusters 2>/dev/null | grep -qx ctf; then
  log "기존 kind 클러스터 ctf 재사용"
else
  # 중첩 환경의 systemd 부팅 경쟁(kind #3758) 대비 최대 2회 시도
  for attempt in 1 2; do
    log "kind 클러스터 생성 (시도 $attempt)..."
    if kind create cluster --name ctf --config /ctf/cluster/kind-config.yaml \
         --image "${KIND_NODE_IMAGE:-kindest/node:v1.31.0}" --wait 240s; then
      break
    fi
    log "생성 실패 — 정리 후 재시도"
    kind delete cluster --name ctf || true
    [ "$attempt" = 2 ] && { log "kind 생성 2회 실패. dockerd 로그 말미:"; tail -n 40 /var/log/dockerd.log; exit 1; }
    sleep 5
  done
fi
kubectl wait --for=condition=Ready node --all --timeout=240s

# 2) 노드 라벨: worker1=app, worker2=db, worker3=bastion
kubectl label node ctf-worker  ctf-role=app     --overwrite
kubectl label node ctf-worker2 ctf-role=db      --overwrite
kubectl label node ctf-worker3 ctf-role=bastion --overwrite

# 3) ingress-nginx (control-plane 고정)
log "ingress-nginx 설치..."
kubectl apply -f /ctf/cluster/ingress-nginx.yaml
kubectl -n ingress-nginx patch deploy ingress-nginx-controller \
  -p '{"spec":{"template":{"spec":{"nodeSelector":{"ingress-ready":"true","kubernetes.io/os":"linux"}}}}}' || true
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=240s

# 4) app / db / bastion
log "앱/디비/바스티온 배포..."
kubectl apply -f /ctf/manifests/00-namespaces.yaml
kubectl -n db  create configmap db-src  --from-file=db.py=/ctf/db/db.py   --dry-run=client -o yaml | kubectl apply -f -
kubectl -n app create configmap app-src --from-file=app.py=/ctf/app/app.py --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f /ctf/manifests/10-db.yaml
kubectl apply -f /ctf/manifests/20-app.yaml
kubectl apply -f /ctf/manifests/30-bastion-rbac.yaml
kubectl -n db  rollout status deploy/db  --timeout=180s
kubectl -n app rollout status deploy/app --timeout=180s

# 5) bastion kubeconfig
/ctf/bastion/make-kubeconfig.sh

# 6) 8080 쉘 리스너 (연결마다 shell.sh)
log "bastion 쉘 리스너 :8080"
socat TCP-LISTEN:8080,reuseaddr,fork EXEC:'/ctf/bastion/shell.sh',pty,stderr,setsid,sigint,sane &

cat <<'READY'
============================================================
 CTF ready.
   앱:    curl -k https://localhost:443/user
   쉘:    nc localhost 1337
============================================================
READY
# 컨테이너 유지
tail -f /var/log/dockerd.log
