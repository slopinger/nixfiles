inputs: final: prev: (

let inherit (prev) lib;
in lib.genAttrs
  (builtins.attrNames (lib.filterAttrs (_: v: v == "directory") (builtins.readDir ./.)))
  (pkg: final.callPackage ./${pkg} (
    builtins.intersectAttrs (builtins.functionArgs (import ./${pkg})) { inherit prev inputs; }
  ))
)
