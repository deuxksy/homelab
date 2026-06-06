---
title: aria2 Download Manager for Heritage
date: 2026-06-07
status: approved
---

# aria2 Download Manager for Heritage LXC 200

## 개요

Heritage LXC 200에 aria2 기반 범용 다운로드 매니저 추가. Transmission은 토렌트 전용 유지, aria2는 HTTP/HTTPS/FTP/BT 다운로드 담당.

## 아키텍처

```text
클라이언트(Aria2 Explorer/Aria2App) → Tailscale 네트워크 → Heritage LXC:6800 → aria2 RPC → /mnt/data2/downloads/
```

## 구성 요소

| 항목 | 값 |
| :--- | :--- |
| Docker 이미지 | p3terx/aria2-pro:test (daily build) |
| RPC 포트 | 6800 (Tailscale 내부 전용) |
| RPC 인증 | RPC_SECRET 환경변수 |
| 저장 경로 | /mnt/data2/downloads → 컨테이너 /downloads |
| UID/GID | 1000:1000 (호스트 crong 101000 매핑) |
| 설정 | named volume aria2-config:/config (이미지 자동 생성) |
| BT | 활성 (포트 6888 TCP/UDP) |
| Web UI | 없음 (RPC 클라이언트만) |

## 검증 이력

| 검증 | 결과 |
| :--- | :--- |
| rpc-listen-all=false + Docker 포트 매핑 | Blocker → 이미지 기본 true로 해결 |
| aria2.conf env 치환 | 미지원 → 이미지가 env→CLI 자동 변환 |
| hurlenko/aria2 AriaNg 불필요 포함 | Risk → p3terx/aria2-pro로 변경 |
| p3terx/aria2-pro latest 4년 전 | Risk → :test 태그 사용 (daily build) |
| BT 포트 미노출 | Risk → 6888 TCP/UDP 포트 추가 |
| UMASK/TZ/LOG 누락 | Risk → 공식 docker-compose 기반으로 보완 |
