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

provider "libvirt" {
  uri = "qemu:///system"
}

variable "ssh_key" {
  type    = string
  default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJwI2xmLrw4APecukfuLt+nrUNVFzzND/vENsQUTuyQP hub@desktop"
}

resource "libvirt_network" "lab" {
  name      = "k8s"
  mode      = "nat"
  domain    = "k8s.local"
  addresses = ["10.42.0.0/24"]
  dhcp {
    enabled = true
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

# persistent disk
resource "libvirt_volume" "lab" {
  name           = "lab.qcow2"
  base_volume_id = libvirt_volume.debian_12.id
  size           = 21474836480 # 20GB
}

resource "libvirt_domain" "lab" {
  name      = "lab"
  vcpu      = 2
  memory    = 4096
  cloudinit = libvirt_cloudinit_disk.cloudinit.id
  network_interface {
    network_id = libvirt_network.lab.id
    mac        = "00:00:F3:10:10:10"
  }
  disk {
    volume_id = libvirt_volume.lab.id
  }
}
