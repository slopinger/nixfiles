# Docker for test harnesses; no permanent containers.
# Docker-published ports bypass any host firewall: publish as 127.0.0.1:<port>:<port>
# unless they must be public.
{ ... }: {
  virtualisation.docker = {
    enable = true;
    liveRestore = true; # updating docker doesn't take the containers down
    logDriver = "journald";
  };
}
