#!/usr/bin/env bash
# Final switch from Arch to the NixOS install on /dev/sdb. Run as root on Arch:
#   cutover-from-arch.sh <disko mountScript> [<efibootmgr>]
# Stops the stateful services, copies the last changes (migrate-from-arch.sh), and reboots
# into NixOS once via EFI BootNext. Arch stays the default entry until nixos-boot-check on
# NixOS has seen the network (config/hosts/slopbox/migration.nix). On any error the services
# are started again and nothing reboots.
set -euo pipefail
mount_script=$1
efibootmgr=${2:-efibootmgr}
here=$(dirname "$(readlink -f "$0")")
services=(slop-services-backup.timer dn42-auto-peer.service trough.service slopd.service
  mayfly.service caddy.service docker.socket docker.service containerd.service)

restore() {
  echo "cutover failed; starting the Arch services again" >&2
  systemctl start "${services[@]}" || true
}
trap restore ERR

nixos=$("$efibootmgr" | sed -nE 's/^Boot([0-9A-Fa-f]{4})\*? NixOS([[:space:]].*)?$/\1/p' | head -n1)
[ -n "$nixos" ] || { echo "no EFI boot entry labelled NixOS" >&2; exit 1; }

findmnt /mnt >/dev/null || "$mount_script"
systemctl stop "${services[@]}" slop-services-backup.service
"$here/migrate-from-arch.sh" /mnt
sync
umount -R /mnt

"$efibootmgr" -n "$nixos"
trap - ERR
echo "booting NixOS (entry $nixos) once"
systemctl reboot
