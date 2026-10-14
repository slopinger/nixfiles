# /dev/sda (96G, GPT). Partition and filesystem labels match the existing Arch install
# (partlabels ESP/root, fs labels ESP/root), so this mounts the current disk as is.
{ inputs, ... }: {
  imports = [
    inputs.disko.nixosModules.disko
  ];
  disko.devices.disk.sda = {
    device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          label = "ESP";
          type = "EF00";
          size = "1G";
          content = {
            type = "filesystem";
            format = "vfat";
            extraArgs = [ "-F" "32" "-n" "ESP" ];
            mountpoint = "/boot";
            mountOptions = [ "fmask=0077" "dmask=0077" ];
          };
        };
        root = {
          label = "root";
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            extraArgs = [ "-L" "root" ];
            mountpoint = "/";
          };
        };
      };
    };
  };
}
