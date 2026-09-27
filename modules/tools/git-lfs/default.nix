{
  config,
  lib,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable;
  cfg = config.tools.git-lfs;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.git-lfs.enable = mkToolEnable lib "git-lfs";

  config = lib.mkIf cfg.enable {
    programs.git = {
      enable = lib.mkDefault true;
      lfs.enable = lib.mkDefault true;
    };
  };
}
