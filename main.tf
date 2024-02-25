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
  ctrl_node_count = 2
  work_node_count = 3
}

provider "libvirt" {
  uri = var.qemu_uri
}

resource "libvirt_network" "lab" {
  name      = "k8s"
  mode      = "nat"
  domain    = "k8s.local"
  addresses = ["10.42.0.0/24"]
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
  template = templatefile("${path.module}/cloudinit.tftpl", { ssh_key = var.ssh_key })
}
resource "libvirt_cloudinit_disk" "cloudinit" {
  name      = "cloudinit.iso"
  user_data = data.template_file.user_data.rendered
}

# persistent disks
resource "libvirt_volume" "ctrl_disk" {
  count          = local.ctrl_node_count
  name           = "ctrl-${count.index}.qcow2"
  base_volume_id = libvirt_volume.debian_12.id
  size           = var.node_disk * 1024 * 1024 * 1024
}
resource "libvirt_volume" "work_disk" {
  count          = local.work_node_count
  name           = "work-${count.index}.qcow2"
  base_volume_id = libvirt_volume.debian_12.id
  size           = var.node_disk * 1024 * 1024 * 1024
}

# virtual machines
resource "libvirt_domain" "ctrl_node" {
  count     = local.ctrl_node_count
  name      = "ctrl-${count.index}"
  vcpu      = var.node_cores
  memory    = var.node_memory
  cloudinit = libvirt_cloudinit_disk.cloudinit.id
  network_interface {
    network_id = libvirt_network.lab.id
    addresses  = ["10.42.0.1${count.index}"]
    mac        = "00:00:F3:10:42:1${count.index}"
  }
  disk {
    volume_id = libvirt_volume.ctrl_disk[count.index].id
  }
}
resource "libvirt_domain" "work_node" {
  count     = local.work_node_count
  name      = "work-${count.index}"
  vcpu      = var.node_cores
  memory    = var.node_memory
  cloudinit = libvirt_cloudinit_disk.cloudinit.id
  network_interface {
    network_id = libvirt_network.lab.id
    addresses  = ["10.42.0.2${count.index}"]
    mac        = "00:00:F3:10:42:2${count.index}"
  }
  disk {
    volume_id = libvirt_volume.work_disk[count.index].id
  }
}
