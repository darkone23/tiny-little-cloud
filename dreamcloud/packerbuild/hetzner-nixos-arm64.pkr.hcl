
// https://community.hetzner.com/tutorials/custom-os-images-with-packer

// https://nixos.wiki/wiki/Install_NixOS_on_Hetzner_Cloud

variable "base_image" {
  type    = string
  default = "debian-12"
}

variable "output_name" {
  type    = string
  default = "snapshot"
}

variable "version" {
  type    = string
  default = "v1.0.0"
}

packer {
  required_plugins {
    hcloud = {
      source  = "github.com/hetznercloud/hcloud"
      version = ">= 1.6.0"
    }
  }
}

source "hcloud" "base-amd64" {
  image         = var.base_image
  location      = "nbg1"
  server_type   = "cx22"
  ssh_keys      = []
  user_data     = ""
  ssh_username  = "root"
  snapshot_name = "${var.output_name}-${var.version}"
  snapshot_labels = {
    base    = var.base_image,
    version = var.version,
    name    = "${var.output_name}-${var.version}"
  }
}

build {
  sources = ["source.hcloud.base-amd64"]
  provisioner "shell" {
    env = {
      BUILDER = "packer"
    }
    inline = [
      "apt-get update",
      "apt-get install -y wget fail2ban cowsay",
      "/usr/games/cowsay 'Hi Hetzner Cloud' > /etc/motd",
    ]
  }
}
