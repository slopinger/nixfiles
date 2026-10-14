{ lib, ... }:
with lib;
{
  options.freifick.deployment = {
    tags = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = "colmena deployment tags";
    };
    targetHost = mkOption {
      type = with types; nullOr str;
      default = null;
      description = "colmena target host override";
    };
  };
}
