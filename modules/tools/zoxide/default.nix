{
  config,
  lib,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable;
  cfg = config.tools.zoxide;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.zoxide.enable = mkToolEnable lib "zoxide";

  config = lib.mkIf cfg.enable {
    programs.zoxide = {
      enable = lib.mkDefault true;
      enableFishIntegration = lib.mkDefault true;
    };
  };
}
