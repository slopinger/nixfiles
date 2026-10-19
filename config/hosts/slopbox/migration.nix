# Move from the Arch install on the scsi0 disk (2026-10-17, booted for good 2026-10-19). Arch stays on its disk as a fallback.
# The first NixOS boot is a one-time EFI BootNext. nixos-boot-check makes NixOS the default
# boot entry once IPv4 and IPv6 work, or boots Arch once more if they don't come up within
# 10 minutes. Remove this file once Arch is no longer needed.
{ lib, pkgs, ... }: let
  # The Arch ESP on scsi0 ("Linux Boot Manager" in NVRAM)
  archEspPartuuid = "a433e76f-140f-4583-810d-3b373764e200";
in {
  # The NixOS entry in NVRAM is created by hand (efibootmgr, label "NixOS") and points at the
  # fixed \EFI\systemd\systemd-bootx64.efi; bootctl must not reorder entries behind our back.
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # A remote VM: don't hang in an emergency shell or after a panic. A reset (or the
  # reboot after a panic) returns to Arch until nixos-boot-check has succeeded once.
  systemd.enableEmergencyMode = false;
  boot.kernelParams = [ "panic=30" ];

  # The old Arch root, read-only, for anything the migration didn't carry over.
  fileSystems."/mnt/arch" = {
    device = "/dev/disk/by-uuid/8011e19f-c8af-4502-aa1e-a655675f9e66";
    fsType = "ext4";
    options = [ "ro" "nofail" "x-systemd.device-timeout=10s" ];
  };

  systemd.services.nixos-boot-check = {
    description = "Make NixOS the default boot entry once the network works, else boot Arch";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "!/var/lib/nixos-boot-check/ok";
    path = with pkgs; [ efibootmgr iputils util-linux gnugrep gnused coreutils systemd ];
    serviceConfig = {
      Type = "oneshot";
      StateDirectory = "nixos-boot-check";
    };
    script = ''
      entry() { efibootmgr -v | grep -i "GPT,$1" | head -n1 | sed -E 's/^Boot([0-9A-Fa-f]{4}).*/\1/'; }
      esp=$(lsblk -no PARTUUID "$(findmnt -no SOURCE /boot)")
      nixos=$(entry "$esp")
      arch=$(entry ${archEspPartuuid})
      echo "NixOS entry: ''${nixos:-none}, Arch entry: ''${arch:-none}"
      for _ in $(seq 60); do
        if ping -4 -c1 -W3 1.1.1.1 >/dev/null && ping -6 -c1 -W3 2606:4700:4700::1111 >/dev/null; then
          if [ -n "$nixos" ]; then
            rest=$(efibootmgr | sed -n 's/^BootOrder: //p' | tr , '\n' | grep -vix "$nixos" | paste -sd,)
            efibootmgr -q -o "$nixos''${rest:+,$rest}"
          fi
          touch /var/lib/nixos-boot-check/ok
          echo "network is up; NixOS is the default boot entry"
          exit 0
        fi
        sleep 10
      done
      if [ -z "$arch" ]; then
        echo "no network after 10 minutes and no Arch entry; staying up" >&2
        exit 1
      fi
      echo "no network after 10 minutes; rebooting into Arch once" >&2
      efibootmgr -q -n "$arch"
      systemctl reboot
    '';
  };
}
