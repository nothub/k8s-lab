terraform {
  required_version = ">= 0.14"
  required_providers {
    libvirt = {
      // https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs
      source  = "dmacvicar/libvirt"
      version = "0.7.6"
    }
  }
}

locals {
  config_yaml = file("${path.module}/../config.yaml")
  config      = yamldecode(local.config_yaml)
  gate_node   = local.config["hosts"]["gate"]
  ctrl_nodes  = local.config["hosts"]["ctrl"]
  work_nodes  = local.config["hosts"]["work"]
  net         = local.config["net"]
}

provider "libvirt" {
  uri = var.qemu_uri
}

resource "libvirt_network" "lab" {
  name      = "k8s"
  mode      = "nat"
  domain    = local.net["domain"]
  addresses = [local.net["cidr"]]
  dhcp {
    enabled = false
  }
  dns {
    enabled = true
  }
}

# os base image
resource "libvirt_volume" "debian_12" {
  name   = "debian_12"
  source = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
}

# cloudinit disk
data "template_file" "user_data" {
  template = templatefile("${path.module}/cloudinit.tftpl", {
    pub_keys = yamldecode(file("${path.module}/../secrets/ssh.yaml")).pub_keys
  })
}
resource "libvirt_cloudinit_disk" "cloudinit" {
  name      = "cloudinit.iso"
  user_data = data.template_file.user_data.rendered
}

# persistent disks
resource "libvirt_volume" "gate_disk" {
  name           = "gate.qcow2"
  base_volume_id = libvirt_volume.debian_12.id
  size           = var.ctrl_node_disk * 1024 * 1024 * 1024
}
resource "libvirt_volume" "ctrl_disk" {
  count          = length(local.ctrl_nodes)
  name           = "ctrl${count.index}.qcow2"
  base_volume_id = libvirt_volume.debian_12.id
  size           = var.ctrl_node_disk * 1024 * 1024 * 1024
}
resource "libvirt_volume" "work_disk" {
  count          = length(local.work_nodes)
  name           = "work${count.index}.qcow2"
  base_volume_id = libvirt_volume.debian_12.id
  size           = var.work_node_disk * 1024 * 1024 * 1024
}

# virtual machines
resource "libvirt_domain" "gate_node" {
  name      = "gate"
  vcpu      = var.gate_node_cores
  memory    = var.gate_node_memory
  cloudinit = libvirt_cloudinit_disk.cloudinit.id
  network_interface {
    network_id = libvirt_network.lab.id
    addresses  = [local.gate_node["ipv4"]]
    mac        = local.gate_node["mac"]
  }
  disk {
    volume_id = libvirt_volume.gate_disk.id
  }
}
resource "libvirt_domain" "ctrl_node" {
  count     = length(local.ctrl_nodes)
  name      = "ctrl${count.index}"
  vcpu      = var.ctrl_node_cores
  memory    = var.ctrl_node_memory
  cloudinit = libvirt_cloudinit_disk.cloudinit.id
  network_interface {
    network_id = libvirt_network.lab.id
    addresses  = [local.ctrl_nodes[count.index]["ipv4"]]
    mac        = local.ctrl_nodes[count.index]["mac"]
  }
  disk {
    volume_id = libvirt_volume.ctrl_disk[count.index].id
  }
}
resource "libvirt_domain" "work_node" {
  count     = length(local.work_nodes)
  name      = "work${count.index}"
  vcpu      = var.work_node_cores
  memory    = var.work_node_memory
  cloudinit = libvirt_cloudinit_disk.cloudinit.id
  network_interface {
    network_id = libvirt_network.lab.id
    addresses  = [local.work_nodes[count.index]["ipv4"]]
    mac        = local.work_nodes[count.index]["mac"]
  }
  disk {
    volume_id = libvirt_volume.work_disk[count.index].id
  }
}
