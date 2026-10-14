# Caddy terminates TLS for every site on this host. Site blocks live with their services
# (freifick-net.nix, gitlab.nix); `import security_headers` in new ones.
{ lib, ... }: {
  freifick.deployment.tags = [ "web" ];

  networking.firewall.allowedTCPPorts = [ 80 443 ];
  networking.firewall.allowedUDPPorts = [ 443 ]; # HTTP/3

  services.caddy = {
    enable = true;
    # Some names (slop.kyouma.net) have a CAA record that only permits letsencrypt.org,
    # so don't let Caddy fall back to ZeroSSL.
    acmeCA = "https://acme-v02.api.letsencrypt.org/directory";
    logFormat = lib.mkDefault "level INFO";
    globalConfig = ''
      # Admin API only on a unix socket restricted to caddy:caddy (no TCP listener).
      admin "unix//run/caddy/admin.socket"
    '';
    # Reusable security headers. HSTS >= 6 months is required for an A+ on SSL Labs.
    extraConfig = ''
      (security_headers) {
        header {
          Strict-Transport-Security "max-age=31536000"
          X-Content-Type-Options "nosniff"
          X-Frame-Options "DENY"
          Referrer-Policy "strict-origin-when-cross-origin"
          -Server
        }
      }
    '';
  };
  # for the admin socket (the upstream unit allows writes to /run/caddy)
  systemd.services.caddy.serviceConfig.RuntimeDirectory = "caddy";
}
