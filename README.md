# slop's NixOS infrastructure

Declarative configuration for the freifick.net server (hostname `slopbox`), a
Proxmox/QEMU UEFI VM. NixOS lives on the disk
`/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi1`; the previous Arch Linux install
stays on `scsi-0QEMU_QEMU_HARDDISK_drive-scsi0` as a fallback and is mounted read-only
at `/mnt/arch` when it is attached at boot. The `sdX` names are not stable: during the
move from Arch the NixOS disk was `/dev/sdb`, now it is usually `/dev/sda`. Never run
disko against the Arch disk.

Source: https://github.com/slopinger/nixfiles. Application flake inputs are
fetched from https://github.com/slopinger.

## Host configuration (`config/hosts/slopbox`)

- Disk (`disko.nix`): GPT with a **4 GiB** FAT32 ESP (`nixos-esp`, systemd-boot keeps
  a kernel + initrd per generation there, ~45 MiB each; boot menu limited to 30) and a
  **btrfs** root (`nixos-root`) with subvolumes `@root` `/`, `@nix`, `@home`, `@srv`,
  `@var-lib`, `@var-log`, `@docker` (`/var/lib/docker`) and `@snapshots`
  (`/.snapshots`), all `compress=zstd:1,noatime`. Monthly btrfs scrub, no swap.
- Network: systemd-networkd `10-wan` matched by MAC. **IPv4 via DHCP** (the upstream
  router only routes 45.150.123.24 after a DHCP request; DHCP DNS/NTP/hostname are
  ignored), static IPv6 `2a0f:be01:0:100::113/128` via `fe80::1`, no RAs. Cloudflare
  DNS through resolved. No firewall, as on Arch: internal services bind to loopback.
- SSH key-only, no root login, Arch host keys at the same paths. User `slop`
  (UID/GID 1000), passwordless wheel sudo. Home Manager: bash (aliases for
  claude/agy/codex; credential-bearing aliases go in `~/.bashrc.local`), signed git
  with gh as credential helper, SSH hosts for GitHub and git.dn42.dev, tmux, and
  claude-code, codex and antigravity-cli.
- Lix, QEMU guest agent, UTC, en_US.UTF-8, latest kernel, systemd initrd.
- `migration.nix`: the move from Arch (see below). It mounts the Arch root at
  `/mnt/arch`, disables emergency mode and reboots 30 s after a panic, and runs
  `nixos-boot-check` until it first succeeds.

## Services (`config/services`)

| File | What |
|---|---|
| `caddy.nix` | Caddy, Let's Encrypt only, admin API on `/run/caddy/admin.socket`, `(security_headers)` snippet, Arch's data dir `/var/lib/caddy` |
| `freifick-net.nix` | https://freifick.net (site from `slop-landing`), slopd on 127.0.0.1:8787, `slopctl`, www/slop.kyouma.net redirects |
| `trough.nix` | https://fedi.freifick.net, trough on 127.0.0.1:8790, `troughctl`, optional `/etc/trough-secrets.env`, week-long access log in `/var/log/caddy` |
| `slopbox.nix` | https://slopbox.freifick.net (mayfly on 127.0.0.1:8791) and the `mayfly.` redirect |
| `driftline.nix` | https://driftline.freifick.net static site with its CSP |
| `backups.nix` | `slop-services-backup.timer`, daily verified trough/slopd archives in `/srv/backups/slop-services` |
| `dn42/` | AS4242420125: dummy interface, BIRD 3, hourly ROA timer, 45 WireGuard peers (`peers.nix`), `dn42-auto-peer.service` |
| `docker.nix` | Docker for test harnesses (journald logs, live restore) |
| `agent-tools.nix` | Toolchains (gcc, go, gleam, erlang, rebar3, node, uv, python), MCP servers, headless Chromium + Xvfb/openbox/scrot/xdotool, fonts, nix-ld, `/usr/bin` + `/usr/local/bin` links used by the agents' MCP configs |

Service users keep their Arch UIDs/GIDs (caddy 968, slopd 967, trough 966/965,
mayfly 963) so copied state keeps its owner. Application flakes own their packages
and NixOS modules; this flake pins them and reexports the modules.

### DN42 peers

`config/services/dn42/peers.nix` feeds `services.slop-dn42.peers` from the dn42
flake, which generates the networkd netdev/network pair and the BIRD session per peer
(identical to what `dn42ctl add-peer` writes on Arch). On NixOS `/etc/systemd/network`
is read-only, so new peers are added there and deployed with a rebuild. While Arch is
live, regenerate the file from the running host's files with

```console
scripts/dn42-peers-from-arch.py > config/services/dn42/peers.nix
```

The shared tunnel key `/etc/wireguard/dn42.key` is runtime state; it is copied, never
put into Nix. ROA tables live in `/var/lib/dn42-roa`.

## Build and deployment

```console
nix flake check --no-build
nix build .#nixosConfigurations.slopbox.config.system.build.toplevel
nix flake update trough                 # example application update
nix develop                            # colmena and nixos-anywhere tools
colmena apply --on slopbox              # deploy as slop to freifick.net
sudo nixos-rebuild switch --flake .#slopbox   # or locally on the host
```

nixpkgs tracks `nixos-unstable`, but is locked to `0541f33` (nixos-unstable-small,
2026-10-17): on the 2026-10-14 nixos-unstable, Lix 2.95.4 is not in the binary cache
and fails to build (meson `mimalloc` option). A plain `nix flake update` is fine once
nixos-unstable has moved past that commit.

## Moving from Arch to `/dev/sdb`

Done on 2026-10-19. The cutover on 2026-10-17 did not stick: the VM came back up in
Arch, which kept serving for two days. NixOS was then booted by making the NixOS disk
the only Proxmox boot disk (the NVRAM entries are gone; OVMF starts systemd-boot via
the ESP's fallback `\EFI\BOOT\BOOTX64.EFI`), and Arch's newer trough database and
slopd counters were copied over by hand. If a cutover is ever repeated, check that the
first boot really is NixOS before treating Arch's state as frozen.

To repeat it from the Arch install (as root, from this checkout; there the NixOS disk
was `/dev/sdb`):

1. Build `system.build.toplevel`, `system.build.diskoScript` and
   `system.build.mountScript`. The disko script wipes `/dev/sdb` only and creates the
   ESP and btrfs subvolumes, addressed by the partlabels `nixos-esp`/`nixos-root`
   (Arch uses `ESP`/`root`; keep labels unique).
2. `nixos-install --root /mnt --system <toplevel> --no-root-passwd --no-channel-copy`.
   `canTouchEfiVariables` is off, so add the NVRAM entry by hand and keep Arch first:
   `efibootmgr -c -d /dev/sdb -p 1 -L NixOS -l '\EFI\systemd\systemd-bootx64.efi'`,
   then `efibootmgr -o <old order>`.
3. `scripts/migrate-from-arch.sh /mnt` copies the state (repeatable, rsync):
   `/home/slop`, `/root`, `/srv`, `/var/lib/{trough,slopd,mayfly,caddy,docker,containerd}`,
   the journal and Caddy logs, `/etc/machine-id`, SSH host keys,
   `/etc/trough-secrets.env`, `/etc/wireguard/dn42.{key,pub}`, the `nix profile`
   closures with their GC roots, and a reference copy of Arch's `/etc`, `/usr/local`,
   `/opt` and other logs in `/srv/arch`. Credential-bearing shell aliases belong in
   `~/.bashrc.local` (Home Manager replaces `~/.bashrc` and keeps the old one as
   `.bashrc.before-nixos`).
4. `scripts/cutover-from-arch.sh <mountScript> <efibootmgr>` stops the stateful
   services, runs the copy once more, and reboots into NixOS once (EFI BootNext). On
   NixOS, `nixos-boot-check` makes the NixOS entry the default once IPv4 and IPv6 work;
   without network for 10 minutes it boots Arch once more. A reset before that also
   returns to Arch.

Before the switch, the installed disk was booted in QEMU (OVMF, `snapshot=on`, isolated
user-mode network, commands through the guest agent) with the copied state: no failed
units, all sites served over HTTPS with the copied certificates, 45 DN42 tunnels and
BIRD sessions configured, the docker images present, trough/slopd data identical.

Operational notes for the live host are maintained in `/home/slop/CLAUDE.md`.
