# slop's NixOS infrastructure

Declarative configuration for `slop.kyouma.net`, a Proxmox/QEMU UEFI VM.
The flake host attribute remains `arch` for deployment compatibility. Its short
hostname is `slop`, domain `kyouma.net`. The existing Arch installation remains
on `/dev/sda`; the NixOS installation uses only `/dev/sdb` (stable by-id
`scsi-0QEMU_QEMU_HARDDISK_drive-scsi1`). Never run disko against the Arch disk.

Source: https://github.com/slopinger/nixfiles. Application flake inputs are
fetched from https://github.com/slopinger.

## Host configuration

- Static IPv4/IPv6 and Cloudflare DNS through networkd/resolved; unchanged WAN MAC,
  routes and SSH authorized keys. SSH is key-only with root login disabled.
- User `slop` (UID/GID 1000), passwordless wheel sudo, SSH-signed git commits,
  home-manager bash, SSH, git and tmux. Existing managed dotfiles are backed up
  with `.before-nixos` during first activation. Homes and private workflow DBs
  are migrated independently of the public configuration.
- Caddy serves freifick.net and proxies trough and slopbox. Driftline is
  packaged static content. All legacy redirects remain. TLS state is retained
  at `/var/lib/caddy`; Caddy's data-directory environment matches Arch.
- slopd, trough (`fedi.freifick.net`, permanent federation identity), mayfly
  (`slopbox.freifick.net`), and the verified service backup timer
  are enabled. Service UIDs/GIDs match the old state.
- DN42 dummy interface, BIRD 3, ROA timer, existing runtime WireGuard/peer files
  and automatic peering monitor are retained. Peer snippets remain mutable in
  `/etc/bird/peers`; keys stay outside the store. A configured peer does not
  imply an established BGP session.
- Firewall remains disabled to match the live server, including DN42 tunnels.
  Internal applications bind to loopback. Public application ports are 22,
  80/443; WireGuard uses UDP 20125.
- Lix, QEMU guest agent, UTC, en_US.UTF-8, no swap, systemd-boot with a dedicated
  1 GiB ESP and ext4 root. The old disk remains a firmware fallback.

Application flakes own their packages/modules. The infrastructure lock pins all
eight project inputs and reexports the six service modules. MCP tools are
per-user stdio programs, with no new public listener. Static website updates now
use flake input updates and NixOS rebuilds instead of Arch deployment scripts.

## Build and deployment

```console
nix flake check --no-build
nix build .#nixosConfigurations.arch.config.system.build.toplevel
nix flake update trough                 # example application update
nix develop                            # colmena and nixos-anywhere tools
colmena apply --on arch                 # deploy as slop to freifick.net
```

The local disk migration uses `system.build.diskoScript` and `nixos-install`
with the prebuilt system closure; nixos-anywhere is unnecessary on this host.
Disk formatting is destructive and is only for the dedicated new disk.

## State and secrets migration

Secrets never belong in Nix expressions, store paths, commits or logs. Preserve
all of `/home` (especially `~/.secrets`, `.config` symlinks, SSH/signing keys,
agent credentials and private workflow databases), `/root`, `/srv`, `/opt`,
`/usr/local`, service state under `/var/lib`, SSH host keys, machine ID,
`/etc/trough.env`, `/etc/trough-secrets.env`, WireGuard keys/network files and
BIRD peer snippets. A root-only original `/etc` snapshot is kept at
`/root/arch-migration/etc` on the destination.

Copy live state initially, then stop database/upload writers and backup timers
for a final consistent copy. Verify SQLite integrity, secret/SSH-key byte
identity and ownership without printing contents. Validate generated sshd and
Caddy configuration, EFI binaries/entries and root mounts. Test a disposable
UEFI VM overlay before selecting the new disk in firmware.

Migration status (2026-10-15): configuration builds and target partitions exist;
installation, consistent final copy and isolated boot validation are in progress.
The live operating system is still Arch. Operational notes are maintained in
`/home/slop/CLAUDE.md`; `AGENTS.md` is its symlink.
