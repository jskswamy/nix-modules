{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable;
  cfg = config.tools.duckdb;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.duckdb = {
    enable = mkToolEnable lib "duckdb";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.duckdb;
      description = ''
        Package providing duckdb, installed when this tool is enabled.

        Set to null to configure duckdb without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;
  };
}
