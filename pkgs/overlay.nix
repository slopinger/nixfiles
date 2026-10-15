inputs: final: prev: (

let inherit (prev) lib;
in lib.genAttrs
  (builtins.attrNames (lib.filterAttrs (_: v: v == "directory") (builtins.readDir ./.)))
  (pkg: final.callPackage ./${pkg} (
    builtins.intersectAttrs (builtins.functionArgs (import ./${pkg})) { inherit prev inputs; }
  ))
 // lib.genAttrs
  [ "trough" "mayfly" "dn42" "driftline" "server-backups" "therapie-mcp" "arbeitsagentur-mcp" ]
  (name: inputs.${name}.packages.${prev.stdenv.hostPlatform.system}.default)
)
