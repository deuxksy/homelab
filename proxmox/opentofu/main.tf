data "sops_file" "secrets" {
  source_file = "${path.module}/secrets.sops.yaml"
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = data.sops_file.secrets.data["proxmox_api_token"]
  insecure  = true

  ssh {
    username = "root"
    agent    = true
  }

  tmp_dir = "/var/tmp"
}
