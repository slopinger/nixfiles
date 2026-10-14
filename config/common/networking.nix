{ lib, ... }: with lib; {
  networking = {
    useDHCP = false;
    dhcpcd.enable = false;
    useNetworkd = true;
    # Like Arch's systemd-timesyncd default.
    timeServers = mkDefault (map (n: "${toString n}.arch.pool.ntp.org") [ 0 1 2 3 ]);
  };

  systemd.network.enable = true;
  services.resolved.enable = true;
}
