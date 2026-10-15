# 단일 컨테이너 안에 docker(DinD) + kind + kubectl. CTF 래퍼.
FROM docker:27-dind

# 도구: bash, curl, socat(쉘 리스너), ca-certificates
RUN apk add --no-cache bash curl socat ca-certificates

# kubectl + kind (빌드 아키텍처 자동 감지)
RUN set -eux; \
    arch="$(uname -m)"; \
    case "$arch" in x86_64) A=amd64;; aarch64|arm64) A=arm64;; *) A=amd64;; esac; \
    curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/v1.31.0/bin/linux/${A}/kubectl"; \
    chmod +x /usr/local/bin/kubectl; \
    curl -fsSLo /usr/local/bin/kind "https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-${A}"; \
    chmod +x /usr/local/bin/kind

# 비권한 플레이어 사용자 (bastion 쉘용)
RUN adduser -D -h /home/player player

COPY . /ctf
RUN chmod +x /ctf/cluster/entrypoint.sh /ctf/bastion/*.sh

EXPOSE 443 8080
ENTRYPOINT ["/ctf/cluster/entrypoint.sh"]
