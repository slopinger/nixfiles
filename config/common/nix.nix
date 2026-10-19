{ pkgs, ... }: {
  # Lix, as installed by install.lix.systems on the Arch host.
  nix.package = pkgs.lixPackageSets.stable.lix;
  nix.registry.nixpkgs.to = {
    type = "path";
    path = pkgs.path;
  };
  nix.nixPath = [ "nixpkgs=flake:nixpkgs" ];
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    always-allow-substitutes = true;
    max-jobs = "auto";
    bash-prompt-prefix = "(nix:$name)\\040";
    # @wheel so colmena can copy closures as `slop`
    trusted-users = [ "root" "@wheel" ];
    # cache.kyouma.net: binary cache of hydra.kyouma.net, which builds our Hydra fork
    # (jobset slopinger-hydra:main), so its Lix-main closure needn't be compiled here.
    substituters = [ "https://cache.kyouma.net" ];
    trusted-substituters = [ "https://cache.lix.systems" ];
    trusted-public-keys = [
      "cache.lix.systems:aBnZUw8zA7H35Cz2RyKFVs3H4PlGTLawyY5KRbvJR8o="
      "cache.kyouma.net:Frjwu4q1rnwE/MnSTmX9yx86GNA/z3p/oElGvucLiZg="
    ];
  };
  # was a manual `nix-collect-garbage --delete-older-than 30d` on Arch
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
}
