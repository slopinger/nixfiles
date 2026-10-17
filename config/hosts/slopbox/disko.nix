# Dedicated NixOS disk (/dev/sdb); the running Arch disk (/dev/sda) is never touched.
# A 4 GiB ESP: systemd-boot keeps a kernel + initrd per generation on it, and
# linuxPackages_latest with a systemd initrd quickly fills the 1 GiB Arch layout.
# Root is btrfs with subvolumes, so / can be snapshotted without /nix and noisy state.
{ inputs, ... }: let
  mountOptions = [ "compress=zstd:1" "noatime" ];
in {
  imports = [
    inputs.disko.nixosModules.disko
  ];
  disko.devices.disk.sdb = {
    device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi1";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          label = "nixos-esp";
          type = "EF00";
          size = "4G";
          content = {
            type = "filesystem";
            format = "vfat";
            extraArgs = [ "-F" "32" "-n" "NIXOS-ESP" ];
            mountpoint = "/boot";
            mountOptions = [ "fmask=0077" "dmask=0077" ];
          };
        };
        root = {
          label = "nixos-root";
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" "-L" "nixos-root" ];
            subvolumes = {
              "@root" = { mountpoint = "/"; inherit mountOptions; };
              "@nix" = { mountpoint = "/nix"; inherit mountOptions; };
              "@home" = { mountpoint = "/home"; inherit mountOptions; };
              "@srv" = { mountpoint = "/srv"; inherit mountOptions; };
              "@var-lib" = { mountpoint = "/var/lib"; inherit mountOptions; };
              "@var-log" = { mountpoint = "/var/log"; inherit mountOptions; };
              # Docker images/containers: churn that should stay out of /var/lib snapshots.
              "@docker" = { mountpoint = "/var/lib/docker"; inherit mountOptions; };
              # Top-level home for btrfs snapshots (`btrfs subvolume snapshot -r /home /.snapshots/...`).
              "@snapshots" = { mountpoint = "/.snapshots"; inherit mountOptions; };
            };
          };
        };
      };
    };
  };
}
