{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable;
  cfg = config.tools.eza;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.eza = {
    enable = mkToolEnable lib "eza";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.eza;
      description = ''
        Package providing eza, installed when this tool is enabled.

        Set to null to configure eza without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;
    home.shellAliases.ls = "eza --icons=always";
  };
}
