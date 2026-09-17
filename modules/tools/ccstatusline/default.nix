{
  config,
  lib,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable;
  src = mkSource config ./config "modules/tools/ccstatusline/config";
  cfg = config.tools.ccstatusline;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.ccstatusline.enable = mkToolEnable lib "ccstatusline";

  config = lib.mkIf cfg.enable {
    home.file.".config/ccstatusline/settings.json".source =
      src.file "settings.json";
  };
}
