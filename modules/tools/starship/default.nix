{
  config,
  lib,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable;
  src = mkSource config ./config "modules/tools/starship/config";
  fishSrc = mkSource config ./fish "modules/tools/starship/fish";
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

    home.file = {
      ".config/starship.toml".source = src.file "starship.toml";

      # A drop-in for fish, not part of fish's own config: fish does not
      # import starship, so the prompt tweak travels with the prompt.
      # Harmless where fish is absent. Kept in fish/, not config/, because
      # some tools link their config/ directory wholesale.
      ".config/fish/conf.d/starship.fish".source = fishSrc.file "starship.fish";
    };
  };
}
