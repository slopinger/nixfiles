# The freifick.net server: Proxmox VM, 12 vCPUs, 15 GiB RAM, no swap.
# Public: 22 (sshd), 80/443 (Caddy), 2222 (GitLab git-over-SSH). Everything else binds to loopback.
{ pkgs, ... }: {
  imports = [
    ../../common
    ../../profiles/headless.nix
    ../../profiles/qemu.nix
    ../../services/freifick-net.nix
    ../../services/gitlab.nix
    ../../services/current-services.nix
    ./disko.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "slop";
  networking.domain = "kyouma.net";
  networking.firewall.enable = false;
  freifick.deployment.targetHost = "freifick.net";

  # Arch's `linux` package tracks the latest stable kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.firewall.allowedTCPPorts = [ 22 ];

  # DNS names: freifick.net, www.freifick.net, git.freifick.net (Cloudflare, DNS-only), slop.kyouma.net
  systemd.network.networks."10-wan" = {
    matchConfig.MACAddress = "bc:24:11:e7:2e:6a";
    address = [
      "45.150.123.24/32"
      "2a0f:be01:0:100::113/128"
    ];
    dns = [
      "1.1.1.1"
      "1.0.0.1"
      "2606:4700:4700::1111"
      "2606:4700:4700::1001"
    ];
    networkConfig.IPv6AcceptRA = false;
    routes = [
      { Gateway = "169.254.1.1"; GatewayOnLink = true; }
      { Gateway = "fe80::1"; }
    ];
  };

  system.stateVersion = "26.11";
}
