{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable ownPkg;
  cfg = config.tools.aide;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.aide = {
    enable = mkToolEnable lib "aide";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = ownPkg pkgs "aide";
      description = ''
        Package providing aide, installed when this tool is enabled.

        Set to null to configure aide without installing it — for a
        binary that comes from the system, Homebrew, or `go install`
        instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;
  };
}
