variable proxmox_api_url {
  type = string
}

variable proxmox_api_token_id {
  type = string
}

variable proxmox_api_token {
  type = string
}

variable "master_count" {
  default = 3
}

variable "worker_count" {
  default = 2
}
