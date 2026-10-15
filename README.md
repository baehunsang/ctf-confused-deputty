# CTF: Ingress, 두 번째 정문 (Confused Deputy)

## 구성

```
control-plane  : ingress-nginx 컨트롤러
worker1 (app)  : ns app  
worker2 (db)   : ns db   
worker3 (bastion): ns bastion
```


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
