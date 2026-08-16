# Heritage Sync & Port 9080 Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Synchronize the local repository `heritage/` configuration with the latest server state and resolve the live HTTP 502 Bad Gateway outage by aligning Caddy and Tailscale Serve on port 9080.

**Architecture:** Tailscale Serve proxies `https://heritage.bun-bull.ts.net` (443) -> `127.0.0.1:9080` (Caddy host network). Caddy routes subpaths (`/jellyfin/*`, `/transmission*`, `/aria2*`, and catch-all `/` for Homepage).

**Tech Stack:** Docker Compose v2, Caddy L7 Reverse Proxy, Tailscale Serve, Debian 12 (LXC 200).

## Global Constraints

- Caddy MUST listen on port `:9080`.
- All media and download paths on host (`/mnt/data1`, `/mnt/data2`) use UID/GID `1000:1000` (mapped to `101000:101000` on PVE).
- Aria2 Web UI route is `/aria2*` proxying to `localhost:6888`.

---

### Task 1: Update Local Caddyfile

**Files:**
- Modify: `heritage/caddy/Caddyfile`

**Interfaces:**
- Produces: Caddy reverse proxy rules on port `:9080` with `/aria2*` route.

- [ ] **Step 1: Update `heritage/caddy/Caddyfile`**

Write the following content:
```caddy
# Caddyfile for Heritage Collection
# Tailscale Web Proxy & Reverse Proxy

:9080 {
    # Jellyfin
    redir /jellyfin /jellyfin/
    handle /jellyfin/* {
        reverse_proxy localhost:8096
    }

    # Transmission
    handle /transmission* {
        reverse_proxy localhost:8091
    }

    # Aria2 (AriaNg Web UI)
    handle /aria2* {
        reverse_proxy localhost:6888
    }

    # Homepage (catch-all)
    handle {
        reverse_proxy localhost:3000
    }
}
```

- [ ] **Step 2: Verify syntax format**

Run: `grep ":9080" heritage/caddy/Caddyfile && grep "aria2" heritage/caddy/Caddyfile`
Expected: Matches found for `:9080` and `handle /aria2*`

- [ ] **Step 3: Commit**

```bash
git add heritage/caddy/Caddyfile
git commit -m "fix(heritage): align caddyfile port to 9080 and add aria2 route"
```

---

### Task 2: Update Local `heritage/compose.yml`

**Files:**
- Modify: `heritage/compose.yml`

**Interfaces:**
- Produces: Updated Compose configuration aligning volume names (`aria2_config`), Homepage permissions (`PGID=1000`), and removing dead comments.

- [ ] **Step 1: Update `heritage/compose.yml`**

Write the cleaned compose file matching the current server stack:
```yaml
services:
  # --- L7 Reverse Proxy (Caddy) ---
  caddy:
    image: docker.io/library/caddy:latest
    container_name: caddy
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./caddy/Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config

  # --- Dashboard (Homepage) ---
  homepage:
    image: ghcr.io/gethomepage/homepage:latest
    container_name: homepage
    restart: unless-stopped
    env_file:
      - .env
    network_mode: host
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Seoul
      - HOMEPAGE_ALLOWED_HOSTS=*
    volumes:
      - ./homepage/config:/app/config
      - /var/run/docker.sock:/var/run/docker.sock:ro

  # --- Acquisition Engine: Torrent (Transmission) ---
  transmission:
    image: lscr.io/linuxserver/transmission:latest
    container_name: transmission
    restart: unless-stopped
    ports:
      - "8091:9091"
      - "51413:51413"
      - "51413:51413/udp"
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Seoul
    volumes:
      - ./transmission/config:/config
      - ./transmission/data:/data
      - /mnt/data2/torrent/downloads:/downloads
      - /mnt/data1/torrent/complete:/downloads/complete
      - /mnt/data2/torrent/downloads/watch:/watch
    mem_limit: 512m

  # --- Acquisition Engine: Direct Download (Aria2) ---
  aria2:
    image: p3terx/aria2-pro:test
    container_name: aria2
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - UMASK_SET=022
      - RPC_PORT=6800
      - LISTEN_PORT=6888
      - DISK_CACHE=64M
      - IPV6_MODE=false
      - UPDATE_TRACKERS=false
      - TZ=Asia/Seoul
    ports:
      - "6800:6800"
      - "6888:6888"
      - "6888:6888/udp"
    volumes:
      - aria2_config:/config
      - /mnt/data2/torrent/downloads/aria:/downloads:rw
    logging:
      driver: json-file
      options:
        max-size: 1m

  # --- Digital Theater (Jellyfin) ---
  jellyfin:
    image: docker.io/jellyfin/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
    ports:
      - "8096:8096"
    user: "1000:1000"
    environment:
      - TZ=Asia/Seoul
      - JELLYFIN_BaseUrl=/jellyfin
    volumes:
      - ./jellyfin/config:/config
      - ./jellyfin/cache:/cache
      - /mnt/data2/torrent/downloads:/data1
      - /mnt/data1/torrent/complete:/data2
    mem_limit: 2g
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8096/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

volumes:
  aria2_config:
  caddy_data:
  caddy_config:
```

- [ ] **Step 2: Verify compose syntax**

Run: `grep "aria2_config:" heritage/compose.yml`
Expected: Match in service volume and top-level volume block.

- [ ] **Step 3: Commit**

```bash
git add heritage/compose.yml
git commit -m "chore(heritage): sync compose.yml with server state"
```

---

### Task 3: Update Local Homepage Services Configuration

**Files:**
- Modify: `heritage/homepage/config/services.yaml`

**Interfaces:**
- Produces: Homepage service cards for Transmission, Aria2 (AriaNg), and Jellyfin.

- [ ] **Step 1: Update `heritage/homepage/config/services.yaml`**

Write the updated configuration:
```yaml
# Homepage Services Configuration - The Heritage Collection
# https://gethomepage.dev/configs/services/

- Info:
    - Calendar:
        widget:
          type: calendar
          firstDayInWeek: sunday
          view: monthly
          maxEvents: 10
          showTime: true

- Media:
    - Transmission:
        label: "Torrent Node"
        icon: transmission.png
        href: https://heritage.bun-bull.ts.net/transmission/web/
        container: transmission
        widget:
          type: transmission
          url: http://localhost:8091

    - Aria2:
        label: "Download Manager"
        icon: aria-ng.png
        href: https://heritage.bun-bull.ts.net/aria2/
        container: aria2

- Streaming:
    - Jellyfin:
        label: "Media Server"
        icon: jellyfin.png
        href: https://heritage.bun-bull.ts.net/jellyfin
        container: jellyfin
        widget:
          type: jellyfin
          url: http://localhost:8096
          key: "{{HOMEPAGE_VAR_JELLYFIN_API_KEY}}"
          enableBlocks: true
          enableNowPlaying: true
          enableUser: true
          showEpisodeNumber: true
          expandOneStreamToTwoRows: false
```

- [ ] **Step 2: Verify services config**

Run: `grep "aria-ng.png" heritage/homepage/config/services.yaml`
Expected: Match found.

- [ ] **Step 3: Commit**

```bash
git add heritage/homepage/config/services.yaml
git commit -m "fix(homepage): update aria2 link to ariang and cleanup docker attributes"
```

---

### Task 4: Hotfix Remote `/opt/heritage/caddy/Caddyfile` and Restart Caddy

**Files:**
- Modify (Remote): `/opt/heritage/caddy/Caddyfile` on LXC 200

**Interfaces:**
- Action: Replace `:9091` with `:9080` in remote Caddyfile and restart Caddy container.

- [ ] **Step 1: Update remote Caddyfile to listen on `:9080`**

Run:
```bash
ssh crong@walle.bun-bull.ts.net "sudo pct exec 200 -- sed -i 's/:9091/:9080/' /opt/heritage/caddy/Caddyfile"
```

- [ ] **Step 2: Verify remote Caddyfile**

Run:
```bash
ssh crong@walle.bun-bull.ts.net "sudo pct exec 200 -- head -n 5 /opt/heritage/caddy/Caddyfile"
```
Expected: Output shows `:9080 {`

- [ ] **Step 3: Restart Caddy container**

Run:
```bash
ssh crong@walle.bun-bull.ts.net "sudo pct exec 200 -- bash -c 'cd /opt/heritage && docker compose restart caddy'"
```
Expected: `Restarting caddy ... done`

---

### Task 5: Verify Live Endpoints & 502 Resolution

**Interfaces:**
- Verifies: Tailscale Serve endpoint responses.

- [ ] **Step 1: Verify root endpoint (Homepage)**

Run: `curl -sI https://heritage.bun-bull.ts.net/`
Expected: `HTTP/2 200` (or `HTTP/1.1 200 OK`)

- [ ] **Step 2: Verify Jellyfin endpoint**

Run: `curl -sI https://heritage.bun-bull.ts.net/jellyfin/`
Expected: `HTTP/2 200` or `HTTP/2 302`

- [ ] **Step 3: Verify Transmission endpoint**

Run: `curl -sI https://heritage.bun-bull.ts.net/transmission/`
Expected: `HTTP/2 307` or `HTTP/2 200` or `HTTP/2 401`

- [ ] **Step 4: Verify Aria2 (AriaNg) endpoint**

Run: `curl -sI https://heritage.bun-bull.ts.net/aria2/`
Expected: `HTTP/2 200` (AriaNg HTML page)
