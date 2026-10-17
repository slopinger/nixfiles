#!/usr/bin/env bash
# Copy all state from the running Arch install into the installed NixOS root mounted at
# $1 (default /mnt; mount it with the host's disko mountScript). Run as root on Arch.
# Safe to repeat: the first run copies everything, the final run (services stopped) only the
# changes. Secrets are copied file to file and never printed.
set -euo pipefail
root=${1:-/mnt}
for m in "$root" "$root/boot" "$root/nix" "$root/home" "$root/var/lib"; do
  mountpoint -q "$m" || { echo "$m is not mounted" >&2; exit 1; }
done
[ -e "$root/nix/var/nix/profiles/system" ] || { echo "$root has no installed NixOS system" >&2; exit 1; }

rs() { rsync -aHAXS --numeric-ids --delete "$@"; }

# Home directories and service data, at the same paths. Owners keep their Arch IDs
# (slop 1000, trough 966/965, slopd 967, mayfly 963, caddy 968; pinned in the config).
rs /home/slop/ "$root/home/slop/"
rs /root/ "$root/root/"
rs --exclude=/arch /srv/ "$root/srv/"
for d in trough slopd mayfly caddy docker containerd; do
  [ -d "/var/lib/$d" ] && rs "/var/lib/$d/" "$root/var/lib/$d/"
done
# Same machine-id below, so `journalctl` on NixOS also shows the Arch journal.
rs /var/log/journal/ "$root/var/log/journal/"
rs /var/log/caddy/ "$root/var/log/caddy/"

# Host identity and runtime secrets (deliberately not in Nix)
install -m 0444 /etc/machine-id "$root/etc/machine-id"
install -d -m 0755 "$root/etc/ssh" "$root/etc/wireguard"
cp -a /etc/ssh/ssh_host_* "$root/etc/ssh/"
cp -a /etc/wireguard/dn42.key /etc/wireguard/dn42.pub "$root/etc/wireguard/"
cp -a /etc/trough-secrets.env "$root/etc/"

# Tools installed with `nix profile` (claude-code, agy, github-mcp-server, ...) and their
# history, so the profile links in ~/.local/state/nix/profiles keep resolving. The copied
# gcroots/auto links point at those profile links and protect them from garbage collection.
nix=/nix/var/nix/profiles/default/bin/nix
for p in /home/slop/.local/state/nix/profiles/profile-*-link /nix/var/nix/profiles/per-user/root/profile-*-link; do
  [ -e "$p" ] && "$nix" copy --no-check-sigs --to "local?root=$root" "$(readlink -f "$p")"
done
install -d "$root/nix/var/nix/profiles/per-user/root"
cp -a /nix/var/nix/profiles/per-user/root/profile* "$root/nix/var/nix/profiles/per-user/root/"
cp -a /nix/var/nix/gcroots/auto/. "$root/nix/var/nix/gcroots/auto/"

# Everything else Nix does not describe, for reference: all of /etc, hand-deployed tools
# and the other logs. The whole Arch root also stays mounted read-only at /mnt/arch.
install -d -m 0700 "$root/srv/arch"
rs /etc/ "$root/srv/arch/etc/"
rs /usr/local/ "$root/srv/arch/usr/local/"
rs /opt/ "$root/srv/arch/opt/"
rs --exclude=/journal --exclude=/caddy /var/log/ "$root/srv/arch/var/log/"
echo "copied Arch state into $root"
