# Boybrowse encrypted Perl sync; browser builds live in the application flake.
{ inputs, config, ... }: {
  imports = [ ./caddy.nix inputs.boybrowse.nixosModules.default ];
  services.boybrowse-sync = {
    enable = true;
    backups.enable = true;
  };
  environment.systemPackages = [ config.services.boybrowse-sync.package ];
  services.caddy.virtualHosts."boybrowse-sync.freifick.net" = {
    logFormat = null;
    extraConfig = ''
      import security_headers
      request_body {
        max_size 5MiB
      }
      reverse_proxy 127.0.0.1:${toString config.services.boybrowse-sync.port}
    '';
  };
}
