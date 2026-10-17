# nixfiles development notes

Follow `/home/slop/CLAUDE.md`; keep this file and README current. AGENTS.md links here.
Every software project needs a locked Nix flake and applicable reusable NixOS module.
Never add Co-Authored-By trailers or session links to public GitHub content.
Development lives on GitHub only (`git push origin main`).

- Migration to the dedicated `/dev/sdb` disk is explicitly authorized. The running
  Arch disk `/dev/sda` must remain intact. Host flake attribute stays `arch`; its
  network identity is now `slop.kyouma.net`. See README for migration status.
- Application flakes own their packages/modules. This flake pins public GitHub inputs,
  exposes packages through the overlay, and reexports their NixOS modules. Update input
  locks when changing application revisions; do not maintain duplicate application builds.
- `nix flake check --no-build` evaluates the host and package definitions. `nix flake check`
  builds the host system; `nix develop` provides deployment tools. Run relevant application
  checks in its source repo. Inspect status, sign small commits and push only your changes.
- Secrets are runtime files, never Nix literals or store paths. Preserve WAN/SSH settings.

## NixOS disk migration (in progress since 2026-10-15)
- Target: `/dev/sdb` (by-id `scsi-0QEMU_QEMU_HARDDISK_drive-scsi1`) with `nixos-esp` 1 GiB FAT32 and
  `nixos-root` ext4, mounted under `/mnt` during installation. Running Arch stays on `/dev/sda`; never
  format it. Arch is first in EFI BootOrder until the NixOS install is verified.
- Host `arch` configures FQDN `slop.kyouma.net` (`hostName=slop`, `domain=kyouma.net`), all public
  sites, trough, slopbox, DN42 and backup timers; service numeric UIDs/GIDs are preserved.
- Copy all homes (including `.secrets`, credentials, SSH/signing keys and private workflow DBs), `/srv`,
  service state and `/etc/trough-secrets.env`. Preserve SSH host keys, the WireGuard key and Caddy TLS
  state. Installation, final consistent copy and EFI verification are not complete yet.
- Pinned application flakes: slop-landing, driftline, server-backups, trough, mayfly, dn42, therapie-mcp,
  arbeitsagentur-mcp. Lantern (+ libraries) and slopbgp have their own flakes and modules but are not
  part of this host. The live Arch services and their deploy scripts remain authoritative; packaging
  here does not deploy them.
- The dn42 daemon's old hardcoded registry credential is still in public git history and needs external
  rotation; never copy it into Nix expressions, store paths or notes.
