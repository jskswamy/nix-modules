{
  config,
  lib,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable;
  src = mkSource config ./config "modules/tools/nbdime/config";
  cfg = config.tools.nbdime;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.nbdime.enable = mkToolEnable lib "nbdime";

  config = lib.mkIf cfg.enable {
    home.file.".config/nbdime/config.json".source =
      src.file "config.json";
  };
}
