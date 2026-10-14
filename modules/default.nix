{ lib, ... }: let
  mapModules = builtins.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./.));
in {
  imports = map (dir: ./${dir}) mapModules;
}
