#!/usr/bin/env bash
# socat 연결마다 실행되는 bastion 쉘. player(비권한) 사용자로 떨어뜨려
# 래퍼 컨테이너의 admin kubeconfig(/root/.kube/config) 접근을 막는다.
exec su player -s /bin/bash -c '
export KUBECONFIG=/ctf/bastion/kubeconfig
export PATH=/usr/local/bin:/usr/bin:/bin
cd /home/player 2>/dev/null || cd /tmp
exec /bin/bash --noprofile --norc -i
'
