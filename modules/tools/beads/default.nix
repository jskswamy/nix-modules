{
  config,
  lib,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable;
  src = mkSource config ./config "modules/tools/beads/config";
  cfg = config.tools.beads;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.beads.enable = mkToolEnable lib "beads";

  config = lib.mkIf cfg.enable {
    # Beads memory system
    home.file.".config/bd/config.yaml".source =
      src.file "config.yaml";
  };
}
