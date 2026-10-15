# GitLab CE (Omnibus image) for https://git.freifick.net.
# Caddy terminates TLS and proxies to 127.0.0.1:8929; git over SSH is public on port 2222.
# State lives in bind mounts under /srv/gitlab ({config,logs,data}); /srv/gitlab/.env holds
# GITLAB_ROOT_PASSWORD, only used on first boot.
# Upgrades: bump the pinned tag along GitLab's upgrade path
# (https://gitlab-com.gitlab.io/support/toolbox/upgrade-path/), take a backup first.
{ config, ... }: let
  dir = "/srv/gitlab";
in {
  imports = [
    ./caddy.nix
    ./docker.nix
  ];

  # Import the preserved image on first boot without depending on registry access.
  systemd.services.gitlab-image-import = {
    requires = [ "docker.service" ];
    after = [ "docker.service" ];
    before = [ "docker-gitlab.service" ];
    serviceConfig.Type = "oneshot";
    path = [ config.virtualisation.docker.package ];
    script = ''
      if ! docker image inspect gitlab/gitlab-ce:19.4.2-ce.0 >/dev/null 2>&1; then
        docker load --input /root/arch-migration/gitlab-image.tar
      fi
    '';
  };
  systemd.services.docker-gitlab = {
    requires = [ "gitlab-image-import.service" ];
    after = [ "gitlab-image-import.service" ];
  };

  networking.firewall.allowedTCPPorts = [ 2222 ];

  virtualisation.oci-containers.containers.gitlab = {
    image = "gitlab/gitlab-ce:19.4.2-ce.0";
    hostname = "git.freifick.net";
    ports = [
      "127.0.0.1:8929:80"
      "2222:22"
    ];
    volumes = [
      "${dir}/config:/etc/gitlab"
      "${dir}/logs:/var/log/gitlab"
      "${dir}/data:/var/opt/gitlab"
    ];
    environmentFiles = [ "${dir}/.env" ];
    environment.GITLAB_OMNIBUS_CONFIG = ''
      external_url 'https://git.freifick.net'

      # TLS is terminated by Caddy on the host
      nginx['listen_port'] = 80
      nginx['listen_https'] = false
      nginx['proxy_set_headers'] = { 'X-Forwarded-Proto' => 'https', 'X-Forwarded-Ssl' => 'on' }
      nginx['real_ip_trusted_addresses'] = ['172.16.0.0/12', '10.0.0.0/8', '192.168.0.0/16']
      nginx['real_ip_header'] = 'X-Forwarded-For'
      nginx['real_ip_recursive'] = 'on'
      gitlab_rails['trusted_proxies'] = ['172.16.0.0/12', '10.0.0.0/8', '192.168.0.0/16']
      letsencrypt['enable'] = false

      gitlab_rails['gitlab_shell_ssh_port'] = 2222
      gitlab_rails['time_zone'] = 'UTC'

      # no outgoing mail configured
      gitlab_rails['gitlab_email_enabled'] = false
      gitlab_rails['gitlab_email_from'] = 'gitlab@freifick.net'

      # trim what we don't use (RAM)
      registry['enable'] = false
      gitlab_pages['enable'] = false
      gitlab_kas['enable'] = false
      prometheus_monitoring['enable'] = false
      puma['worker_processes'] = 2
      sidekiq['concurrency'] = 10

      gitlab_rails['backup_keep_time'] = 604800
    '';
    extraOptions = [ "--shm-size=256m" ];
  };

  systemd.tmpfiles.rules = [
    "d ${dir} 0755 root root -"
  ];

  # Nightly backup (repositories + database), 7 days kept in ${dir}/data/backups.
  # Same disk only; a restore also needs config/gitlab-secrets.json and gitlab.rb.
  systemd.services.gitlab-backup = {
    description = "GitLab backup (repositories + database) into ${dir}/data/backups";
    requires = [ "docker-gitlab.service" ];
    after = [ "docker-gitlab.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${config.virtualisation.docker.package}/bin/docker exec gitlab gitlab-backup create CRON=1 STRATEGY=copy";
    };
  };
  systemd.timers.gitlab-backup = {
    description = "Nightly GitLab backup";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 03:30:00";
      RandomizedDelaySec = "15m";
      Persistent = true;
    };
  };

  # GitLab sets its own security headers; we only add HSTS.
  services.caddy.virtualHosts."git.freifick.net" = {
    logFormat = null;
    extraConfig = ''
      header {
        Strict-Transport-Security "max-age=31536000"
        -Server
      }
      reverse_proxy 127.0.0.1:8929
    '';
  };
}
