---
title: ProxmoxMCP-Plus config.json 갱신
date: 2026-07-04
status: approved
---

# ProxmoxMCP-Plus config.json 갱신

## 개요

ProxmoxMCP-Plus(uvx 실행)가 walle(Proxmox VE 9.2)에 연결하도록 로컬 config.json의 placeholder를 실제 값으로 갱신하고, `.mcp.json`의 참조 경로를 정정한다.

## 아키텍처

```text
Claude Code → uvx proxmox-mcp-plus → config.json(PROXMOX_MCP_CONFIG)
  → Proxmox API(walle.bun-bull.ts.net:8006)
  → SSH exec(crong@walle + sudo) → 노드 명령(qm/pct/pvesh)
```

## 경로 정책

| 항목 | 경로 | 비고 |
| :--- | :--- | :--- |
| config 파일 | `~/.config/proxmox-mcp/config.json` | 로컬 평문, 권한 600, git 미추적 |
| MCP 참조 | `.mcp.json`(homelab repo) | env `PROXMOX_MCP_CONFIG` 경로 정정 |

config.json은 OS 로컬 파일이므로 sops 암호화 불필요. 권한 600으로 보호.

## 필드 매핑 (walle 맞춤)

| 섹션 | 필드 | 값 | 근거 |
| :--- | :--- | :--- | :--- |
| proxmox | host | `walle.bun-bull.ts.net` | Tailscale |
| proxmox | port | 8006 | PVE 기본 |
| proxmox | verify_ssl | `false` | 자가 서명 인증서 |
| proxmox | service | PVE | 유지 |
| api_tunnel | enabled | `false` | Tailscale 직접, 터널 불필요 |
| auth | user | `root@pam` | 토큰에서 분해 |
| auth | token_name | `<secrets>` | `secrets.sops.yaml` 복호화 |
| auth | token_value | `<secrets>` | `secrets.sops.yaml` 복호화 |
| security | dev_mode | `true` | 자가 서명 + approval 토큰 비활성화 |
| logging | level | `INFO` | 운영 기본(원본 DEBUG) |
| mcp | transport | STDIO | 유지 |
| command_policy | mode | `deny_all` | 보안 기본값 유지 |
| ssh | user | `crong` | NOPASSWD sudo 검증됨 |
| ssh | key_file | `~/.ssh/id_ed25519` | crong@walle 접속 검증 완료 |
| ssh | use_sudo | `true` | root 명령 필요 |
| ssh | host_overrides | `{walle: walle.bun-bull.ts.net}` | 노드 매핑 |
| ssh | port | 22 | 기본 |
| ssh | known_hosts_file | `~/.ssh/known_hosts` | 기존 존재 |
| ssh | strict_host_key_checking | `true` | 유지 |

## 사전 검증 이력

| 검증 | 결과 |
| :--- | :--- |
| `.mcp.json` 참조 경로 vs 실제 파일 | Risk → 불일치. `.mcp.json`은 `~/.config/ProxmoxMCP-Plus/...` 참조, 사용자 생성 파일은 `~/.config/proxmox-mcp/config.json` → `.mcp.json` 수정 |
| CLAUDE.md 경로 기재 | `~/.config/proxmox-mcp/config.json`로 파일과 일치 (수정 불필요) |
| `~/.ssh/id_ed25519` 존재 | OK (권한 600) |
| `ssh crong@walle` 접속 | OK (id_ed25519 인증) |
| crong NOPASSWD sudo | OK (`sudo -n pveversion`, `sudo -n qm list` 성공) |
| walle root SSH (id_ed25519) | Blocker → crong+sudo 경로로 회피 |
| `secrets.sops.yaml` 복호화 | OK (`proxmox_api_token` 존재) |

## 작업 절차

1. `sops -d proxmox/opentofu/secrets.sops.yaml`에서 `proxmox_api_token` 추출
2. 토큰 형식 `root@pam!<name>=<value>` → `auth.user`/`auth.token_name`/`auth.token_value` 분해
3. `~/.config/proxmox-mcp/config.json`에 위 테이블 값 반영
4. `chmod 600 ~/.config/proxmox-mcp/config.json`
5. `.mcp.json`의 `PROXMOX_MCP_CONFIG` env 값을 `~/.config/proxmox-mcp/config.json`으로 수정
6. 검증: Claude Code 재시작 후 `mcp__proxmox-mcp-plus__*` 도구로 `get_nodes`/`get_vms` 호출 응답 확인

## 범위 외 (YAGNI)

- sops 래퍼 / 임시 평문 복호화 스크립트 — 로컬 파일이라 불필요
- MCP 전용 API 토큰 신규 발급 — 기존 `root@pam` 토큰 재사용
- `command_policy` 세부 allow/deny 패턴 조정 — deny_all 기본값 유지
- SSH host_overrides 다중 노드 — 단일 노드(walle) 환경
