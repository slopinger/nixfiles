# nixfiles development notes

Follow `/home/slop/CLAUDE.md`; keep this file and README current. AGENTS.md links here.
Every software project needs a locked Nix flake and applicable reusable NixOS module.
Never add Co-Authored-By trailers or session links to public GitHub content.
Development lives on GitHub only (`git push origin main`).

- NixOS runs from `/dev/sdb`; the old Arch disk `/dev/sda` must remain intact (fallback,
  mounted read-only at `/mnt/arch`). Host flake attribute and hostname are `slopbox`.
  See README for the layout, services and migration procedure.
- Application flakes own their packages/modules. This flake pins public GitHub inputs,
  exposes packages through the overlay, and reexports their NixOS modules. Update input
  locks when changing application revisions; do not maintain duplicate application builds.
- `nix flake check --no-build` evaluates the host and package definitions. `nix flake check`
  builds the host system; `nix develop` provides deployment tools. Run relevant application
  checks in its source repo. Inspect status, sign small commits and push only your changes.
- Secrets are runtime files, never Nix literals or store paths. Preserve WAN/SSH settings.

## Migration from Arch (2026-10-17)
- `/dev/sdb` (by-id `scsi-0QEMU_QEMU_HARDDISK_drive-scsi1`): 4 GiB ESP `nixos-esp` + btrfs
  `nixos-root` with subvolumes, created by disko (README). Test images need partlabels other
  than `nixos-esp`/`nixos-root`, or disko's by-partlabel paths hit the real disk.
- `config/hosts/slopbox/migration.nix` holds the fallback: `canTouchEfiVariables = false`
  (NVRAM entry "NixOS" made by hand), `nixos-boot-check` (sets NixOS first in BootOrder once
  the network works, else boots Arch once), `/mnt/arch`. Remove it once Arch is retired.
- State was copied with `scripts/migrate-from-arch.sh`; Arch's `/etc`, `/usr/local`, `/opt`
  and logs are kept in `/srv/arch` for reference.
- `scripts/dn42-peers-from-arch.py` only applies while the Arch files exist (`/mnt/arch`).
  On NixOS, add DN42 peers to `config/services/dn42/peers.nix` and rebuild.
- Verify after changes: `nix flake check --no-build`, build the toplevel.
- nixpkgs is locked past the Lix build failure of nixos-unstable 2026-10-14 (README).
- The dn42 daemon's old hardcoded registry credential is still in public git history and needs external
  rotation; never copy it into Nix expressions, store paths or notes.
