{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable;
  cfg = config.tools.bat;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.bat = {
    enable = mkToolEnable lib "bat";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.bat;
      description = ''
        Package providing bat, installed when this tool is enabled.

        Set to null to configure bat without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;
    home.shellAliases.cat = "bat";
    home.sessionVariables = {
      MANPAGER = "bat -l man -p";
      BAT_THEME = "ansi";
    };
  };
}
