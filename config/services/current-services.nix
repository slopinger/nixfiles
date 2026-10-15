# Runtime state and private keys are copied separately; never import secrets into Nix.
{ inputs, lib, pkgs, ... }: {
  imports = map (name: inputs.${name}.nixosModules.default)
    [ "trough" "mayfly" "dn42" "driftline" "server-backups" ];

  services.trough = {
    enable = true;
    host = "fedi.freifick.net";
    environmentFile = "/etc/trough.env";
  };
  systemd.services.trough.serviceConfig.EnvironmentFile = lib.mkAfter [ "-/etc/trough-secrets.env" ];
  services.mayfly = { enable = true; url = "https://slopbox.freifick.net"; };
  services.driftline = { enable = true; domain = "driftline.freifick.net"; };
  services.slop-services-backup.enable = true;
  services.slop-dn42.enable = true;
  # Keep mutable peer snippets for the existing automatic provisioning tools.
  services.bird.config = lib.mkForce (builtins.replaceStrings
    [ "/etc/bird/roa_dn42" ] [ "/var/lib/dn42-roa/roa_dn42" ]
    (builtins.readFile ./dn42-bird.conf));

  # Preserve numeric ownership of migrated service state.
  users.users = {
    slop.group = "slop";
    caddy.uid = lib.mkForce 968;
    slopd.uid = 967;
    trough.uid = 966;
    mayfly.uid = 963;
  };
  users.groups = {
    slop.gid = 1000;
    caddy.gid = lib.mkForce 968;
    slopd.gid = 967;
    trough.gid = 965;
    mayfly.gid = 963;
  };
  systemd.tmpfiles.rules = [
    "z /etc/wireguard/dn42.key 0640 root systemd-network -"
  ];
  # Arch stores Caddy's data directly here, rather than in .local/share/caddy.
  systemd.services.caddy.environment.XDG_DATA_HOME = lib.mkForce "/var/lib";
  systemd.services.dn42-auto-peer = {
    description = "DN42 registry and automatic peering monitor";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "bird.service" ];
    wants = [ "network-online.target" "bird.service" ];
    path = with pkgs; [ sudo git openssh iproute2 systemd bird3 wireguard-tools iputils ];
    serviceConfig = {
      User = "slop";
      Group = "slop";
      WorkingDirectory = "/home/slop/src/dn42";
      ExecStart = "${pkgs.dn42}/bin/dn42-auto-peer-daemon.py";
      Restart = "on-failure";
      RestartSec = 15;
    };
  };
  services.caddy.virtualHosts = {
    "fedi.freifick.net".extraConfig = ''
      import security_headers
      encode zstd gzip
      request_body {
        max_size 90MB
      }
      reverse_proxy 127.0.0.1:8790
      log
    '';
    "slopbox.freifick.net" = {
      logFormat = null;
      extraConfig = ''
        import security_headers
        request_body {
          max_size 202MiB
        }
        reverse_proxy 127.0.0.1:8791 {
          header_up X-Real-IP {remote_host}
        }
      '';
    };
    "mayfly.freifick.net" = {
      logFormat = null;
      extraConfig = ''
        import security_headers
        redir https://slopbox.freifick.net{uri} 308
      '';
    };
    "driftline.freifick.net".extraConfig = ''
      import security_headers
      encode zstd gzip
      header {
        Content-Security-Policy "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self'; connect-src 'self'; worker-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'"
        Cache-Control "no-cache"
      }
    '';
  };
  environment.systemPackages = with pkgs; [ rsync sqlite docker-compose wireguard-tools dn42 trough mayfly therapie-mcp arbeitsagentur-mcp nodejs go ];
}
