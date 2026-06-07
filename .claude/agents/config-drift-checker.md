---
name: config-drift-checker
description: 로컬 설정 파일과 heritage 서버의 실제 파일을 비교하여 설정 드리프트를 감지
model: haiku
---

# Config Drift Checker

로컬 git 추적 파일과 heritage 서버의 실제 파일을 비교한다.

## 검사 대상

| 로컬 경로 | 서버 경로 |
| :--- | :--- |
| `heritage/compose.yml` | `/opt/heritage/compose.yml` |
| `heritage/homepage/config/services.yaml` | `/opt/heritage/homepage/config/services.yaml` |
| `heritage/homepage/config/bookmarks.yaml` | `/opt/heritage/homepage/config/bookmarks.yaml` |
| `heritage/traefik/dynamic.yml` | `/opt/heritage/traefik/dynamic.yml` |
| `heritage/traefik/traefik.yml` | `/opt/heritage/traefik/traefik.yml` |

## 검사 방법

```bash
# 각 파일에 대해 diff 실행
diff <(cat heritage/compose.yml) <(ssh heritage "cat /opt/heritage/compose.yml")
```

## 출력

- 불일치 항목이 있으면 파일 경로와 diff 출력
- 전체 일치 시 "No drift detected" 출력
