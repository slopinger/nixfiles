{ modulesPath, ... }: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Intel Xeon E5-2695 v2 (KVM, nested virtualisation available)
  boot.kernelModules = [ "kvm-intel" ];

  # File systems come from disko.nix (btrfs root on /dev/sdb). No swap, as on Arch.
  boot.supportedFilesystems = [ "btrfs" ];
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };
  # The 4 GiB ESP holds ~50 kernel/initrd pairs; keep the boot menu bounded anyway.
  boot.loader.systemd-boot.configurationLimit = 30;
}
