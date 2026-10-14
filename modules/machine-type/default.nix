{ config, lib, ...}: with lib;
let
  cfg = config.freifick.machine-type;
in {
  options.freifick.machine-type = {
    physical = mkOption {
      type = types.bool;
      default = false;
      description = "Mark machine as physical.";
    };

    virtual = mkOption {
      type = types.bool;
      default = false;
      description = "Mark machine as virtual.";
    };

    headless = mkOption {
      type = types.bool;
      default = false;
      description = "Mark machine as headless.";
    };
  };
  config = {
    assertions = [
      { assertion = !(cfg.physical && cfg.virtual);
        message = "machine-type.physical and machine-type.virtual are mutually exclusive";
      }
    ];
  };
}
