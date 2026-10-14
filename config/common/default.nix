{ lib, pkgs, ... }: let
  inherit (lib) mkDefault;
in {
  imports = [
    ./networking.nix
    ./nix.nix
    ./openssh.nix
    ./users.nix
    ../../modules
  ];
  # what `pacman -Qqe` had on the Arch install
  environment.systemPackages = with pkgs; [
    kitty.terminfo
    bat
    dnsutils # dig
    htop
    ripgrep
    uutils-coreutils # uu-* prefixed (see pkgs/), GNU coreutils stay default
    git
    bmon
    bottom
    man-pages
    man-pages-posix
    unzip
    zip
    fd
    figlet
    whois
    restic
    fend
    shellcheck
    tmux
    vim
    curl
    python3
  ];

  freifick.deployment.tags = [ "all" ];

  documentation.man.enable = true;
  documentation.dev.enable = true;

  # /tmp is a tmpfs on Arch (systemd tmp.mount)
  boot.tmp.useTmpfs = mkDefault true;

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };
  users.mutableUsers = mkDefault false;

  # i18n puts LANG into pam_env as well, so processes started by sshd without a login shell
  # (e.g. `ssh -t host tmux attach`) get UTF-8 (on Arch this was /etc/environment).
  i18n.defaultLocale = mkDefault "en_US.UTF-8";
  time.timeZone = mkDefault "UTC";
}
