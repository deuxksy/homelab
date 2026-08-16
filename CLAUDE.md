# CLAUDE.md

@./.ai/RULES.md

## MCP Servers

`.mcp.json`으로 관리. Claude Code 시작 시 자동 로드.

| 서버 | 상태 | 비고 |
| :--- | :--- | :--- |
| proxmox-mcp-plus | 활성 | `uvx proxmox-mcp-plus`, 설정: `/home/deck/.config/proxmox-mcp/config.json` (권한 600, git 미추적) |
| serena | 활성 | 코드 심볼 분석 |
| zai-mcp-server | 활성 | 멀티모달 분석, OCR, UI 비교 |
| figma | 비활성 | 필요시 활성 |
| discord | 비활성 | 필요시 활성 |

> kubernetes MCP는 K8s 클러스터(talos) 삭제로 비활성화됨. `.mcp.json`에서 제거 대상.

- **Proxmox MCP 설정:** `/home/deck/.config/proxmox-mcp/config.json` (권한 600) — `verify_ssl=false` + `dev_mode=true` (자가 서명 인증서 허용 조건), `ssh.user=crong` + `use_sudo=true` (NOPASSWD), `command_policy.mode=deny_all` (SSH exec 도구 비활성, API 도구만 사용). 토큰은 `proxmox/opentofu/secrets.sops.yaml`의 `proxmox_api_token`에서 sops 복호화 후 주입
- **Proxmox MCP 데이터 경로:** `~/.local/state/proxmox-mcp/walle/` (sqlite DB, 로그) — XDG 표준 준수
