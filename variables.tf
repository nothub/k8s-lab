variable "qemu_uri" {
  type    = string
  default = "qemu:///system"
}

variable "ssh_key" {
  type        = string
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJwI2xmLrw4APecukfuLt+nrUNVFzzND/vENsQUTuyQP hub@desktop"
  description = "janitor public ssh key"
}

variable "node_cores" {
  type        = number
  default     = 2
  description = "vcpu cores per node"
  validation {
    condition     = var.node_cores >= 1
    error_message = "minimum vcpu cores: 1"
  }
}

variable "node_memory" {
  type        = number
  default     = 4096
  description = "memory per node (megabytes)"
  validation {
    condition     = var.node_memory >= 2048
    error_message = "minimum node memory: 2048"
  }
}

variable "node_disk" {
  type        = number
  default     = 20
  description = "disk size per node (gigabytes)"
  validation {
    condition     = var.node_disk >= 20
    error_message = "minimum node disk size: 20"
  }
}
