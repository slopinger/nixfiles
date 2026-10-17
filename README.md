# slop's NixOS infrastructure

Declarative configuration for the freifick.net server (hostname `arch`), a
Proxmox/QEMU UEFI VM that currently runs Arch Linux on `/dev/sda`. This flake
describes the same server as NixOS, to be installed on the dedicated second disk
`/dev/sdb` (stable by-id `scsi-0QEMU_QEMU_HARDDISK_drive-scsi1`). Never run disko
against the Arch disk.

Source: https://github.com/slopinger/nixfiles. Application flake inputs are
fetched from https://github.com/slopinger.

## Host configuration (`config/hosts/arch`)

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
nix build .#nixosConfigurations.arch.config.system.build.toplevel
nix flake update trough                 # example application update
nix develop                            # colmena and nixos-anywhere tools
colmena apply --on arch                 # deploy as slop to freifick.net (once on NixOS)
```

nixpkgs is held at `7fd4004` (2026-10-11): on the 2026-10-14 nixos-unstable, Lix
2.95.4 is not in the binary cache and fails to build (meson `mimalloc` option). Move
it forward once `lixPackageSets.stable.lix` is cached again.

## Installing to `/dev/sdb`

1. Build `system.build.toplevel` and `system.build.diskoScript`. The disko script
   wipes and repartitions `/dev/sdb` only, addressing partitions by the partlabels
   `nixos-esp`/`nixos-root` (Arch uses `ESP`/`root`; keep labels unique).
2. `sudo nixos-install --root /mnt --system <toplevel> --no-root-passwd --no-channel-copy`.
   `canTouchEfiVariables` adds a "Linux Boot Manager" entry first in BootOrder;
   put Arch back first (`efibootmgr -o`) and test with `efibootmgr -n <entry>`
   (BootNext) until NixOS is verified.
3. Copy state (stop writers and timers for the final copy): `/home` (including
   `~/.secrets`, SSH/signing keys, agent configs and private workflow databases),
   `/srv`, `/var/lib/{trough,slopd,mayfly,caddy,dn42-roa}`, SSH host keys,
   `/etc/machine-id`, `/etc/trough-secrets.env`, `/etc/wireguard/dn42.key` (+ `.pub`).
   Verify SQLite integrity and byte identity of keys without printing them. Arch's
   `/etc/trough.env` is no longer needed (the module sets the same values).
4. Before relying on Home Manager, move credential-bearing aliases out of
   `~/.bashrc` (it gets replaced; the old file is kept as `.bashrc.before-nixos`)
   into `~/.bashrc.local`.

The layout and boot path were tested on 2026-10-17 by running the disko script and
`nixos-install` against a sparse loop-device image (unique test labels,
`canTouchEfiVariables = false` so the host's NVRAM stays untouched) and booting it with
OVMF: it reached multi-user with no failed units, all services active, and BIRD up
on empty ROA tables without network.

Operational notes for the live host are maintained in `/home/slop/CLAUDE.md`.
