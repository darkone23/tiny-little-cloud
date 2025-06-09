
// https://community.hetzner.com/tutorials/custom-os-images-with-packer

// https://nixos.wiki/wiki/Install_NixOS_on_Hetzner_Cloud

variable "ssh_pubkey" {
  type      = string
  sensitive = true
  default   = "${env("SSH_PUBKEY")}"
}

variable "hcloud_token" {
  type      = string
  sensitive = true
  default   = "${env("HCLOUD_TOKEN")}"
}

variable "base_image" {
  type = string
  # default = "nixos-minimal-25.05"
  default = "debian-12"
}

variable "nix_channel" {
  type    = string
  default = "nixos-25.05"
}

variable "version" {
  type    = string
  default = "snapshot-{{ timestamp }}"
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
  token       = var.hcloud_token
  image       = var.base_image
  location    = "hil"
  server_type = "cpx31"
  ssh_keys    = []
  # user_data_file     = "cloud-init.yml"
  ssh_username  = "root"
  snapshot_name = "${var.nix_channel}-${var.version}"
  snapshot_labels = {
    base    = var.base_image,
    version = var.version,
    os      = var.nix_channel,
    name    = "${var.nix_channel}-${var.version}"
  }
}

build {
  sources = ["source.hcloud.base-amd64"]
  provisioner "shell" {
    env = {
      BUILDER     = "packer"
      PROVIDER    = "hetznercloud"
      NIX_CHANNEL = var.nix_channel
      SSH_PUBKEY  = var.ssh_pubkey
    }
    inline = [
      "whoami",
      "mkdir -p ~/.ssh",
      "test ! -z \"$SSH_PUBKEY\" && echo $SSH_PUBKEY > ~/.ssh/authorized_keys",
      "chmod 600 ~/.ssh/authorized_keys",
      "echo -n 'installed-pubkey:'",
      "cat /root/.ssh/authorized_keys",
      "bash -c 'curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | bash 2>&1 | tee /tmp/infect.log'"
    ]
  }
}
