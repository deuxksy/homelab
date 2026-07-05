variable "proxmox_node" {
  type    = string
  default = "walle"
}

variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox API endpoint"
  default     = "https://walle.bun-bull.ts.net:8006"
}

variable "heritage_vmid" {
  type    = number
  default = 200
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
