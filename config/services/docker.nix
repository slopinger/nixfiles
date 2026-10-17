# Docker for test harnesses; no permanent containers.
# Docker-published ports bypass any host firewall: publish as 127.0.0.1:<port>:<port>
# unless they must be public.
{ ... }: {
  virtualisation.docker = {
    enable = true;
    liveRestore = true; # updating docker doesn't take the containers down
    logDriver = "journald";
    # Images live in the system containerd's store (/var/lib/containerd), as on Arch,
    # instead of the containerd that dockerd would start under /var/lib/docker.
    daemon.settings = {
      containerd = "/run/containerd/containerd.sock";
      features.containerd-snapshotter = true;
    };
  };
  virtualisation.containerd.enable = true;
  systemd.services.docker = {
    requires = [ "containerd.service" ];
    after = [ "containerd.service" ];
  };
}
