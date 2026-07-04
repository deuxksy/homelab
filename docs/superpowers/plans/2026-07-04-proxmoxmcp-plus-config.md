# ProxmoxMCP-Plus config.json 갱신 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `~/.config/proxmox-mcp/config.json`의 placeholder를 walle 실값으로 채우고 `.mcp.json`의 참조 경로를 정정하여 ProxmoxMCP-Plus가 walle에 연결되도록 한다.

**Architecture:** ProxmoxMCP-Plus(uvx)가 `PROXMOX_MCP_CONFIG` env로 config.json을 읽어 Proxmox API(walle:8006)와 SSH exec(crong@walle + sudo)를 사용. 정적 필드는 jq로 일괄 갱신, 토큰은 `sops --output-type json | jq -r`로 복호화해 파이프라인에서 `IFS='!' read` + 파라미터 확장으로 분해 후 jq `--arg`로 안전 주입.

**Tech Stack:** jq 1.8.1, sops 3.13.2 (age), zsh/bash. (yq 불필요 — sops json 출력 + jq로 대체)

## Global Constraints

- config.json 절대 경로: `/home/deck/.config/proxmox-mcp/config.json` (로컬 평문, 권한 600, git 미추적). `.mcp.json` env에는 `~` 확장이 불확실하므로 절대 경로 사용.
- sops 원본: `proxmox/opentofu/secrets.sops.yaml`의 `proxmox_api_token` (형식 `root@pam!<name>=<value>`, CLAUDE.md 기준)
- 토큰 평문은 stdout/채팅에 노출 금지 — 파이프라인 내에서만 흐름, 변수 export 금지, 검증은 길이/고정값 여부만 출력(token name도 식별자이므로 마스킹)
- `.sops.yaml` path_regex는 `.sops.yaml` 매칭 — 파일명 변경 금지
- walle 자가 서명 인증서 → `verify_ssl=false`, `dev_mode=true` (schema상 dev_mode=true여야 verify_ssl=false 허용)
- SSH exec은 crong 계정(NOPASSWD sudo)으로 root 명령 실행
- 임시 파일 생성 시 `(umask 077 && ...)` 서브셸 사용 — 기본 umask 022의 644 노출 방지
- 명령어는 `/home/deck/git/homelab`을 CWD로 실행 (sops 상대 경로)

## File Structure

| 파일 | 책임 | 변경 유형 |
| :--- | :--- | :--- |
| `/home/deck/.config/proxmox-mcp/config.json` | ProxmoxMCP-Plus 런타임 설정 | Modify (값 채우기) |
| `.mcp.json` | Claude Code MCP 서버 참조 | Modify (env 경로) |
| `proxmox/opentofu/secrets.sops.yaml` | 토큰 단일 소스(읽기 전용) | Read only |

---

### Task 1: config.json 정적 필드 갱신 (토큰 제외)

**Files:**
- Modify: `/home/deck/.config/proxmox-mcp/config.json`

**Interfaces:**
- Produces: 정적 값이 채워진 config.json (auth는 Task 2에서 주입)

- [ ] **Step 1: 현재 config.json 백업 + 권한 보호**

Run:
```bash
cp ~/.config/proxmox-mcp/config.json ~/.config/proxmox-mcp/config.json.bak.$(date +%Y%m%d-%H%M%S)
chmod 600 ~/.config/proxmox-mcp/config.json.bak.*
ls -la ~/.config/proxmox-mcp/config.json.bak.*
```
Expected: 백업 파일 생성 + 권한 600 확인 (재실행 시 토큰 포함 백업 보호)

- [ ] **Step 2: jq로 정적 필드 일괄 갱신 (umask 077)**

Run:
```bash
CONFIG=/home/deck/.config/proxmox-mcp/config.json
( umask 077 && jq '
  .proxmox.host="walle.bun-bull.ts.net" |
  .proxmox.port=8006 |
  .proxmox.verify_ssl=false |
  .proxmox.service="PVE" |
  .api_tunnel.enabled=false |
  .security.dev_mode=true |
  .logging.level="INFO" |
  .command_policy.mode="deny_all" |
  .ssh.user="crong" |
  .ssh.port=22 |
  .ssh.key_file="~/.ssh/id_ed25519" |
  .ssh.use_sudo=true |
  .ssh.known_hosts_file="~/.ssh/known_hosts" |
  .ssh.strict_host_key_checking=true |
  .ssh.host_overrides={"walle": "walle.bun-bull.ts.net"}
' "$CONFIG" > "$CONFIG.tmp" ) && mv "$CONFIG.tmp" "$CONFIG"
```
Expected: 에러 없이 완료. tmp 파일은 600으로 생성 후 원본 교체.

- [ ] **Step 3: 갱신된 정적 필드 검증**

Run:
```bash
jq '{host: .proxmox.host, verify_ssl: .proxmox.verify_ssl, dev_mode: .security.dev_mode, ssh_user: .ssh.user, ssh_key: .ssh.key_file, use_sudo: .ssh.use_sudo, host_overrides: .ssh.host_overrides}' ~/.config/proxmox-mcp/config.json
```
Expected output:
```json
{
  "host": "walle.bun-bull.ts.net",
  "verify_ssl": false,
  "dev_mode": true,
  "ssh_user": "crong",
  "ssh_key": "~/.ssh/id_ed25519",
  "use_sudo": true,
  "host_overrides": {
    "walle": "walle.bun-bull.ts.net"
  }
}
```

- [ ] **Step 4: JSON 문법 + 권한 검증**

Run:
```bash
jq empty ~/.config/proxmox-mcp/config.json && echo "JSON OK"
stat -c '%a %n' ~/.config/proxmox-mcp/config.json
```
Expected: `JSON OK` + `600 .../config.json`

---

### Task 2: 토큰 복호화 및 auth 필드 주입

**Files:**
- Modify: `/home/deck/.config/proxmox-mcp/config.json`

**Interfaces:**
- Consumes: `proxmox/opentofu/secrets.sops.yaml`의 `proxmox_api_token`
- Produces: auth.user, auth.token_name, auth.token_value가 채워진 config.json

- [ ] **Step 1: 토큰 형식 사전 검증 (평문 비노출)**

Run:
```bash
cd /home/deck/git/homelab
sops -d --output-type json proxmox/opentofu/secrets.sops.yaml | jq -r '.proxmox_api_token' | grep -qE '^[^!]+![^=]+=.+$' && echo "FORMAT OK" || echo "FORMAT MISMATCH - 중단"
```
Expected: `FORMAT OK`. 형식이 다르면 plan 중단 후 토큰 구조 재확인. 평문 미출력.

- [ ] **Step 2: 토큰 파싱 + auth 주입 (단일 파이프라인, 평문 비노출)**

Run:
```bash
cd /home/deck/git/homelab
CONFIG=/home/deck/.config/proxmox-mcp/config.json
sops -d --output-type json proxmox/opentofu/secrets.sops.yaml | jq -r '.proxmox_api_token' | {
  IFS='!' read -r USER_PART REST
  NAME_PART="${REST%%=*}"
  VALUE_PART="${REST#*=}"
  ( umask 077 && jq --arg u "$USER_PART" --arg n "$NAME_PART" --arg v "$VALUE_PART" \
    '.auth.user=$u | .auth.token_name=$n | .auth.token_value=$v' \
    "$CONFIG" > "$CONFIG.tmp" ) && mv "$CONFIG.tmp" "$CONFIG"
}
```
Expected: 에러 없이 완료.
- `jq -r` raw 출력 (따옴표 미포함)
- `IFS='!' read`로 `!` 분할 (파이프라인 = 비대화형, 히스토리 확장 안 됨)
- `${REST#*=}` 파라미터 확장으로 첫 `=` 이후 전체 (중복 `=` 안전)
- `(umask 077 && ...)`로 tmp 600 생성
- 토큰 평문은 파이프라인 내에만 존재, 셸 변수 export 없음

- [ ] **Step 3: auth 필드 검증 (식별자 마스킹, 길이만)**

Run:
```bash
jq '{user_is_root_pam: (.auth.user=="root@pam"), name_len: (.auth.token_name|length), value_len: (.auth.token_value|length)}' ~/.config/proxmox-mcp/config.json
```
Expected: `user_is_root_pam: true`, `name_len`/`value_len`이 0보다 큰 정수. 평문/name 미출력.

- [ ] **Step 4: JSON 문법 + 권한 재검증**

Run:
```bash
jq empty ~/.config/proxmox-mcp/config.json && echo "JSON OK"
stat -c '%a %n' ~/.config/proxmox-mcp/config.json
```
Expected: `JSON OK` + `600`

---

### Task 3: config.json 권한 확인 + .mcp.json 경로 정정 + 커밋

**Files:**
- Modify: `/home/deck/.config/proxmox-mcp/config.json` (권한 재확인)
- Modify: `.mcp.json`

**Interfaces:**
- Produces: 권한 600 config.json, `proxmox-mcp-plus`가 절대 경로로 참조하는 `.mcp.json`

- [ ] **Step 1: config.json 권한 600 재확인**

Run:
```bash
chmod 600 ~/.config/proxmox-mcp/config.json
stat -c '%a %U:%G %n' ~/.config/proxmox-mcp/config.json
```
Expected: `600 deck:deck /home/deck/.config/proxmox-mcp/config.json`

- [ ] **Step 2: .mcp.json 현재 값 확인**

Run: `jq '.mcpServers["proxmox-mcp-plus"].env' .mcp.json`
Expected:
```json
{
  "PROXMOX_MCP_CONFIG": "~/.config/ProxmoxMCP-Plus/proxmox-config/config.json"
}
```

- [ ] **Step 3: .mcp.json env 경로를 절대 경로로 수정**

Run:
```bash
( umask 077 && jq '.mcpServers["proxmox-mcp-plus"].env.PROXMOX_MCP_CONFIG = "/home/deck/.config/proxmox-mcp/config.json"' .mcp.json > .mcp.json.tmp ) && mv .mcp.json.tmp .mcp.json
```
Expected: 에러 없이 완료. `~` 대신 절대 경로 사용 (uvx/Claude Code env ~ 확장 불확실 회피).

- [ ] **Step 4: .mcp.json 변경 확인**

Run: `jq '.mcpServers["proxmox-mcp-plus"].env' .mcp.json`
Expected:
```json
{
  "PROXMOX_MCP_CONFIG": "/home/deck/.config/proxmox-mcp/config.json"
}
```

- [ ] **Step 5: .mcp.json 커밋**

Run:
```bash
cd /home/deck/git/homelab
git status --short
git diff --stat .mcp.json
git add .mcp.json
git commit -m "fix: ProxmoxMCP-Plus config 참조 경로를 proxmox-mcp 절대경로로 정정"
git log --oneline -1
```
Expected: 커밋 해시 출력. config.json은 git 밖(~/.config/)이므로 커밋 대상 아님. `git status --short`로 의도치 않은 변경 미포함 확인.

---

### Task 4: MCP 실행 검증

**Files:**
- 없음 (런타임 검증)

**Interfaces:**
- Consumes: Task 1-3 결과

- [ ] **Step 1: uvx 단독 기동 테스트 (env 명시, 토큰 마스킹)**

Run:
```bash
PROXMOX_MCP_CONFIG=/home/deck/.config/proxmox-mcp/config.json timeout 10 uvx proxmox-mcp-plus 2>&1 | sed -E 's/(token_value|Authorization|PVEAPIToken)[^ ]*/<masked>/g' | head -20
```
Expected: config를 읽고 에러 없이 STDIO 대기 상태 진입(또는 timeout 종료). 인증/SSL 에러가 없어야 함. `.mcp.json` env는 Claude 주입값이라 shell 실행 시 자동 적용 안 됨 — 반드시 `PROXMOX_MCP_CONFIG` 명시.

- [ ] **Step 2: Claude Code MCP 서버 재연결**

사용자 액션: Claude Code를 재시작하거나 `/mcp` 명령으로 `proxmox-mcp-plus` 재연결.

Run: `claude` 세션에서 `/mcp` 실행 → `proxmox-mcp-plus` 상태가 `connected`인지 확인.
Expected: `connected` 상태.

- [ ] **Step 3: 읽기 전용 MCP 도구 호출 테스트**

Claude Code에서 MCP 도구 호출 (예: `get_nodes` 또는 `get_vms`). Verify: 응답에 walle 노드와 VM 100/101/900이 포함되는지 확인. SSH exec 도구(crong+sudo 경로)도 별도 호출로 API auth와 SSH sudo 경로를 분리 검증 권장.

Expected: 노드/VM 목록 정상 응답.

---

## Self-Review (2-way 교차 검증 반영)

**검증 이력:** Antigravity(Gemini 3.1 Pro High) + Codex(gpt-5.5) 2-way 병렬 검증. Blocker 3개 만장일치.

**1. Blocker 해결:**
- B1 (따옴표 중복): `jq -r` raw 출력 + `--arg` 직접 주입 → 해결
- B2 (임시 파일 644): `(umask 077 && ...)` 서브셸 → 해결
- B3 (단독 기동 env 누락): `PROXMOX_MCP_CONFIG=...` 명시 → 해결

**2. Risk 반영:**
- 중복 `=` 파싱: `${REST#*=}` 파라미터 확장 → 해결
- `~` 경로: 절대 경로 `/home/deck/...` 사용
- token name 노출: Step 3에서 길이만 출력
- 백업 권한: Task 1 Step 1에서 `chmod 600` 추가
- yq 의존성: `sops --output-type json | jq -r`로 제거
- dev_mode 설명: spec 정정 (`verify_ssl=false` 허용 조건)

**3. Codex schema 검증 (ProxmoxMCP-Plus 0.5.8):**
- `auth.user/token_name/token_value`, `ssh.host_overrides/use_sudo`, `proxmox.verify_ssl`, `security.dev_mode` 필드명 모두 유효
- `command_policy.high_risk_mode/high_risk_operations` 필드 존재 — 기존 config에 없으면 default 적용 (YAGNI, 명시 생략)

**4. Spec coverage:** 모든 spec 필드가 Task에 매핑됨. Placeholder 없음.

**주의사항:**
- Task 2 평문 토큰은 파이프라인 내에만 존재 — stdout/채팅에 노출되지 않음
- 토큰 형식이 `^[^!]+![^=]+=.+$`가 아니면 Task 2 Step 1에서 중단
- config.json은 git 미추적 — 재현 필요 시 Task 1-3 재실행 또는 백업(600)에서 복원
