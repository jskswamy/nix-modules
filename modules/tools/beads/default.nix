{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable ownPkg;
  src = mkSource config ./config "modules/tools/beads/config";
  cfg = config.tools.beads;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.beads = {
    enable = mkToolEnable lib "beads";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = ownPkg pkgs "beads";
      description = ''
        Package providing beads, installed when this tool is enabled.

        Set to null to configure beads without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;

    # Beads memory system
    home.file.".config/bd/config.yaml".source =
      src.file "config.yaml";
  };
}
