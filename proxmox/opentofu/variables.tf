variable "proxmox_node" {
  type    = string
  default = "walle"
}

variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox API endpoint"
  default     = "https://walle.bun-bull.ts.net:8006"
}

variable "talos_template_vmid" {
  type        = number
  default     = 900
  description = "Talos VM 템플릿 ID (사전 수동 생성)"
}

variable "talos_master_vmid" {
  type    = number
  default = 100
}

variable "talos_worker_vmid" {
  type    = number
  default = 101
}

variable "heritage_vmid" {
  type    = number
  default = 200
}

variable "talos_master_resources" {
  type = object({
    cores  = number
    memory = number
    disk   = number
  })
  default = {
    cores  = 2
    memory = 4096
    disk   = 20
  }
}

variable "talos_worker_resources" {
  type = object({
    cores  = number
    memory = number
    disk   = number
  })
  default = {
    cores  = 2
    memory = 2560
    disk   = 30
  }
}

variable "heritage_resources" {
  type = object({
    cores  = number
    memory = number
    swap   = number
    disk   = number
  })
  default = {
    cores  = 2
    memory = 1536
    swap   = 512
    disk   = 50
  }
}

variable "cockpit_template_vmid" {
  type        = number
  default     = 901
  description = "Ubuntu 24.04 cloud image template ID (사전 수동 생성, scripts/create-ubuntu-template.sh)"
}

variable "cockpit_vmid" {
  type    = number
  default = 102
}

variable "cockpit_resources" {
  type = object({
    cores  = number
    memory = number
    disk   = number
  })
  default = {
    cores  = 2
    memory = 4096
    disk   = 30
  }
}
