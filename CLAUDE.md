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
