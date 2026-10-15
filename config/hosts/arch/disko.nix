# Dedicated NixOS disk; the existing Arch disk is untouched.
{ inputs, ... }: {
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
          size = "1G";
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
            type = "filesystem";
            format = "ext4";
            extraArgs = [ "-L" "nixos-root" ];
            mountpoint = "/";
          };
        };
      };
    };
  };
}
