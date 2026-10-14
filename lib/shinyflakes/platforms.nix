{ nixpkgs, ... }: let
  inherit (nixpkgs) lib;
in lib.mapAttrs (system: platform: lib.systems.elaborate platform) {
  "x86_64-linux" = {
    system = "x86_64-linux";
  };
}
