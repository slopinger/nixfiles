# Proxmox / QEMU VM (UEFI, virtio)
{ modulesPath, ... }: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.loader = {
    systemd-boot = {
      enable = true;
      editor = false;
    };
    efi.canTouchEfiVariables = true;
    timeout = 3;
  };
  boot.initrd.systemd.enable = true;
  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];

  services.qemuGuest.enable = true;

  freifick = {
    machine-type.virtual = true;
    deployment.tags = [ "pve-vm" ];
  };
}
