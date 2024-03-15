variable "qemu_uri" {
  type    = string
  default = "qemu:///system"
}

variable "gate_node_cores" {
  type        = number
  default     = 2
  description = "vcpu cores per gate node"
  validation {
    condition     = var.gate_node_cores >= 1
    error_message = "minimum vcpu cores: 1"
  }
}

variable "ctrl_node_cores" {
  type        = number
  default     = 2
  description = "vcpu cores per control node"
  validation {
    condition     = var.ctrl_node_cores >= 1
    error_message = "minimum vcpu cores: 1"
  }
}

variable "work_node_cores" {
  type        = number
  default     = 2
  description = "vcpu cores per worker node"
  validation {
    condition     = var.work_node_cores >= 1
    error_message = "minimum vcpu cores: 1"
  }
}

variable "gate_node_memory" {
  type        = number
  default     = 3072
  description = "memory (megabytes) per gate node"
  validation {
    condition     = var.gate_node_memory >= 2048
    error_message = "minimum node memory: 2048"
  }
}

variable "ctrl_node_memory" {
  type        = number
  default     = 3072
  description = "memory (megabytes) per control node"
  validation {
    condition     = var.ctrl_node_memory >= 2048
    error_message = "minimum node memory: 2048"
  }
}

variable "work_node_memory" {
  type        = number
  default     = 4096
  description = "memory (megabytes) per worker node"
  validation {
    condition     = var.work_node_memory >= 2048
    error_message = "minimum node memory: 2048"
  }
}

variable "gate_node_disk" {
  type        = number
  default     = 20
  description = "disk size (gigabytes) per gate node"
  validation {
    condition     = var.gate_node_disk >= 20
    error_message = "minimum node disk size: 20"
  }
}

variable "ctrl_node_disk" {
  type        = number
  default     = 20
  description = "disk size (gigabytes) per control node"
  validation {
    condition     = var.ctrl_node_disk >= 20
    error_message = "minimum node disk size: 20"
  }
}

variable "work_node_disk" {
  type        = number
  default     = 20
  description = "disk size (gigabytes) per worker node"
  validation {
    condition     = var.work_node_disk >= 20
    error_message = "minimum node disk size: 20"
  }
}
