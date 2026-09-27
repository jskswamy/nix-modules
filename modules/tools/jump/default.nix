{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable;
  cfg = config.tools.jump;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.jump = {
    enable = mkToolEnable lib "jump";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.jump;
      description = ''
        Package providing jump, installed when this tool is enabled.

        Set to null to configure jump without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;
  };
}
