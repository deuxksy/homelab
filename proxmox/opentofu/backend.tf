# ============================================
# Terraform Backend (Cloudflare R2)
# ============================================
# S3-compatible backend using Cloudflare R2
# terraform-state bucket은 수동 생성 후 이 파일에서 참조만 함
# 생성: npx wrangler r2 bucket create terraform-state --location wnam
# ============================================

terraform {
  backend "s3" {
    endpoints = {
      s3 = "https://e0924c382d21ac0f10aee606b82687ce.r2.cloudflarestorage.com"
    }
    bucket                      = "terraform-state"
    key                         = "homelab/dev/terraform.tfstate"
    region                      = "auto"

    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}
