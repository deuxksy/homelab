---
name: heritage-deploy
description: heritage compose/config 파일을 서버에 배포하고 docker compose 재시작
disable-model-invocation: true
---

# Heritage Deploy

heritage LXC 서버에 compose 설정을 배포하고 서비스를 재시작한다.

## Steps

1. 변경된 파일 확인: `compose.yml`, `homepage/config/*`, `traefik/*`
2. `scp`로 heritage 서버에 복사
3. `ssh heritage "cd /opt/heritage && docker compose up -d --remove-orphans"` 실행
4. `ssh heritage "docker ps --format 'table {{.Names}}\t{{.Status}}'"`로 상태 확인
5. 필요시 `curl -s -o /dev/null -w "%{http_code}" https://heritage.bun-bull.ts.net/`로 접속 확인

## Commands

```bash
# 파일 배포
scp /Users/crong/git/homelab/heritage/compose.yml heritage:/opt/heritage/compose.yml
scp /Users/crong/git/homelab/heritage/homepage/config/services.yaml heritage:/opt/heritage/homepage/config/services.yaml
scp /Users/crong/git/homelab/heritage/homepage/config/bookmarks.yaml heritage:/opt/heritage/homepage/config/bookmarks.yaml

# 재시작
ssh heritage "cd /opt/heritage && docker compose up -d --remove-orphans"

# 상태 확인
ssh heritage "docker ps --format 'table {{.Names}}\t{{.Status}}'"
```
