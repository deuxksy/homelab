---
name: tofu-plan
description: OpenTofu R2 자격 증명 로드 후 plan 실행
disable-model-invocation: true
---

# OpenTofu Plan

Cloudflare R2 backend에 연결하여 OpenTofu plan을 실행한다.

## Prerequisites

- R2 자격 증명: `source ~/git/twenty-four-seven-three-sixty-five/.env`
- backend.tf가 Cloudflare R2 S3-compatible backend로 설정됨

## Steps

1. R2 자격 증명 로드: `source ~/git/twenty-four-seven-three-sixty-five/.env`
2. `cd proxmox/opentofu && tofu init` (backend 변경 시에만)
3. `tofu plan` 실행
4. 변경사항 리포트 출력

## Commands

```bash
source /Users/crong/git/twenty-four-seven-three-sixty-five/.env
cd /Users/crong/git/homelab/proxmox/opentofu
tofu plan
```
