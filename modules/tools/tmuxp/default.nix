{
  config,
  lib,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable;
  src = mkSource config ./config "modules/tools/tmuxp/config";
  cfg = config.tools.tmuxp;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.tmuxp.enable = mkToolEnable lib "tmuxp";

  config = lib.mkIf cfg.enable {
    home.file.".config/tmuxp".source = src.dir;
  };
}
