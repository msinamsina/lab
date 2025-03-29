output instance_ip_addr {
 value = [for ip in proxmox_vm_qemu.k3s-nodes : ip.ssh_host ]
}
