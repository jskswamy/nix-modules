{
  config,
  lib,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable;
  src = mkSource config ./config "modules/tools/starship/config";
  cfg = config.tools.starship;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.starship.enable = mkToolEnable lib "starship";

  config = lib.mkIf cfg.enable {
    # starship.toml is symlinked below; edits take effect on the next
    # prompt with no rebuild.
    programs.starship = {
      enable = lib.mkDefault true;
      enableFishIntegration = lib.mkDefault true;
    };

    home.file.".config/starship.toml".source =
      src.file "starship.toml";
  };
}
