# Caddy Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Traefik을 Caddy로 교체하여 proxy_redirect 지원 (base path 미지원 앱 대응)

**Architecture:** Tailscale Serve(443→9080) → Caddy(:9080) → 각 서비스. Caddy는 network_mode: host로 로컬 포트 접근, Jellyfin은 BaseUrl=/jellyfin 설정.

**Tech Stack:** Caddy (latest), Docker Compose, Tailscale Serve

---

### Task 1: Create Caddyfile

**Files:**
- Create: `heritage/caddy/Caddyfile`

- [ ] **Step 1: Create caddy directory**

```bash
mkdir -p heritage/caddy
```

- [ ] **Step 2: Write Caddyfile**

Create `heritage/caddy/Caddyfile`:

```caddy
:9080 {
    # Jellyfin (Base URL 설정 필요)
    redir /jellyfin /jellyfin/
    handle /jellyfin/* {
        reverse_proxy localhost:8096
    }

    # Transmission (prefix 유지)
    handle /transmission* {
        reverse_proxy localhost:8091
    }

    # Homepage (catch-all)
    handle {
        reverse_proxy localhost:3000
    }
}
```

- [ ] **Step 3: Validate Caddyfile syntax**

Run: `cd heritage && docker run --rm -v "$PWD/caddy:/etc/caddy" caddy validate --config /etc/caddy/Caddyfile`
Expected: `Configuration valid` or similar success message

- [ ] **Step 4: Commit**

```bash
git add heritage/caddy/Caddyfile
git commit -m "feat: create Caddyfile for reverse proxy"
```

---

### Task 2: Update compose.yml - Replace Traefik with Caddy

**Files:**
- Modify: `heritage/compose.yml`

- [ ] **Step 1: Remove traefik service block**

Remove lines 3-11 from `heritage/compose.yml`:
```yaml
services:
  # --- L7 Reverse Proxy ---
  traefik:
    image: traefik:v3
    container_name: traefik
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./traefik/traefik.yml:/etc/traefik/traefik.yml:ro
      - ./traefik/dynamic.yml:/etc/traefik/dynamic.yml:ro
```

- [ ] **Step 2: Add caddy service**

Add after `services:` header (line 3):
```yaml
services:
  # --- L7 Reverse Proxy ---
  caddy:
    image: caddy:latest
    container_name: caddy
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./caddy/Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
```

- [ ] **Step 3: Add caddy volumes section**

Add to existing `volumes:` section (after line 132):
```yaml
volumes:
  aria2-config:
  caddy_data:
  caddy_config:
```

- [ ] **Step 4: Commit**

```bash
git add heritage/compose.yml
git commit -m "feat: replace traefik with caddy in compose.yml"
```

---

### Task 3: Update compose.yml - Set Jellyfin BaseUrl

**Files:**
- Modify: `heritage/compose.yml`

- [ ] **Step 1: Change JELLYFIN_BaseUrl environment variable**

Find line 88 in `heritage/compose.yml`:
```yaml
      - JELLYFIN_BaseUrl=
```

Change to:
```yaml
      - JELLYFIN_BaseUrl=/jellyfin
```

- [ ] **Step 2: Commit**

```bash
git add heritage/compose.yml
git commit -m "feat: set JELLYFIN_BaseUrl=/jellyfin for reverse proxy"
```

---

### Task 4: Delete Traefik configuration

**Files:**
- Delete: `heritage/traefik/traefik.yml`
- Delete: `heritage/traefik/dynamic.yml`

- [ ] **Step 1: Delete traefik directory**

```bash
rm -rf heritage/traefik
```

- [ ] **Step 2: Commit**

```bash
git add heritage/traefik
git commit -m "chore: remove traefik configuration files"
```

---

### Task 5: Deploy and verify Caddy

**Files:**
- None (deployment only)

- [ ] **Step 1: SSH to heritage and change directory**

Run: `ssh heritage "cd /opt/heritage"`
Expected: SSH connection successful

- [ ] **Step 2: Pull latest changes**

Run: `ssh heritage "cd /opt/heritage && git pull"`
Expected: Latest commits pulled

- [ ] **Step 3: Start Caddy container**

Run: `ssh heritage "cd /opt/heritage && docker compose up -d caddy"`
Expected: Caddy container started

- [ ] **Step 4: Test Homepage access**

Run: `curl -i http://localhost:9080/`
Expected: `HTTP/1.1 200 OK` or `302 Found`

- [ ] **Step 5: Test Jellyfin access**

Run: `curl -i http://localhost:9080/jellyfin/`
Expected: `HTTP/1.1 200 OK` or redirect to `/jellyfin/`

- [ ] **Step 6: Test Transmission access**

Run: `curl -i http://localhost:9080/transmission/web/`
Expected: `HTTP/1.1 200 OK`

- [ ] **Step 7: Verify Caddy container logs**

Run: `ssh heritage "cd /opt/heritage && docker compose logs caddy --tail=20"`
Expected: No errors in logs

---

### Task 6: Stop Traefik container

**Files:**
- None (deployment only)

- [ ] **Step 1: Stop and remove traefik container**

Run: `ssh heritage "docker stop traefik && docker rm traefik"`
Expected: Traefik container stopped and removed

- [ ] **Step 2: Verify no traefik container**

Run: `ssh heritage "docker ps -a | grep traefik"`
Expected: No output (container removed)

---

### Task 7: Browser integration testing

**Files:**
- None (manual testing)

- [ ] **Step 1: Test Homepage in browser**

Open: `https://heritage.bun-bull.ts.net/` in browser
Expected: Homepage loads correctly

- [ ] **Step 2: Test Jellyfin in browser**

Open: `https://heritage.bun-bull.ts.net/jellyfin/` in browser
Expected: Jellyfin loads correctly, no 404 for static assets

- [ ] **Step 3: Test Transmission in browser**

Open: `https://heritage.bun-bull.ts.net/transmission/web/` in browser
Expected: Transmission Web UI loads correctly

- [ ] **Step 4: Check DevTools Network tab**

In browser DevTools for Jellyfin/Transmission pages:
Expected: All JS/CSS/XHR requests load correctly (no 404s from `/` root)

---

### Task 8: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Read CLAUDE.md to find Traefik references**

Search for: "Traefik" occurrences in CLAUDE.md
Note: Line numbers and content

- [ ] **Step 2: Update Architecture section**

Find "Traefik (L7 reverse proxy, port 9080)" reference
Replace with: "Caddy (L7 reverse proxy, port 9080)"

- [ ] **Step 3: Update Service URL table**

Verify table still correct (no changes needed as URLs remain same)
URLs: Homepage, Jellyfin, Transmission remain unchanged

- [ ] **Step 4: Update Day-to-Day Operations section**

Find: "Caddy 서비스 재시작" if exists, or add after Heritage service restart section
Add:
```bash
# Caddy 서비스 재시작
ssh heritage "cd /opt/heritage && docker compose restart caddy"

# Caddy 로그 확인
ssh heritage "cd /opt/heritage && docker compose logs -f --tail=50 caddy"
```

- [ ] **Step 5: Update File Layout section**

Find: "heritage/traefik/" entry
Replace with: "heritage/caddy/" | Caddy L7 reverse proxy 설정 (Caddyfile)

- [ ] **Step 6: Update Key Constraints section**

Find: "Traefik 라우팅:" reference
Replace with: "Caddy 라우팅:" and update description

- [ ] **Step 7: Remove Traefik-specific Gotchas**

Find: Any Traefik-specific notes in Gotchas section
Remove or replace with Caddy-specific notes if applicable

- [ ] **Step 8: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md for Caddy migration"
```

---

### Task 9: Final verification and documentation

**Files:**
- None (verification)

- [ ] **Step 1: Verify all containers running**

Run: `ssh heritage "cd /opt/heritage && docker compose ps"`
Expected: All services running, caddy included, traefik excluded

- [ ] **Step 2: Check disk usage (caddy_data volume)**

Run: `ssh heritage "docker system df -v | grep caddy"`
Expected: Volumes created successfully

- [ ] **Step 3: Test external access via Tailscale**

Run: `curl -i https://heritage.bun-bull.ts.net/`
Expected: `HTTP/1.1 200 OK` via HTTPS

- [ ] **Step 4: Create rollback script (optional)**

Create `scripts/rollback-to-traefik.sh`:
```bash
#!/bin/bash
# Rollback to Traefik in case of Caddy issues
cd /opt/heritage
git checkout HEAD~8 -- compose.yml
git checkout HEAD~7 -- traefik/
docker compose down caddy
docker compose up -d traefik
echo "Rolled back to Traefik"
```

- [ ] **Step 5: Document migration completion**

Note: Check that all spec requirements are met and create migration summary

- [ ] **Step 6: Commit rollback script**

```bash
git add scripts/rollback-to-traefik.sh
git commit -m "chore: add rollback script for Caddy migration"
```

---

## Self-Review

**1. Spec coverage:**
- ✅ `heritage/caddy/Caddyfile` 생성 → Task 1
- ✅ `heritage/compose.yml` 수정 → Task 2, Task 3
- ✅ `heritage/traefik/` 삭제 → Task 4
- ✅ Caddy 배포 및 검증 → Task 5, Task 6, Task 7
- ✅ CLAUDE.md 업데이트 → Task 8

**2. Placeholder scan:**
- ✅ No TBD, TODO, or incomplete placeholders found
- ✅ All code snippets are complete and executable
- ✅ All commands have expected outputs

**3. Type consistency:**
- ✅ `caddy` service name consistent throughout
- ✅ Port 9080 consistent
- ✅ Volume names consistent
- ✅ Jellyfin BaseUrl value consistent
