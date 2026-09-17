{
  config,
  lib,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable;
  src = mkSource config ./config "modules/tools/pet/config";
  cfg = config.tools.pet;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.pet.enable = mkToolEnable lib "pet";

  config = lib.mkIf cfg.enable {
    home.file = {
      ".config/pet/config.toml".source = src.file "config.toml";
      ".config/pet/snippet.toml".source = src.file "snippet.toml";
    };
  };
}
