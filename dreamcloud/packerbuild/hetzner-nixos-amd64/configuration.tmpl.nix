{ pkgs, ... }:

let
  # this file is templated by envsubst
  # so below values get templated via env vars
  # use double dollar sign to escape
  ssh_pubkey = "${SSH_PUBKEY}";

  lix_from_src =
    # from https://lix.systems/add-to-config/
    # This includes the Lix NixOS module in your configuration along with the
    # matching version of Lix itself.
    #
    # The sha256 hashes were obtained with the following command in Lix (n.b.
    # this relies on --unpack, which is only in Lix and CppNix > 2.18):
    # nix store prefetch-file --name source --unpack https://git.lix.systems/lix-project/lix/archive/2.93.0.tar.gz
    #
    # Note that the tag (e.g. 2.93.0) in the URL here is what determines
    # which version of Lix you'll wind up with.
    (let
      module = fetchTarball {
        name = "source";
        url = "https://git.lix.systems/lix-project/nixos-module/archive/2.93.0.tar.gz";
        sha256 = "sha256-11R4K3iAx4tLXjUs+hQ5K90JwDABD/XHhsM9nkeS5N8=";
      };
      lixSrc = fetchTarball {
        name = "source";
        url = "https://git.lix.systems/lix-project/lix/archive/2.93.0.tar.gz";
        sha256 = "sha256-hsFe4Tsqqg4l+FfQWphDtjC79WzNCZbEFhHI8j2KJzw=";
      };
      # This is the core of the code you need; it is an exercise to the
      # reader to write the sources in a nicer way, or by using npins or
      # similar pinning tools.
      in import "$${module}/module.nix" { lix = lixSrc; }
    );
in {
  imports = [
    ./hardware-configuration.nix
    ./networking.nix # generated at runtime by nixos-infect   
    lix_from_src
  ];

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  swapDevices = [{
    device = "/swapfile";
    size = 4 * 1024; # 2GB
  }];

  systemd.oomd.enable = false;
  services.earlyoom = {
      enable = true;
      freeSwapThreshold = 2;
      freeMemThreshold = 2;
      extraArgs = [
          # "-g"
          # "--avoid '^(X|plasma.*|konsole|kwin)$'"
          # "--prefer '^(electron|libreoffice|gimp)$'"
      ];
  };

  networking.hostName = "hetzner-nixos";
  networking.domain = "";

  services.openssh.enable = true;
  programs.mosh.enable = true;

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };


  # users.users.root.openssh.authorizedKeys.keys = [
    # ssh_pubkey
  # ];

  users.groups.nixos = {};
  users.users.nixos.openssh.authorizedKeys.keys = [
    ssh_pubkey
  ];

  users.users.nixos = {
    isNormalUser = true;
    shell = pkgs.bash;
    description = "nixos";
    extraGroups = [ 
      "wheel" "nixos"
    ];
    packages = with pkgs; [
      git
    ];
  };

  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  nix = {
    # package = pkgs.lix;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  system.stateVersion = "23.11";
}
