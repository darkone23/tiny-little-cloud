
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
  type    = string
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
  token         = var.hcloud_token
  image         = var.base_image
  location      = "hil"
  server_type   = "cpx31"
  ssh_keys      = []
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
      "mkdir -p ~/.ssh",
      "touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys",
      "test ! -z \"$SSH_PUBKEY\" && (echo $SSH_PUBKEY >> ~/.ssh/authorized_keys)",
      # "cat ~/.ssh/authorized_keys",
      # "echo thar be yr keys",
      "bash -c 'curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | bash 2>&1 | tee /tmp/infect.log'"
    ]
  }

  provisioner "shell" {
    # 2300218 = packer ssh failed for some mysterious reason
    valid_exit_codes = [0, 2300218] # for some reason this is failing... maybe OOM ?
    inline = [
      "ps aux",
      # "swapon --show",
      "fallocate -l 4G /swapfile",
      "chmod 600 /swapfile",
      "mkswap /swapfile",
      "swapon /swapfile",
      # # "swapon --show",
      # "echo hello again",
      # "free -m",
      # "free && sync && echo 3 > /proc/sys/vm/drop_caches && free",
      # "echo 1 > /proc/sys/vm/drop_caches",
      # "echo 2 > /proc/sys/vm/drop_caches",
      # "echo 3 > /proc/sys/vm/drop_caches",
      # "free -m",
    ]
  }
  #
  # provisioner "shell" {
  #   env = {
  #     BUILDER     = "packer"
  #     DEBIAN_FRONTEND = "noninteractive"
  #   }
  #   inline = [
  #     # "ls -lah",
  #     # "apt-get update && apt-get --with-new-pkgs upgrade -y",
  #     # "apt-get install curl -y",
  #     "mkdir -p /packerbuild",
  #     "curl -L https://github.com/a8m/envsubst/releases/download/v1.4.3/envsubst-`uname -s`-`uname -m` -o /packerbuild/envsubst",
  #     "chmod +x /packerbuild/envsubst",
  #     "test -f /packerbuild/envsubst"
  #   ]
  # }


  # TODO: add initial configuration.nix changes

  # we need to leave the packer RSA key in this image for the provision connection to work
  # but also neeed to somehow 'merge' the generated configuration.nix with our desired base target

  # provisioner "file" {
  #   source      = "configuration.tmpl.nix"
  #   destination = "/packerbuild/configuration.tmpl.nix"
  # }

  provisioner "file" {
    source      = "networking.nix"
    destination = "/etc/nixos/networking.nix"
  }

  #
  # provisioner "shell" {
  #   env = {
  #     SSH_PUBKEY = var.ssh_pubkey
  #   }
  #   inline = [
  #     "echo hello from provisioner",
  #     #
  #     # "/packerbuild/envsubst -i /packerbuild/configuration.tmpl.nix -o /etc/nixos/configuration.nix",
  #     # "mv /packerbuild/networking.nix /etc/nixos/networking.nix",
  #     # "rm -rf /packerbuild",
  #
  #     "cat /etc/nixos/configuration.nix",
  #     "cat /etc/nixos/networking.nix",
  #
  #   ]
  # }

  provisioner "shell" {
    env = {
      NIX_PATH = "/root/.nix-defexpr/channels:nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos:nixos-config=/etc/nixos/configuration.nix:/nix/var/nix/profiles/per-user/root/channels"
    }
    inline = [
      # "echo hello again provisioner",
      "bash 2>&1 --login -c \"nix-shell -p nixos-rebuild --run 'nixos-rebuild build'\"",
      "echo 'nixos-rebuild: OK'",
    ]
  }



  provisioner "shell" {
    # ssh will no longer work once this profile is applied...
    expect_disconnect = true
    env = {
      NIX_PATH = "/root/.nix-defexpr/channels:nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos:nixos-config=/etc/nixos/configuration.nix:/nix/var/nix/profiles/per-user/root/channels"
    }
    inline = [
      "bash 2>&1 --login -c \"nix-shell -p nixos-rebuild --run 'nixos-rebuild switch'\""
    ]
  }


}
