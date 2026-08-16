# Design Spec: Heritage Configuration Sync & Port 9080 Recovery

- **Date:** 2026-08-17
- **Target:** LXC 200 (`heritage`), `heritage/` in homelab repository
- **Status:** Approved

---

## 1. Background & Problem Statement

Heritage LXC (ID: 200) runs media services behind Caddy L7 reverse proxy and Tailscale Serve.
During live inspection, the following issues and drifts were identified:
1. **HTTP 502 Bad Gateway Outage:** Tailscale Serve proxies `https://heritage.bun-bull.ts.net` (port 443) to `http://127.0.0.1:9080`. However, the remote `/opt/heritage/caddy/Caddyfile` was listening on `:9091` instead of `:9080`, causing complete failure of external access.
2. **Configuration Drift:** Remote had improvements (AriaNg web UI routing, updated homepage services, clean compose.yml) that were not synced back into the repository `heritage/` directory.

---

## 2. Architecture & Port Contracts

```
Tailnet Client -> https://heritage.bun-bull.ts.net (443)
                  ↓ (Tailscale Serve)
               http://127.0.0.1:9080 (Caddy Reverse Proxy)
                  ├── / -> Homepage (localhost:3000)
                  ├── /jellyfin/* -> Jellyfin (localhost:8096)
                  ├── /transmission* -> Transmission (localhost:8091)
                  └── /aria2* -> Aria2 / AriaNg (localhost:6888)
```

| Service | Container Name | Host Port | Routing via Caddy (:9080) |
| :--- | :--- | :--- | :--- |
| **Caddy** | `caddy` | `:9080` (host network) | L7 Entry point for Tailscale Serve |
| **Homepage** | `homepage` | `:3000` (host network) | `/` (catch-all) |
| **Jellyfin** | `jellyfin` | `:8096` | `/jellyfin/*` |
| **Transmission**| `transmission`| `:8091` | `/transmission*` |
| **Aria2** | `aria2` | `:6800` (RPC), `:6888` (AriaNg) | `/aria2*` -> `localhost:6888` |

---

## 3. Configuration Sync Specifications

### 3.1 `heritage/caddy/Caddyfile`
- Listen block: `:9080`
- Handle blocks for `/jellyfin/*`, `/transmission*`, `/aria2*`, and catch-all for Homepage (`localhost:3000`).

### 3.2 `heritage/compose.yml`
- Remove deprecated commented-out blocks (`gatus`, `beszel`).
- `homepage`: `PGID=1000`, `HOMEPAGE_ALLOWED_HOSTS=*`.
- `aria2`: volume `aria2_config:/config`, logging config with max-size 1m.
- Clean volume definition: `aria2_config`, `caddy_data`, `caddy_config`.

### 3.3 `heritage/homepage/config/services.yaml`
- Aria2: `href: https://heritage.bun-bull.ts.net/aria2/`, `icon: aria-ng.png`, `container: aria2`.
- Jellyfin, Transmission, Aria2: remove `server: my-docker`.

---

## 4. Operational Recovery & Verification

1. **Local Files Update:** Apply changes to `heritage/caddy/Caddyfile`, `heritage/compose.yml`, and `heritage/homepage/config/services.yaml`.
2. **Server Hotfix & Sync:** Update `/opt/heritage/caddy/Caddyfile` on LXC 200 to `:9080`.
3. **Caddy Restart:** Execute `docker compose restart caddy` in `/opt/heritage`.
4. **Verification:**
   - `curl -sI https://heritage.bun-bull.ts.net/` -> HTTP 200
   - `curl -sI https://heritage.bun-bull.ts.net/jellyfin/` -> HTTP 200/302
   - `curl -sI https://heritage.bun-bull.ts.net/transmission/` -> HTTP 200/307/401
   - `curl -sI https://heritage.bun-bull.ts.net/aria2/` -> HTTP 200
