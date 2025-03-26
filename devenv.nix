{ pkgs, lib, config, inputs, ... }:

{
  # https://devenv.sh/basics/
  # env.GREET = "devenv";
  env.PULUMI_CONFIG_PASSPHRASE = "";

  # https://devenv.sh/packages/
  packages = [
    pkgs.git
    pkgs.docker
    pkgs.oras

    pkgs.hcloud
    # pkgs.awscli2
    # pkgs.awsebcli
    
    # (pkgs.google-cloud-sdk.withExtraComponents( with pkgs.google-cloud-sdk.components; [
    #   # gke-gcloud-auth-plugin
    # ]))

    pkgs.black
    pkgs.mypy
    pkgs.nil
    pkgs.python3Packages.python-lsp-server
    pkgs.pulumi-bin

    pkgs.packer
    pkgs.jq
  ];

  difftastic.enable = true;

  # https://devenv.sh/languages/
  languages.python.enable = true;
  languages.python.venv.enable = true;
  languages.python.venv.requirements = ''
    pulumi>=3.153.0,<4.0.0
    pulumi-hcloud>=1.0.0,<2.0.0
  '';

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
