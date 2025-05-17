# terraform/backend/main.tf
module "manager_nodes" {
  source = "./modules/proxmox_vm"  # Or your hypervisor of choice
  count  = 3  # 3 managers for high availability
  
  name_prefix  = "metrics-manager"
  cpu          = 2
  memory       = 4096
  disk_size    = 40
  networks     = ["vmbr0"]
  ssh_key      = var.ssh_public_key
}

module "worker_nodes" {
  source = "./modules/proxmox_vm"
  count  = var.worker_count
  
  name_prefix  = "metrics-worker"
  cpu          = 4
  memory       = 8192
  disk_size    = 100
  networks     = ["vmbr0"]
  ssh_key      = var.ssh_public_key
}