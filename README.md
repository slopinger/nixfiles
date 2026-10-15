# slop's Nix Infra

NixOS configuration for the freifick.net server, written out from what is deployed on the
current Arch Linux install. Structure follows [emily's nixfiles](https://woof.rip/emily/nixfiles).

## Coverage of this snapshot

The live server still runs Arch Linux. This NixOS snapshot predates the trough fediverse service,
dn42 routing and the verified trough/slopd backup timer added on 2026-10-14; those services are not
yet enabled in the host configuration. Their project-owned modules are now reexported
by this flake; importing/enabling them and migrating runtime configuration is a separate
host migration task. Do not treat this configuration as a complete replacement for the
current host until they are carried over. The MCP projects run per-user with uv rather than as
public services. Operational facts live in `/home/slop/CLAUDE.md` (`AGENTS.md` is its symlink).
Keep this README and those notes current as services and deployment procedures change.

What it describes:

- **Host `arch`**: Proxmox/QEMU VM, UEFI + systemd-boot, ext4 root on `/dev/sda` (disko layout keeps
  the existing partition/filesystem labels), static IPv4/IPv6 via systemd-networkd, resolved with
  Cloudflare DNS.
- **sshd**: key-only, no root login, same host key paths (fingerprints survive).
- **slop**: wheel with passwordless sudo, no password; home-manager for git (SSH-signed commits),
  ssh, tmux and bash.
- **Caddy** for `freifick.net`, `www.freifick.net` / `slop.kyouma.net` (308 redirects) and
  `git.freifick.net`; Let's Encrypt only, admin API on a unix socket.
- **freifick.net** site and **slopd** (guestbook + visitor counter, `slopctl` for moderation), built
  from the [slop-landing](https://git.freifick.net/slop/slop-landing) flake input.
- **GitLab CE** (Omnibus image, Docker) with state in `/srv/gitlab` and a nightly `gitlab-backup.timer`.
- **Nix**: Lix, flakes, weekly GC.

## Differences from the Arch install

- **Firewall on**: the Arch host has none. Here the NixOS firewall allows exactly the ports that are
  meant to be public (22, 80, 443 tcp+udp, 2222); everything else already listens on loopback only.
  This also stops exposing systemd-resolved's LLMNR/mDNS (5355/5353). Docker-published ports
  bypass it, as before.
- **The web root is a store path** instead of `/srv/http/freifick.net`. Deploy a new site/slopd
  version with `nix flake update slop-landing` + `colmena apply`, not `deploy.sh`.
- `@wheel` is a trusted Nix user so colmena can copy closures as `slop`.
- Not carried over: `base-devel`, `yay` (use `nix shell`), the `ssh_host_mldsa44_ed25519_key`
  host key.

Secrets are not in this repo: GitLab's first-boot root password stays in `/srv/gitlab/.env`, API
tokens stay in `~/.config`.

## Usage

```console
$ nix flake check                     # evaluate + build every host
$ nix build .#nixosConfigurations.arch.config.system.build.toplevel
$ nix develop                         # colmena, nixos-anywhere
$ colmena apply --on arch             # deploy (as slop@freifick.net, builds on the target)
$ colmena apply-local --sudo          # deploy on the host itself
```

### First deployment (replacing Arch)

```console
$ nix run github:nix-community/nixos-anywhere -- --flake ".#arch" root@<target-host>
```

nixos-anywhere repartitions with `disko.nix`. To keep the data, back up first: `/srv/gitlab`
(including `config/gitlab-secrets.json`), `/var/lib/slopd`, `/var/lib/caddy` (certificates) and
`/etc/ssh/ssh_host_*`, and restore them before starting the services. Also preserve the newer
`/var/lib/trough` (DB + uploads, host fixed as `fedi.freifick.net`), `/etc/trough.env`,
`/srv/backups/slop-services`, and the dn42/WireGuard configuration and private keys. Those newer
services must first be enabled and configured in the host; storing their data alone does not enable them.

## Structure
```
nixfiles
├── config              # NixOS configuration
│   ├── common          # configuration applied to all hosts
│   ├── hosts           # configuration for specific hosts
│   ├── profiles        # configuration for specific machine types
│   ├── services        # service configuration
│   └── users           # user configuration
├── lib                 # helper functions
├── modules             # NixOS modules
└── pkgs                # nixpkgs overlay
```

## Project packaging

All eight application/tool projects have their own locked Nix flakes. This
infrastructure flake pins their public GitLab revisions and consumes their
packages directly; slopd and the site no longer have duplicate build recipes.
The overlay/package outputs expose `slop-landing`, `slopd`, `trough`, `mayfly`,
`dn42`, `driftline`, `server-backups`, `therapie-mcp` and `arbeitsagentur-mcp`.
For the runtime executable name and options, see each project's README.

Reusable NixOS modules are exported as `nixosModules.slopd`, `.trough`, `.mayfly`,
`.dn42`, `.driftline` and `.server-backups`. The existing `slopd` namespace is
`freifick.slopd`; the others use the options documented in their source projects.
The MCP servers are per-user stdio tools and do not expose public services.
Reexporting a module does not enable it on `arch`.

To update an application pin, run `nix flake update <input-name>` and commit
`flake.lock`. Evaluate with `nix flake check --no-build`, then build affected
packages, for example `nix build .#trough .#therapie-mcp`. Application suites
run via `nix flake check` in their own source projects. Never add secrets or
session links to this public repository, or co-author trailers to commits.

Validation on 2026-10-15: the full x86_64 NixOS host check built successfully,
all application package outputs built through this flake, and the six exported
modules evaluated together with no failed assertions. Application checks include
Go tests, offline MCP tests, Gleam/HTTP checks, backup fixtures and Node tests.
This verifies builds/configuration; the host snapshot has not been deployed.
