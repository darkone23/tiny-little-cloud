{ pkgs, lib, config, inputs, ... }:

let
  customPython3 = pkgs.python3.withPackages(ps: [
    ps.python-lsp-server    
  ]);
in {
  # https://devenv.sh/basics/
  name = "tiny-little-cloud";
  # env.GREET = "${config.name}";

  env.PULUMI_CONFIG_PASSPHRASE = "";

  # https://devenv.sh/packages/
  packages = [
    pkgs.git

    pkgs.pulumi-bin
    pkgs.hcloud
    pkgs.packer
    pkgs.ansible

    pkgs.docker
    pkgs.oras
    pkgs.skopeo
    pkgs.regctl

    pkgs.s5cmd
    pkgs.ssh-to-age

    pkgs.black
    pkgs.mypy
    pkgs.nil

    pkgs.just
    pkgs.netcat
    pkgs.openssl

    pkgs.nushell
    

  ];

  difftastic.enable = true;

  # https://devenv.sh/languages/
  languages.python.enable = true;
  languages.python.package = customPython3;
  languages.python.venv.enable = true;
  languages.python.venv.requirements = builtins.readFile ./dreamcloud/requirements.txt;

  # languages.go.enable = true;

  # https://devenv.sh/processes/
  # processes.cargo-watch.exec = "cargo-watch";

  # https://devenv.sh/services/
  # services.postgres.enable = true;

  # https://devenv.sh/scripts/
  # scripts.hello.exec = ''
  #   echo hello from $GREET
  # '';

  enterShell = ''
  '';

  # https://devenv.sh/tasks/
  # tasks = {
  #   "myproj:setup".exec = "mytool build";
  #   "devenv:enterShell".after = [ "myproj:setup" ];
  # };

  # https://devenv.sh/tests/
  enterTest = ''
  '';

  # https://devenv.sh/git-hooks/
  # git-hooks.hooks.shellcheck.enable = true;

  # See full reference at https://devenv.sh/reference/options/
}
