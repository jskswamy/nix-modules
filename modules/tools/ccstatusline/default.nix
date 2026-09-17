{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable ownPkg;
  src = mkSource config ./config "modules/tools/ccstatusline/config";
  cfg = config.tools.ccstatusline;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.ccstatusline = {
    enable = mkToolEnable lib "ccstatusline";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = ownPkg pkgs "ccstatusline";
      description = ''
        Package providing ccstatusline, installed when this tool is enabled.

        Set to null to configure ccstatusline without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;

    home.file.".config/ccstatusline/settings.json".source =
      src.file "settings.json";
  };
}
