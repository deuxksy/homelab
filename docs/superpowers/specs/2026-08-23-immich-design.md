---
title: Immich Photo Management for Heritage
date: 2026-08-23
status: approved
---

# Immich Photo Management for Heritage LXC 200

## 개요

Heritage LXC 200에 Immich v3 풀스택(server/ML/PostgreSQL/Valkey)을 추가하고, aria2 다운로드 이미지(`/mnt/data2/torrent/downloads/aria`)를 External Library로 열람. RAM 확보를 위해 moni VM 102를 중지하되, 하드웨어 모니터링 대시보드 Pulse는 heritage로 이전해 유지한다.

## 배경 — 리소스 재배분

walle (Intel N100 4코어, 7.5GB RAM)는 현재 압박 상태(host 여유 1.7GB, swap 2.3GB 사용). moni VM은 PatchMon/Cockpit 불필요화 + Docker daemon 다운 상태 → VM 전체를 중지해 RAM 4GB를 회수한다. Pulse(하드웨어 모니터링)만 heritage로 이전한다.

| 항목 | 변경 | 효과 |
| :--- | :--- | :--- |
| moni VM 102 | `started = false` (중지, disk 보존) | RAM 4096MB 회수. Cockpit/PatchMon 폐기 |
| Pulse | moni → heritage 이전 (volume 마이그레이션) | 하드웨어 모니터링 유지 (+~100MB) |
| heritage LXC 200 | cores 2→4, memory 1536→4096, swap 512→1024 | Immich 풀스택 + Pulse 여유 |

현재 heritage는 5컨테이너로 1.2GB + swap 소진 상태에서 운영 중.

## 아키텍처

```text
클라이언트 → https://heritage.bun-bull.ts.net:2283 (Tailscale Serve TLS 종료)
         → immich-server:2283 (127.0.0.1 loopback)
         → immich-machine-learning:3003 / immich-postgres:5432 / immich-valkey:6379 (내부)

클라이언트 → https://heritage.bun-bull.ts.net:10000 → pulse:7655 (127.0.0.1 loopback)

External Library: /mnt/data2/torrent/downloads/aria --:ro--> immich-server /mnt/aria
```

Immich는 subpath 호스팅 미지원 → Caddy(443→9080) 체인과 별도로 Tailscale Serve 포트 2283 진입점을 둔다. Pulse도 동일 방식으로 10000을 heritage Tailscale Serve에 추가한다.

## 구성 요소

`heritage/compose.yml`에 추가 (공식 docker-compose.yml 기반, 2026-08-23 검증):

| 서비스 | 이미지 | 포트 | mem_limit | 비고 |
| :--- | :--- | :--- | :--- | :--- |
| immich-server | ghcr.io/immich-app/immich-server:`v3.1.0` | 127.0.0.1:2283 | 1g | web 통합, `${UPLOAD_LOCATION}:/data` + `/mnt/data2/torrent/downloads/aria:/mnt/aria:ro` |
| immich-machine-learning | ghcr.io/immich-app/immich-machine-learning:`v3.1.0` | 내부 3003 | 1.5g | model-cache named volume, CPU 추론 |
| immich-valkey | docker.io/valkey/valkey:9 (digest pin) | 내부 6379 | 128m | 공식 compose가 Redis→Valkey 9 전환 |
| immich-postgres | ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0 (digest pin) | 내부 5432 | 768m | shm_size 128mb, `DB_DATA_LOCATION=./postgres` |
| pulse | rcourtman/pulse:latest | 127.0.0.1:7655 | 512m | moni volume `pulse_data` 이관 (admin/PVE 토큰 보존) |

- 이미지 태그: immich-server/ML은 구현 시점 최신 안정 릴리스로 pin (예: v3.x.y). valkey/postgres는 공식 digest 그대로 pin
- depends_on: server → valkey, postgres. healthcheck는 공식 기본값 유지

## 스토리지

| 위치 | 용도 | 근거 |
| :--- | :--- | :--- |
| `/mnt/data1/immich` | UPLOAD_LOCATION — 업로드 원본 + 썸네일 | 대용량 증가 대비 (data1 497GB 여유). LXC에 이미 mp0 마운트 |
| `/opt/heritage/postgres` | DB_DATA_LOCATION | VectorDB는 네트워크 스토리지 지원 안 함. rootfs 50G |
| named volume `model-cache` | ML 모델 캐시 | 재시작 시 재다운로드 방지 |

## 시크릿

`heritage/.env.sops`에 키 6개 추가 (기존 binary blob 패턴 유지, playbook이 전체 복호화):

```text
UPLOAD_LOCATION=/mnt/data1/immich
DB_DATA_LOCATION=./postgres
IMMICH_VERSION=<릴리스 pin>
DB_PASSWORD=<openssl rand -base64 24 | tr -dc A-Za-z0-9>  # 특수문자 금지(공식 권고)
DB_USERNAME=postgres
DB_DATABASE_NAME=immich
```

## 배포 절차

1. **Pulse 데이터 이관 (moni 중지 전)**: moni `/var/lib/docker/volumes/pulse_data` tar 아카이브 → heritage 동일 경로에 복원 (sudo tar, 소유권 보존). admin 계정/PVE 토큰 보존
2. **OpenTofu**: `cockpit.tf` started=false, `variables.tf` heritage 리소스 증설 → `tofu apply` (LXC memory/cores는 cgroup hot-resize, 재시작 불필요 예상)
3. **Ansible**: compose.yml/.env.sops 변경 후 `ansible-playbook playbooks/heritage.yml` — 기존 rsync+복호화+compose up 라인 재사용. Tailscale Serve 태스크에 2283(immich), 10000(pulse) 추가 (reset 기반 재구성, 443→9080 유지)
4. **수동 1회 (IaC 밖)**: Admin UI → External Libraries → 라이브러리 생성 (import path `/mnt/aria`) → 스캔 트리거

Homepage 갱신: `services.yaml`에 Immich/Pulse 항목 추가, `docker.yaml`에서 `moni-docker` 항목 제거 (moni 정지로 인한 데드 엔트리 방지).

## 검증 체크리스트

1. `pct config 200` — cores 4 / memory 4096 확인 + `qm list` moni stopped
2. `docker compose ps` — immich 4컨테이너 + pulse healthy
3. heritage 내부 `curl -s -o /dev/null -w "%{http_code}" http://localhost:2283` → 200, `http://localhost:7655/api/health` → 200
4. `tailscale serve status` — 443→9080 + 2283 + 10000 존재
5. 브라우저: `https://heritage.bun-bull.ts.net:2283` 로딩 → admin 계정 생성 → external library 스캔 → aria 이미지 표시. `https://heritage.bun-bull.ts.net:10000` → 기존 Pulse 계정 로그인 + walle 노드 데이터 표시 확인
6. `free -h` — heritage(host 기준) 메모리 여유 확인

## 위험 및 롤백

- **moni 재기동 시 RAM 재부족**: CLAUDE.md Gotchas에 명시. 재기동하려면 heritage 축소 or Immich ML 중지 필요
- **Pulse 이관 실패**: fresh 배포 후 UI setup wizard로 재설정 (admin 생성 + PVEAuditor API 토큰 수동 재입력). 토큰 값은 moni DB에만 있으므로 이관 성공 여부가 분기점
- **초기 인덱싱 부하**: aria 볼륨 전체 ML 추론은 N100 CPU로 수일. 백그라운드 job이며 mem_limit로 스파이크 완충
- **썸네일 용량**: 이미지 수에 비례 (data1 여유 497GB로 흡수)
- **롤백**: `git revert` + `tofu apply` (moni 재기동, heritage 원 사양 복원) + `docker compose down` (DB volume `./postgres`는 보존되므로 재배포 시 데이터 유지)

## 검증 이력

| 검증 | 결과 |
| :--- | :--- |
| 공식 compose 원본 (v3.1.0 release 아티팩트) | cache 컨테이너 Valkey 9 + digest pin 확인, DB VectorChord 이미지 확인 |
| External Library 공식 문서 | `:ro` 마운트 + Admin UI 등록 + 스캔 트리거 방식 확인 |
| subpath 리버스 프록시 | 미지원 확인 → 전용 포트 2283 필요 |
| walle/heritage/moni 실측 (2026-08-23) | host 여유 1.7GB·swap 2.3GB, heritage swap 소진, moni 실사용 579MB·Docker 다운, Cockpit만 active |
| moni 의존성 스윕 (2026-08-23) | 백업 작업(jobs.cfg)/크론 없음, 외부 의존은 heritage Homepage 위젯 1개(이미 데드)뿐 |
| Tailscale serve 문법 (heritage v1.102.2) | `--bg 2283` 포트 지정 방식 확인, 현재 443→9080 단일 구성 |
