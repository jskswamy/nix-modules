{
  config,
  lib,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable;
  src = mkSource config ./config "modules/tools/tig/config";
  cfg = config.tools.tig;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.tig.enable = mkToolEnable lib "tig";

  config = lib.mkIf cfg.enable {
    home.file.".config/tig/config".source = src.file "config";
  };
}
