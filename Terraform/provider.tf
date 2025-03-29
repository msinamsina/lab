terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.1-rc4"
    }
  }
}

provider "proxmox" {
  # Configuration options
    pm_tls_insecure = true
    pm_api_url = var.proxmox_api_url
    pm_api_token_secret = var.proxmox_api_token
    pm_api_token_id = var.proxmox_api_token_id
}
