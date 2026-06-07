---
name: iac-validation
description: OpenTofu 구성 검증 자동화
---

OpenTofu 설정 변경 후 자동으로 `tofu validate`를 실행합니다.

## 사용 시기

```bash
cd proxmox/opentofu
tofu apply  # 또는 tofu plan
```

자동으로 검증이 실행됩니다.

## 수행 순서

1. PreToolUse 훅크에서 OpenTofu 파일 감지
2. `tofu validate` 실행
3. 검증 오류 있으면 보고, 없으면 계속 진행
