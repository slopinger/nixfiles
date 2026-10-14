{
  description = "slop's infra: freifick.net as NixOS configuration";

  outputs = { self, nixpkgs, colmena, flake-utils, ... }@inputs: let
    sf = import ./lib/shinyflakes inputs;
    inherit (nixpkgs) lib;
  in {
    colmenaHive = colmena.lib.makeHive (sf.mapColmenaMerge self.nixosConfigurations {
      meta = {
        allowApplyAll = false;
        nixpkgs = nixpkgs.legacyPackages.x86_64-linux;
        specialArgs = { inherit inputs; };
      };
    });

    nixosConfigurations = sf.mapNixosCfg {
      hosts = sf.mapHostsMerge ./config/hosts { };
    };

    overlays = {
      freifick = import ./pkgs/overlay.nix inputs;
      default = self.overlays.freifick;
    };

    nixosModules = lib.genAttrs
      (builtins.attrNames (lib.filterAttrs (_: v: v == "directory") (builtins.readDir ./modules)))
      (mod: ./modules/${mod});

    packages = sf.eachSystem (system: platform: let
      pkgs = sf.importPkgs system;
    in lib.filterAttrs (_: pkg: lib.meta.availableOn platform pkg) (sf.mapPackages pkgs system { }));

    checks = sf.eachSystem (system: _:
      lib.mapAttrs (_: host: host.config.system.build.toplevel)
        (lib.filterAttrs (_: host: host.pkgs.stdenv.hostPlatform.system == system) self.nixosConfigurations));
  } // flake-utils.lib.eachSystem [ "x86_64-linux" ] (system: let
    pkgs = sf.importPkgs system;
  in {
    devShells.default = pkgs.mkShell {
      packages = [ pkgs.colmena pkgs.nixos-anywhere ];
    };
    formatter = pkgs.nixfmt-rfc-style;
  });

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # freifick.net static site + slopd (guestbook/counter backend)
    slop-landing = {
      url = "git+https://git.freifick.net/slop/slop-landing.git";
      flake = false;
    };
  };
}
