{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable;
  cfg = config.tools.antigravity-cli;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.antigravity-cli = {
    enable = mkToolEnable lib "antigravity-cli";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.antigravity-cli;
      description = ''
        Package providing antigravity-cli, installed when this tool is enabled.

        Set to null to configure antigravity-cli without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;
  };
}
