# CTF: Ingress, 두 번째 정문 (Confused Deputy)

## 구성

```
control-plane  : ingress-nginx 컨트롤러
worker1 (app)  : ns app  
worker2 (db)   : ns db   
worker3 (bastion): ns bastion
```


## 사전 준비 — NCP(Naver Cloud Platform) 서버 기준

### 스토리지 요건 (디스크 30GB 이상)

이 CTF는 단일 컨테이너 안에서 kind 4노드 + ingress-nginx + 앱/디비 이미지를
DinD 볼륨(`/var/lib/docker`)에 전부 담는다. 노드 이미지(`kindest/node`)·컨트롤러·
앱 이미지와 docker 레이어가 누적되므로 **빈 디스크 30GB 이상**을 확보해야 한다.
NCP 서버 기본 디스크가 부족하면 블록 스토리지를 붙여 docker data-root 를 옮긴다.

```bash
# (선택) 추가 블록 스토리지를 /mnt/data 에 마운트한 경우 docker 데이터 경로 이동
sudo systemctl stop docker
sudo mkdir -p /mnt/data/docker
echo '{ "data-root": "/mnt/data/docker" }' | sudo tee /etc/docker/daemon.json
sudo rsync -aP /var/lib/docker/ /mnt/data/docker/
sudo systemctl start docker
docker info | grep "Docker Root Dir"   # /mnt/data/docker 확인
```

### Docker 설치 (Ubuntu Server 기준)

```bash
# 1) 의존성
sudo apt-get update
sudo apt-get install -y ca-certificates curl

# 2) Docker 공식 GPG 키
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# 3) 저장소 등록
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 4) 엔진 + compose 플러그인 설치
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 5) 비root 로 docker 사용 (적용하려면 재로그인)
sudo usermod -aG docker "$USER"

# 6) 확인
docker version && docker compose version
```

Rocky/CentOS 계열이면 위 2~4단계 대신:

```bash
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
```

> NCP ACG(방화벽)에서 SSH 22, 앱 443, bastion 쉘 1337 포트를 인바운드 허용해야 외부에서 접근된다.

## 띄우기

```
docker compose up --build
```

최초 1회는 이미지 pull 로 수 분 걸린다. 다음 두 줄이 보이면 준비 완료다.

```
 앱:    curl -k https://localhost:443/user
 쉘:    nc localhost 1337
```

## 너에게 주어진 것

권한 확인: `kubectl auth can-i --list -n bastion`
앱이 돌아가는 클러스터와 동일한 클러스터의 제한된 namespace에 대해 kubectl할 수 있는 권한
app, db의 소스코드

flag{placeholder}는 플래그 아님


hint
1. 내 ns에선 Ingress를 만들 수 있다
2. EndpointSlice에 들어갈 수 있는 ip는 자기 리소스만일까?

## 목표

ns `db` 의 `/flag` 가 돌려주는 값을 읽어라. 플래그는 `flag{...}` 형식이다.


풀이는 `SOLUTION.md` 에 있다(먼저 직접 풀어보길 권한다).
