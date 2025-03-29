locals {
  nodes = concat(
    [for i in range(var.master_count) : { name = "k3s-master-0${i+1}", role = "master", vmid = 1000 + i + 1}],
    [for i in range(var.worker_count) : { name = "k3s-worker-0${i+1}", role = "worker", vmid = 2000 + i + 1}]
  )
}

resource "proxmox_vm_qemu" "k3s-nodes" {
  for_each    = { for idx, node in local.nodes : idx => node }
  vmid        = each.value.vmid
  name        = each.value.name
  target_node = "aras"
  agent       = 1
  cores       = 2
  memory      = 2048
  boot        = "order=scsi0"
  clone       = "ubuntu-24.04"
  full_clone  = true
  os_type     = "cloud-init"
  scsihw      = "virtio-scsi-single"
  vm_state    = "running"
  automatic_reboot = true

  ipconfig0  = "ip=dhcp"
  ciuser     = "ubuntu"
  cipassword = "change-me"
  ciupgrade  = true

  sshkeys    = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJvgGBEqSMILIxh0gjIO4+viQXNHdOfeUSAfUoxXRUUq ubuntu@admin"


  serial {
    id = 0
  }

  disks {
    scsi {
      scsi0 {
        disk {
          storage = "ssd"
          size    = "20G"
        }
      }
    }
    ide {
      ide1 {
        cloudinit {
          storage = "ssd"
        }
      }
    }
  }

  network {
# the ID field should be uncommented if you are using procxmox 3.0.1-rc6 provider
#   id = 0  
    bridge = "vmbr0"
    link_down = false
    model  = "virtio"
    macaddr = "bc:24:11:c8:4a:0${each.key + 1}"
  }
}
