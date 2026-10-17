# nixfiles development notes

Follow `/home/slop/CLAUDE.md`; keep this file and README current. AGENTS.md links here.
Every software project needs a locked Nix flake and applicable reusable NixOS module.
Never add Co-Authored-By trailers or session links to public GitHub content.
Development lives on GitHub only (`git push origin main`).

- Migration to the dedicated `/dev/sdb` disk is explicitly authorized. The running
  Arch disk `/dev/sda` must remain intact. Host flake attribute and hostname are `arch`.
  See README for the layout, services and install procedure.
- Application flakes own their packages/modules. This flake pins public GitHub inputs,
  exposes packages through the overlay, and reexports their NixOS modules. Update input
  locks when changing application revisions; do not maintain duplicate application builds.
- `nix flake check --no-build` evaluates the host and package definitions. `nix flake check`
  builds the host system; `nix develop` provides deployment tools. Run relevant application
  checks in its source repo. Inspect status, sign small commits and push only your changes.
- Secrets are runtime files, never Nix literals or store paths. Preserve WAN/SSH settings.

## NixOS disk migration (configuration complete 2026-10-17; install not done)
- Target `/dev/sdb` (by-id `scsi-0QEMU_QEMU_HARDDISK_drive-scsi1`): 4 GiB ESP `nixos-esp` + btrfs
  `nixos-root` with subvolumes (README). sdb still holds an older 1 GiB ESP + ext4 attempt with the
  same partlabels: any test image must use different labels, or disko's by-partlabel paths hit sdb.
  Test installs must set `boot.loader.efi.canTouchEfiVariables = false` (host NVRAM).
- The config mirrors the live Arch host: keep it in sync when services, Caddy sites, networkd or
  DN42 peers change there (`scripts/dn42-peers-from-arch.py` regenerates `dn42/peers.nix`).
  The live Arch services and their deploy scripts remain authoritative until the switch.
- Verify after changes: `nix flake check --no-build`, build the toplevel, and diff generated
  units against the live files when touching networkd/BIRD/Caddy.
- nixpkgs is pinned to `7fd4004` because Lix fails to build on newer unstable (README).
- The dn42 daemon's old hardcoded registry credential is still in public git history and needs external
  rotation; never copy it into Nix expressions, store paths or notes.
