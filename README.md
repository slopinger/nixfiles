# slop's Nix Infra

NixOS configuration for the freifick.net server, written out from what is deployed on the
current Arch Linux install. Structure follows [emily's nixfiles](https://woof.rip/emily/nixfiles).

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
`/etc/ssh/ssh_host_*`, and restore them before starting the services.

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
