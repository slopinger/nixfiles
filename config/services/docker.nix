# Docker-published ports bypass the host firewall: publish as 127.0.0.1:<port>:<port>
# unless they must be public.
{ ... }: {
  virtualisation.docker = {
    enable = true;
    liveRestore = true; # updating docker doesn't take the containers down
    logDriver = "journald";
  };
  virtualisation.oci-containers.backend = "docker";
}
