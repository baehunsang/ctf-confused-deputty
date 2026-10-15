#!/usr/bin/env bash
# CP6443 UNREACHABLE 원인 분해. 호스트(WSL)에서:  bash diag-net.sh
# 끝의 ===NET=== 아래 7줄만 옮겨 적으면 된다.
W=ctf-ingress
echo "===NET (이 아래만 옮겨 적어 주세요)==="

# 1) 래퍼의 kubectl 로 클러스터가 살아있나 (control-plane apiserver 생존 확인)
echo -n "KUBECTL : "; docker exec "$W" kubectl get nodes --no-headers 2>&1 | awk '{print $1"="$2}' | tr '\n' ' '; echo

# 2) control-plane 컨테이너가 kind 네트워크에서 받은 IP
CPIP=$(docker exec "$W" docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' ctf-control-plane 2>&1)
echo "CP_IP   : $CPIP"

# 3) control-plane 안에서 apiserver 가 6443 을 실제로 LISTEN 하나
echo -n "APISRV  : "; docker exec "$W" docker exec ctf-control-plane sh -c '(echo >/dev/tcp/127.0.0.1/6443) 2>/dev/null && echo LISTEN_OK || echo LISTEN_FAIL'

# 4) 워커2 에서 control-plane 이름이 DNS 로 풀리나
echo -n "W2_DNS  : "; docker exec "$W" docker exec ctf-worker2 getent hosts ctf-control-plane 2>&1 | awk '{print $1}' | head -1; 

# 5) 워커2 -> control-plane L3 (ping)
echo -n "W2_PING : "; docker exec "$W" docker exec ctf-worker2 sh -c 'ping -c1 -W2 ctf-control-plane >/dev/null 2>&1 && echo OK || echo FAIL'

# 6) 워커2 -> control-plane:6443 L4 (IP 로 직접)
FIP=$(echo $CPIP | awk '{print $1}')
echo -n "W2_6443 : "; docker exec "$W" docker exec ctf-worker2 sh -c "(echo >/dev/tcp/${FIP}/6443) 2>/dev/null && echo OK || echo FAIL"

# 7) 워커2 가 같은 kind 네트워크에 붙어 있나
echo -n "W2_NET  : "; docker exec "$W" docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' ctf-worker2 2>&1
echo "====================================="
